import 'dart:convert';

/// How serious a diagnostics entry is.
enum DiagLevel {
  info('I'),
  warning('W'),
  error('E');

  const DiagLevel(this.code);

  /// One letter used in the log file.
  final String code;

  static DiagLevel? fromCode(String code) {
    for (final DiagLevel level in values) {
      if (level.code == code) {
        return level;
      }
    }
    return null;
  }
}

/// One line of the diagnostics log, with an optional stack trace.
///
/// File format (one entry):
///
/// ```
/// 2026-11-06T09:25:01.123Z E sync Sync failed: StateError: ...
/// <TAB>#0 SyncEngine.run (package:akshaya/...)
/// <TAB>#1 ...
/// ```
///
/// Newlines inside a message are written as the two characters `\n`.
final class DiagEntry {
  const DiagEntry({
    required this.time,
    required this.level,
    required this.tag,
    required this.message,
    this.stack,
  });

  /// UTC instant.
  final DateTime time;
  final DiagLevel level;

  /// Short area name without spaces: `sync`, `ai`, `alerts`, `app`.
  final String tag;
  final String message;
  final String? stack;

  static final RegExp _line = RegExp(
    r'^(\d{4}-\d{2}-\d{2}T\S+) ([IWE]) (\S+) ?(.*)$',
  );

  /// The text appended to the log file for this entry (ends with a newline).
  String format() {
    final StringBuffer out = StringBuffer()
      ..write(time.toUtc().toIso8601String())
      ..write(' ')
      ..write(level.code)
      ..write(' ')
      ..write(tag.replaceAll(RegExp(r'\s+'), '_'))
      ..write(' ')
      ..write(message.replaceAll('\r', '').replaceAll('\n', r'\n'))
      ..write('\n');
    final String? frames = stack;
    if (frames != null) {
      for (final String line in const LineSplitter().convert(frames)) {
        if (line.trim().isEmpty) {
          continue;
        }
        out
          ..write('\t')
          ..write(line)
          ..write('\n');
      }
    }
    return out.toString();
  }

  /// Reads a log file's text back into entries, oldest first. Lines that do
  /// not look like entries (for example the cut-off start of a rotated file)
  /// are skipped.
  static List<DiagEntry> parseAll(String text) {
    final List<DiagEntry> result = <DiagEntry>[];
    DiagEntry? head;
    final List<String> frames = <String>[];

    for (final String raw in const LineSplitter().convert(text)) {
      if (raw.startsWith('\t')) {
        if (head != null) {
          frames.add(raw.substring(1));
        }
        continue;
      }
      final RegExpMatch? match = _line.firstMatch(raw);
      final DateTime? time = match == null ? null : DateTime.tryParse(match[1]!);
      final DiagLevel? level = match == null ? null : DiagLevel.fromCode(match[2]!);
      if (match == null || time == null || level == null) {
        continue;
      }
      if (head != null) {
        result.add(_withFrames(head, frames));
      }
      frames.clear();
      head = DiagEntry(
        time: time.toUtc(),
        level: level,
        tag: match[3]!,
        message: match[4]!.replaceAll(r'\n', '\n'),
      );
    }
    if (head != null) {
      result.add(_withFrames(head, frames));
    }
    return result;
  }

  static DiagEntry _withFrames(DiagEntry entry, List<String> frames) {
    if (frames.isEmpty) {
      return entry;
    }
    return DiagEntry(
      time: entry.time,
      level: entry.level,
      tag: entry.tag,
      message: entry.message,
      stack: frames.join('\n'),
    );
  }
}
