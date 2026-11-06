import 'package:flutter/foundation.dart';

import 'diag_entry.dart';
import 'diag_redactor.dart';
import 'diag_sink.dart';

/// Writes diagnostics entries to a [DiagSink] and tells listeners (the
/// Diagnostics screen) that something new arrived.
///
/// Logging never throws.
final class DiagLog extends ChangeNotifier {
  DiagLog({DiagSink? sink, DateTime Function()? clock})
      : _sink = sink ?? MemoryDiagSink(),
        _clock = clock ?? DateTime.now;

  DiagSink _sink;
  final DateTime Function() _clock;

  DiagSink get sink => _sink;

  /// Switches where entries go (memory at first, the file once it is ready).
  void useSink(DiagSink sink) {
    _sink = sink;
  }

  void log(
    DiagLevel level,
    String tag,
    String message, {
    Object? error,
    StackTrace? stack,
  }) {
    try {
      final String text =
          error == null ? message : '$message: ${error.runtimeType}: $error';
      final DiagEntry entry = DiagEntry(
        time: _clock().toUtc(),
        level: level,
        tag: tag,
        message: DiagRedactor.clean(text),
        stack: stack == null ? null : DiagRedactor.trimStack(stack.toString()),
      );
      final String line = entry.format();
      _sink.write(line);
      if (kDebugMode && level != DiagLevel.info) {
        debugPrint(line.trimRight());
      }
      notifyListeners();
    } on Object {
      // Logging must never break the app.
    }
  }

  /// All entries kept, oldest first.
  Future<List<DiagEntry>> entries() async {
    return DiagEntry.parseAll(await _sink.read());
  }

  /// The raw log text, oldest first.
  Future<String> rawText() => _sink.read();

  Future<void> clear() async {
    await _sink.clear();
    notifyListeners();
  }
}
