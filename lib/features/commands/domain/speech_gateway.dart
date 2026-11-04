import 'dart:typed_data';

/// How a listening attempt ended.
enum SpeechStatus {
  /// [SpeechResult.text] holds what was said.
  ok,

  /// This phone has no speech recogniser (or it is switched off).
  notAvailable,

  /// The person did not allow the microphone.
  permissionDenied,

  /// Nothing was heard.
  noSpeech,

  /// Anything else.
  error,
}

final class SpeechResult {
  const SpeechResult(this.status, [this.text = '']);

  final SpeechStatus status;
  final String text;
}

/// The phone's own speech recogniser (works offline when the language pack is
/// installed). Tests replace it with a fake.
abstract interface class SpeechGateway {
  /// Listens until the person stops talking, then returns the words.
  /// [onPartial] receives the words so far.
  Future<SpeechResult> listen({
    required String localeId,
    void Function(String partial)? onPartial,
  });

  /// Ends listening early; [listen] then returns what was heard.
  Future<void> stop();

  /// Ends listening and drops the words.
  Future<void> cancel();
}

/// Records a few seconds of audio so Gemini can transcribe it when the phone
/// has no speech recogniser.
abstract interface class AudioRecorderGateway {
  /// Starts recording. False when the microphone is not allowed.
  Future<bool> start();

  /// Stops and returns the recording as WAV bytes, or null when there is none.
  Future<Uint8List?> stop();

  Future<void> cancel();
}
