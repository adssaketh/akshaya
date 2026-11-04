import 'dart:async';
import 'dart:typed_data';

import 'package:akshaya/core/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/domain/ai_command_service.dart';
import '../../ai/domain/ai_failures.dart';
import '../../ai/domain/ai_gate.dart';
import '../../ai/domain/ai_settings.dart';
import '../../ai/presentation/ai_notice_dialog.dart';
import '../../ai/presentation/providers.dart';
import '../../pantry/domain/entities.dart';
import '../../pantry/presentation/providers.dart';
import '../../settings/presentation/providers.dart';
import '../domain/command_models.dart';
import '../domain/command_service.dart';
import '../domain/speech_gateway.dart';
import '../domain/voice_language.dart';
import 'providers.dart';

/// Asks for a command by voice or text and returns what was understood, or
/// null when the person closes the sheet.
Future<CommandInterpretation?> showCommandInputSheet(
  BuildContext context, {
  required CommandContext commandContext,
  String initialText = '',
}) {
  return showModalBottomSheet<CommandInterpretation>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (BuildContext sheetContext) {
      return CommandInputSheet(
        commandContext: commandContext,
        initialText: initialText,
      );
    },
  );
}

enum _Phase { idle, listening, recording, transcribing, understanding }

class CommandInputSheet extends ConsumerStatefulWidget {
  const CommandInputSheet({
    super.key,
    required this.commandContext,
    this.initialText = '',
  });

  final CommandContext commandContext;
  final String initialText;

  @override
  ConsumerState<CommandInputSheet> createState() => _CommandInputSheetState();
}

class _CommandInputSheetState extends ConsumerState<CommandInputSheet> {
  static const Duration _maxRecording = Duration(seconds: 10);

  late final TextEditingController _text =
      TextEditingController(text: widget.initialText);
  _Phase _phase = _Phase.idle;
  String? _message;
  Timer? _recordingTimer;

  // Kept so dispose() does not need `ref`.
  late final SpeechGateway _speech;
  late final AudioRecorderGateway _recorder;

  @override
  void initState() {
    super.initState();
    _speech = ref.read(speechGatewayProvider);
    _recorder = ref.read(audioRecorderProvider);
    if (widget.initialText.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(_startVoice());
        }
      });
    }
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    if (_phase == _Phase.listening) {
      unawaited(_speech.cancel());
    }
    if (_phase == _Phase.recording) {
      unawaited(_recorder.cancel());
    }
    _text.dispose();
    super.dispose();
  }

  bool get _busy =>
      _phase == _Phase.transcribing || _phase == _Phase.understanding;

  Future<void> _explainMicrophoneOnce() async {
    final Map<String, String> stored =
        ref.read(settingsMapProvider).value ?? const <String, String>{};
    if (stored[AiSettingKeys.micExplained] == 'true') {
      return;
    }
    if (!mounted) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Use the microphone?'),
        content: const Text(
          'Akshaya listens only while you are speaking a command, and your '
          'phone turns the speech into text. You can always type instead.',
        ),
        actions: <Widget>[
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    await ref.read(settingsRepositoryProvider).writeAll(
      <String, String>{AiSettingKeys.micExplained: 'true'},
    );
  }

  Future<void> _startVoice() async {
    if (_busy || _phase != _Phase.idle) {
      return;
    }
    await _explainMicrophoneOnce();
    if (!mounted) {
      return;
    }
    // Ask about AI before the first command so the notice never interrupts a
    // confirmation.
    await ensureAiNotice(context, ref);
    if (!mounted) {
      return;
    }
    final VoiceLanguage language = ref.read(aiSettingsProvider).voiceLanguage;
    setState(() {
      _phase = _Phase.listening;
      _message = null;
    });
    final SpeechResult result = await _speech.listen(
      localeId: language.localeId,
      onPartial: (String partial) {
        if (mounted) {
          _text.text = partial;
        }
      },
    );
    if (!mounted) {
      return;
    }
    switch (result.status) {
      case SpeechStatus.ok:
        _text.text = result.text;
        setState(() => _phase = _Phase.idle);
        await _submit();
      case SpeechStatus.noSpeech:
        setState(() {
          _phase = _Phase.idle;
          _message = "I didn't catch that. Tap the mic and try again.";
        });
      case SpeechStatus.permissionDenied:
        setState(() {
          _phase = _Phase.idle;
          _message = 'Microphone access is off. Allow it in the phone '
              'settings, or type your command.';
        });
      case SpeechStatus.notAvailable:
        await _fallBackToRecording();
      case SpeechStatus.error:
        setState(() {
          _phase = _Phase.idle;
          _message = 'Voice input did not work. You can type instead.';
        });
    }
  }

  /// The phone has no speech recogniser: record a few seconds and let Gemini
  /// transcribe it, when AI may be used.
  Future<void> _fallBackToRecording() async {
    final AiCommandService? ai = ref.read(aiCommandServiceProvider);
    final AiAvailability availability =
        ai == null ? AiAvailability.notConfigured : await ai.availability();
    if (!mounted) {
      return;
    }
    if (!availability.isReady) {
      setState(() {
        _phase = _Phase.idle;
        _message = 'Voice input is not available on this phone. '
            '${availability.message ?? ''} Type your command instead.';
      });
      return;
    }
    final bool started = await _recorder.start();
    if (!mounted) {
      return;
    }
    if (!started) {
      setState(() {
        _phase = _Phase.idle;
        _message = 'Microphone access is off. Allow it in the phone '
            'settings, or type your command.';
      });
      return;
    }
    setState(() {
      _phase = _Phase.recording;
      _message = 'Recording. Tap the button when you are done.';
    });
    _recordingTimer = Timer(_maxRecording, () {
      if (mounted && _phase == _Phase.recording) {
        unawaited(_stopRecording());
      }
    });
  }

  Future<void> _stopRecording() async {
    _recordingTimer?.cancel();
    setState(() {
      _phase = _Phase.transcribing;
      _message = null;
    });
    final Uint8List? audio = await _recorder.stop();
    final AiCommandService? ai = ref.read(aiCommandServiceProvider);
    if (!mounted) {
      return;
    }
    if (audio == null || ai == null) {
      setState(() {
        _phase = _Phase.idle;
        _message = 'Nothing was recorded. You can type instead.';
      });
      return;
    }
    try {
      final String words = await ai.transcribe(
        audio: audio,
        mimeType: 'audio/wav',
        language: ref.read(aiSettingsProvider).voiceLanguage,
      );
      if (!mounted) {
        return;
      }
      _text.text = words;
      setState(() => _phase = _Phase.idle);
      await _submit();
    } on AiFailure catch (failure) {
      if (!mounted) {
        return;
      }
      setState(() {
        _phase = _Phase.idle;
        _message = '${failure.message} You can type instead.';
      });
    }
  }

  Future<void> _onMicPressed() async {
    switch (_phase) {
      case _Phase.listening:
        await _speech.stop();
      case _Phase.recording:
        await _stopRecording();
      case _Phase.idle:
        await _startVoice();
      case _Phase.transcribing:
      case _Phase.understanding:
        break;
    }
  }

  Future<void> _submit() async {
    final String words = _text.text.trim();
    if (words.isEmpty) {
      setState(() => _message = 'Say or type what you want to do.');
      return;
    }
    final CommandService? service = ref.read(commandServiceProvider);
    if (service == null) {
      setState(() => _message = 'Still getting ready. Try again in a moment.');
      return;
    }
    setState(() {
      _phase = _Phase.understanding;
      _message = null;
    });
    final List<ItemWithBatches> records =
        ref.read(itemsStreamProvider).value ?? const <ItemWithBatches>[];
    final CommandInterpretation result = await service.interpret(
      words,
      context: widget.commandContext,
      language: ref.read(aiSettingsProvider).voiceLanguage,
      knownItemNames: <String>[for (final ItemWithBatches r in records) r.item.name],
    );
    if (!mounted) {
      return;
    }
    if (result.actions.isEmpty) {
      setState(() {
        _phase = _Phase.idle;
        _message = result.note ??
            "I couldn't find anything to do. Try \"add 2 kg rice\" or "
                '"milk finished".';
      });
      return;
    }
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final AkshayaColors colors = context.akColors;
    final VoiceLanguage language = ref.watch(aiSettingsProvider).voiceLanguage;
    final bool listening = _phase == _Phase.listening;
    final bool recording = _phase == _Phase.recording;

    final String status = switch (_phase) {
      _Phase.listening => 'Listening...',
      _Phase.recording => 'Recording...',
      _Phase.transcribing => 'Turning speech into text...',
      _Phase.understanding => 'Understanding...',
      _Phase.idle => 'Tap the mic and speak, or type below.',
    };

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text('Voice or text command', style: context.akText.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Language: ${language.label}. English, Telugu and Hindi can be '
              'mixed.',
              style: context.akText.bodyMedium!.copyWith(
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Center(
              child: Semantics(
                button: true,
                label: listening || recording ? 'Stop' : 'Start speaking',
                child: IconButton.filled(
                  iconSize: AppSizes.iconXl,
                  constraints: const BoxConstraints(
                    minWidth: AppSizes.fab * 1.5,
                    minHeight: AppSizes.fab * 1.5,
                  ),
                  onPressed: _busy ? null : _onMicPressed,
                  icon: Icon(
                    listening || recording
                        ? Icons.stop_rounded
                        : Icons.mic_rounded,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              status,
              textAlign: TextAlign.center,
              style: context.akText.bodyMedium,
            ),
            if (_busy) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              const LinearProgressIndicator(),
            ],
            if (_message != null) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              Text(
                _message!,
                textAlign: TextAlign.center,
                style: context.akText.bodyMedium!.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _text,
              enabled: !_busy,
              minLines: 1,
              maxLines: 3,
              textInputAction: TextInputAction.done,
              onSubmitted: (String _) => _submit(),
              decoration: const InputDecoration(
                labelText: 'Command',
                hintText: 'add 1 litre milk, 6 eggs and half kilo tomatoes',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: const Text('Understand'),
            ),
          ],
        ),
      ),
    );
  }
}
