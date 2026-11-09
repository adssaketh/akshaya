import 'dart:async';
import 'dart:typed_data';

import '../../../core/diagnostics/diag.dart';
import '../../commands/domain/command_models.dart';
import '../../commands/domain/voice_language.dart';
import 'ai_failures.dart';
import 'ai_gate.dart';
import 'ai_response_validator.dart';
import 'ai_settings.dart';

/// The bit that actually talks to Gemini (through Firebase AI Logic). Tests
/// replace it with a fake.
abstract interface class GenerativeBackend {
  /// Sends [prompt] and returns the JSON text of the answer.
  Future<String> generateJson(String prompt);

  /// Sends a short recording and returns what was said.
  Future<String> transcribe({
    required Uint8List audio,
    required String mimeType,
    required String prompt,
  });
}

/// Where the daily AI call count is kept.
abstract interface class AiUsageStore {
  Future<AiUsage> read();

  Future<void> write(AiUsage usage);
}

/// Asks Gemini to read a command that the offline parser could not. Every call
/// goes through [AiGate], is counted against the daily cap, and fails softly.
final class AiCommandService {
  AiCommandService({
    required this.backend,
    required this.usageStore,
    required this.readSettings,
    required this.promptTemplate,
    required this.firebaseConfigured,
    required this.now,
    this.delay = _realDelay,
    this.timeout = const Duration(seconds: 20),
    this.cooldown = const Duration(minutes: 1),
  });

  final GenerativeBackend backend;
  final AiUsageStore usageStore;

  /// Current settings (read on every call so changes apply at once).
  final AiSettings Function() readSettings;
  final String promptTemplate;
  final bool firebaseConfigured;
  final DateTime Function() now;

  /// Waits between retries. Tests pass a no-op.
  final Future<void> Function(Duration) delay;
  final Duration timeout;

  /// How long to stay offline after the quota says "too many requests".
  final Duration cooldown;

  DateTime? _cooldownUntil;

  static const int maxAttempts = 3;
  static const int maxTextLength = 300;
  static const int maxKnownItems = 150;

  static Future<void> _realDelay(Duration d) => Future<void>.delayed(d);

  /// Why AI can or cannot be used right now.
  Future<AiAvailability> availability() async {
    final AiUsage usage = await usageStore.read();
    return _check(usage);
  }

  AiAvailability _check(AiUsage usage) {
    final DateTime current = now();
    return AiGate.check(
      settings: readSettings(),
      usage: usage,
      today: DateTime(current.year, current.month, current.day),
      firebaseConfigured: firebaseConfigured,
      now: current,
      cooldownUntil: _cooldownUntil,
    );
  }

  /// Interprets [text]. Only grocery words go to Google: the text itself, a
  /// list of item names and today's date. Throws an [AiFailure].
  Future<List<CommandAction>> interpret({
    required String text,
    required List<String> knownItemNames,
    required VoiceLanguage language,
    required CommandContext context,
  }) async {
    final String clean = _sanitize(text);
    if (clean.isEmpty) {
      throw const AiInvalidResponseFailure('empty text');
    }
    final DateTime current = now();
    final String prompt = promptTemplate
        .replaceAll('{{today}}', _isoDate(current))
        .replaceAll(
          '{{known_items}}',
          knownItemNames.take(maxKnownItems).map(_sanitize).join(', '),
        )
        .replaceAll('{{language_hint}}', language.promptHint)
        .replaceAll(
          '{{screen}}',
          context == CommandContext.shopping
              ? 'shopping list'
              : 'pantry',
        )
        .replaceAll('{{text}}', clean);
    final String answer = await _callWithRetries(
      (() => backend.generateJson(prompt)),
    );
    return AiResponseValidator.parse(answer);
  }

  /// Turns a recording into text with Gemini. Used when the phone's own
  /// speech recogniser is not available. Throws an [AiFailure].
  Future<String> transcribe({
    required Uint8List audio,
    required String mimeType,
    required VoiceLanguage language,
  }) async {
    final String prompt = 'Transcribe this short audio recording of a person '
        'talking about groceries. The language is ${language.promptHint}. '
        'Return only the words that were said, in the language they were '
        'said, with no commentary.';
    final String answer = await _callWithRetries(
      (() => backend.transcribe(
            audio: audio,
            mimeType: mimeType,
            prompt: prompt,
          )),
    );
    final String text = answer.trim();
    if (text.isEmpty) {
      throw const AiInvalidResponseFailure('empty transcript');
    }
    return text;
  }

  /// Runs [call] through the same gate as command reading: the on/off switch,
  /// the privacy notice, the daily cap (every attempt counts), the quota
  /// cooldown and the retries. Other AI features (recipes) use this so there
  /// is one cap and one cooldown for the whole app. [timeout] replaces the
  /// default 20 seconds for slower requests. Throws an [AiFailure].
  Future<String> guardedCall(
    Future<String> Function() call, {
    Duration? timeout,
  }) {
    return _callWithRetries(call, limit: timeout);
  }

  Future<String> _callWithRetries(
    Future<String> Function() call, {
    Duration? limit,
  }) async {
    AiFailure? last;
    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      final AiUsage usage = await usageStore.read();
      final AiAvailability availability = _check(usage);
      if (!availability.isReady) {
        throw last ?? AiUnavailableFailure(availability);
      }
      // Every attempt counts, so retries cannot run past the cap.
      final DateTime current = now();
      await usageStore.write(
        usage.incremented(DateTime(current.year, current.month, current.day)),
      );
      try {
        return await call().timeout(limit ?? timeout);
      } on Object catch (error) {
        final AiFailure failure = classify(error);
        last = failure;
        // Only the kinds of failure and known error codes: never the request
        // or the answer.
        final String hint = failureHint(error);
        Diag.warn(
          'ai',
          'Call failed (attempt ${attempt + 1} of $maxAttempts): '
              '${failure.runtimeType} from ${error.runtimeType}'
              '${hint.isEmpty ? '' : ' ($hint)'}',
        );
        if (failure is AiQuotaFailure) {
          _cooldownUntil = now().add(cooldown);
          throw failure;
        }
        if (failure is AiOfflineFailure) {
          throw failure;
        }
        if (attempt + 1 < maxAttempts) {
          await delay(Duration(seconds: 1 << attempt));
        }
      }
    }
    throw last ?? const AiServiceFailure();
  }

  /// Error codes and keywords that say WHY a call failed, for the diagnostics
  /// log. Only these are picked out of the error text (an allowlist), so what
  /// was said or answered can never end up in the log.
  static String failureHint(Object error) {
    final String text = error.toString();
    final List<String> parts = <String>[];
    for (final Match m
        in RegExp(r'\[[A-Za-z0-9_\-/.]{3,60}\]').allMatches(text)) {
      parts.add(m.group(0)!);
    }
    final String lower = text.toLowerCase();
    const List<String> keywords = <String>[
      'permission_denied',
      'permission denied',
      'not_found',
      'not found',
      'unavailable',
      'invalid_argument',
      'unauthenticated',
      'failed_precondition',
      'app check',
      'appcheck',
      'attestation',
      'play integrity',
      'api key',
      'not enabled',
      'service_disabled',
      'has not been used',
      'unsupported location',
      'user location',
      'billing',
    ];
    for (final String keyword in keywords) {
      if (lower.contains(keyword)) {
        parts.add(keyword);
      }
    }
    final Match? status = RegExp(r'\b[45]\d\d\b').firstMatch(text);
    if (status != null) {
      parts.add(status.group(0)!);
    }
    return parts.toSet().take(6).join(' ');
  }

  /// Sorts any error from the AI library into one of our failures.
  static AiFailure classify(Object error) {
    if (error is AiFailure) {
      return error;
    }
    if (error is TimeoutException) {
      return const AiServiceFailure();
    }
    final String text = error.toString().toLowerCase();
    if (text.contains('429') ||
        text.contains('quota') ||
        text.contains('resource_exhausted') ||
        text.contains('resource exhausted') ||
        text.contains('rate limit') ||
        text.contains('rate-limit') ||
        text.contains('too many requests')) {
      return const AiQuotaFailure();
    }
    if (text.contains('socketexception') ||
        text.contains('failed host lookup') ||
        text.contains('network is unreachable') ||
        text.contains('no address associated') ||
        text.contains('clientexception') ||
        text.contains('unable to resolve host')) {
      return const AiOfflineFailure();
    }
    return const AiServiceFailure();
  }

  /// Keeps one line of plain text: no control characters, no template
  /// markers, limited length.
  static String _sanitize(String text) {
    final String oneLine = text
        .replaceAll(RegExp(r'[\u0000-\u001F\u007F]+'), ' ')
        .replaceAll('{{', ' ')
        .replaceAll('}}', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return oneLine.length > maxTextLength
        ? oneLine.substring(0, maxTextLength)
        : oneLine;
  }

  static String _isoDate(DateTime d) {
    final String m = d.month.toString().padLeft(2, '0');
    final String day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }
}
