import 'dart:convert';
import 'dart:io';

/// Where diagnostics text is kept. Writing must never throw: a problem with
/// the log must not become a problem for the app.
abstract interface class DiagSink {
  /// Appends [text] (one or more complete lines).
  void write(String text);

  /// Everything kept so far, oldest first.
  Future<String> read();

  /// Forgets everything.
  Future<void> clear();
}

/// Keeps the log in memory only. Used before the file is ready and in tests.
final class MemoryDiagSink implements DiagSink {
  MemoryDiagSink({this.maxChars = 200000});

  final int maxChars;
  String _text = '';

  @override
  void write(String text) {
    _text += text;
    if (_text.length > maxChars) {
      final int cut = _text.indexOf('\n', _text.length - maxChars);
      _text = cut < 0 ? '' : _text.substring(cut + 1);
    }
  }

  @override
  Future<String> read() async => _text;

  @override
  Future<void> clear() async {
    _text = '';
  }
}

/// A log file with one older copy (`<name>.1`). When the file would pass
/// [maxBytes] it becomes the older copy, so the total stays under twice that.
///
/// The app and its background tasks (each its own isolate) append to the same
/// file. Each append is one small synchronous write, so lines do not mix.
final class FileDiagSink implements DiagSink {
  FileDiagSink({
    required this.directory,
    this.maxBytes = 256 * 1024,
    this.fileName = 'diagnostics.log',
  });

  /// Finds the folder the log lives in.
  final Future<Directory> Function() directory;
  final int maxBytes;
  final String fileName;

  File? _file;
  int _size = 0;
  bool _failed = false;
  Future<void>? _opening;
  final List<String> _waiting = <String>[];

  /// Finds the folder. Text written before this finishes is held back and
  /// written afterwards. Safe to call more than once.
  Future<void> open() => _opening ??= _open();

  Future<void> _open() async {
    try {
      final Directory dir = await directory();
      await dir.create(recursive: true);
      final File file = File('${dir.path}${Platform.pathSeparator}$fileName');
      _size = await file.exists() ? await file.length() : 0;
      _file = file;
      final String held = _waiting.join();
      _waiting.clear();
      if (held.isNotEmpty) {
        _append(held);
      }
    } on Object {
      // No folder, no log file. The app carries on without one.
      _failed = true;
      _waiting.clear();
    }
  }

  @override
  void write(String text) {
    if (_failed) {
      return;
    }
    if (_file == null) {
      if (_waiting.length < 500) {
        _waiting.add(text);
      }
      return;
    }
    _append(text);
  }

  void _append(String text) {
    final File? file = _file;
    if (file == null) {
      return;
    }
    try {
      if (_size > 0 && _size + text.length > maxBytes) {
        _rotate(file);
      }
      file.writeAsStringSync(text, mode: FileMode.append, flush: true);
      _size += text.length;
    } on Object {
      // Never let logging break the app.
    }
  }

  void _rotate(File file) {
    try {
      final File older = File('${file.path}.1');
      if (older.existsSync()) {
        older.deleteSync();
      }
      if (file.existsSync()) {
        file.renameSync(older.path);
      }
    } on Object {
      // Keep appending to the current file if the rename fails.
    }
    _size = 0;
  }

  @override
  Future<String> read() async {
    await open();
    final File? file = _file;
    if (file == null) {
      return _waiting.join();
    }
    final StringBuffer out = StringBuffer();
    try {
      final File older = File('${file.path}.1');
      if (await older.exists()) {
        out.write(utf8.decode(await older.readAsBytes(), allowMalformed: true));
      }
      if (await file.exists()) {
        out.write(utf8.decode(await file.readAsBytes(), allowMalformed: true));
      }
    } on Object {
      // Return whatever was readable.
    }
    return out.toString();
  }

  @override
  Future<void> clear() async {
    await open();
    final File? file = _file;
    _waiting.clear();
    _size = 0;
    if (file == null) {
      return;
    }
    for (final File f in <File>[file, File('${file.path}.1')]) {
      try {
        if (await f.exists()) {
          await f.delete();
        }
      } on Object {
        // A file that cannot be deleted is left as it is.
      }
    }
  }
}
