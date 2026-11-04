import 'dart:async';

import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../domain/speech_gateway.dart';

/// [SpeechGateway] backed by the `speech_to_text` plugin.
final class SpeechToTextGateway implements SpeechGateway {
  SpeechToTextGateway() : _speech = SpeechToText();

  final SpeechToText _speech;
  Completer<SpeechResult>? _pending;
  String _lastWords = '';
  bool _initialized = false;

  @override
  Future<SpeechResult> listen({
    required String localeId,
    void Function(String partial)? onPartial,
  }) async {
    if (_pending != null) {
      return const SpeechResult(SpeechStatus.error);
    }
    final Completer<SpeechResult> done = Completer<SpeechResult>();
    _pending = done;
    _lastWords = '';

    void finish(SpeechStatus status) {
      if (!done.isCompleted) {
        done.complete(
          _lastWords.trim().isNotEmpty
              ? SpeechResult(SpeechStatus.ok, _lastWords.trim())
              : SpeechResult(status),
        );
      }
    }

    try {
      if (!_initialized) {
        _initialized = await _speech.initialize(
          onError: (SpeechRecognitionError error) {
            final String msg = error.errorMsg;
            if (msg == 'error_no_match' || msg == 'error_speech_timeout') {
              finish(SpeechStatus.noSpeech);
            } else if (msg == 'error_permission') {
              finish(SpeechStatus.permissionDenied);
            } else {
              finish(SpeechStatus.error);
            }
          },
          onStatus: (String status) {
            if (status == 'done' || status == 'notListening') {
              finish(SpeechStatus.noSpeech);
            }
          },
        );
      }
      if (!_initialized) {
        _pending = null;
        return SpeechResult(
          await _speech.hasPermission
              ? SpeechStatus.notAvailable
              : SpeechStatus.permissionDenied,
        );
      }
      await _speech.listen(
        listenOptions: SpeechListenOptions(
          localeId: localeId,
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 3),
          partialResults: true,
          cancelOnError: true,
        ),
        onResult: (SpeechRecognitionResult result) {
          _lastWords = result.recognizedWords;
          onPartial?.call(_lastWords);
          if (result.finalResult) {
            finish(SpeechStatus.noSpeech);
          }
        },
      );
      return await done.future;
    } on Object {
      return const SpeechResult(SpeechStatus.error);
    } finally {
      _pending = null;
    }
  }

  @override
  Future<void> stop() async {
    await _speech.stop();
  }

  @override
  Future<void> cancel() async {
    _lastWords = '';
    await _speech.cancel();
    final Completer<SpeechResult>? done = _pending;
    if (done != null && !done.isCompleted) {
      done.complete(const SpeechResult(SpeechStatus.noSpeech));
    }
  }
}
