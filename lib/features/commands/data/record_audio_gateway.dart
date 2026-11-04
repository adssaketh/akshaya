import 'dart:io';
import 'dart:typed_data';

import 'package:record/record.dart';

import '../domain/speech_gateway.dart';

/// [AudioRecorderGateway] backed by the `record` plugin: 16 kHz mono WAV in
/// the app's cache folder, deleted right after it is read.
final class RecordAudioGateway implements AudioRecorderGateway {
  RecordAudioGateway() : _recorder = AudioRecorder();

  final AudioRecorder _recorder;
  String? _path;

  @override
  Future<bool> start() async {
    if (!await _recorder.hasPermission()) {
      return false;
    }
    final String path =
        '${Directory.systemTemp.path}/akshaya_voice_${DateTime.now().microsecondsSinceEpoch}.wav';
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: path,
    );
    _path = path;
    return true;
  }

  @override
  Future<Uint8List?> stop() async {
    final String? written = await _recorder.stop();
    final String? path = written ?? _path;
    _path = null;
    if (path == null) {
      return null;
    }
    final File file = File(path);
    try {
      if (!await file.exists()) {
        return null;
      }
      return await file.readAsBytes();
    } finally {
      try {
        await file.delete();
      } on Object {
        // Left in the cache folder, which the system clears.
      }
    }
  }

  @override
  Future<void> cancel() async {
    await _recorder.cancel();
    final String? path = _path;
    _path = null;
    if (path != null) {
      try {
        await File(path).delete();
      } on Object {
        // Nothing to clean up.
      }
    }
  }
}
