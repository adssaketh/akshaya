import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'diag_entry.dart';
import 'diag_log.dart';
import 'diag_sink.dart';

/// The app's diagnostics log. Use it where an error is caught and would
/// otherwise vanish, and for a few plain "what was happening" breadcrumbs.
///
/// ```dart
/// Diag.error('sync', 'Sync failed', error: error, stack: stack);
/// Diag.info('app', 'Resumed');
/// ```
///
/// Rules for what goes in a message:
/// * never item names, shopping entries, notes, recipe text, names or e-mail
///   addresses: counts, ids of kinds ("expired"), and error types are fine;
/// * never the text sent to or received from the AI.
///
/// Until [init] finishes, entries are kept in memory and then moved to the
/// file, so nothing logged at start-up is lost. In tests nothing touches the
/// file system unless a test calls [init] with its own folder.
abstract final class Diag {
  static final DiagLog _log = DiagLog();
  static Future<void>? _initializing;

  static DiagLog get log => _log;

  /// Starts keeping the log in a file. Safe to call from every isolate (the
  /// app and its background tasks) and more than once.
  static Future<void> init({Future<Directory> Function()? directory}) {
    return _initializing ??= _init(directory ?? _defaultDirectory);
  }

  static Future<void> _init(Future<Directory> Function() directory) async {
    try {
      final DiagSink early = _log.sink;
      final FileDiagSink file = FileDiagSink(directory: directory);
      await file.open();
      _log.useSink(file);
      if (early is MemoryDiagSink) {
        final String held = await early.read();
        if (held.isNotEmpty) {
          file.write(held);
        }
      }
    } on Object {
      // Stay on the in-memory log.
    }
  }

  static Future<Directory> _defaultDirectory() async {
    try {
      final Directory support = await getApplicationSupportDirectory();
      return Directory('${support.path}${Platform.pathSeparator}diagnostics');
    } on Object {
      return Directory(
        '${Directory.systemTemp.path}${Platform.pathSeparator}akshaya-diag',
      );
    }
  }

  static void info(String tag, String message) =>
      _log.log(DiagLevel.info, tag, message);

  static void warn(
    String tag,
    String message, {
    Object? error,
    StackTrace? stack,
  }) =>
      _log.log(DiagLevel.warning, tag, message, error: error, stack: stack);

  static void error(
    String tag,
    String message, {
    Object? error,
    StackTrace? stack,
  }) =>
      _log.log(DiagLevel.error, tag, message, error: error, stack: stack);
}
