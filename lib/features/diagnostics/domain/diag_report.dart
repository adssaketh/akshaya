import '../../../core/diagnostics/app_info.dart';
import '../../../core/diagnostics/diag_entry.dart';

/// The plain-text report a person can share when something goes wrong: which
/// build and phone, counts of what is stored (never the items themselves), and
/// the diagnostics log.
abstract final class DiagReport {
  /// [state] is label and value pairs. [entries] are oldest first. When the
  /// log is longer than [maxLogChars], the newest part is kept.
  static String build({
    required AppInfo info,
    required List<MapEntry<String, String>> state,
    required List<DiagEntry> entries,
    required DateTime createdAt,
    int maxLogChars = 60000,
  }) {
    final StringBuffer out = StringBuffer()
      ..writeln('Akshaya Patra diagnostics report')
      ..writeln('Created: ${createdAt.toUtc().toIso8601String()}')
      ..writeln()
      ..writeln('== Build ==');
    for (final MapEntry<String, String> row in info.rows()) {
      out.writeln('${row.key}: ${row.value}');
    }
    out
      ..writeln()
      ..writeln('== State (counts only) ==');
    for (final MapEntry<String, String> row in state) {
      out.writeln('${row.key}: ${row.value}');
    }

    final List<String> blocks = <String>[];
    int used = 0;
    for (int i = entries.length - 1; i >= 0; i--) {
      final String block = entries[i].format();
      if (blocks.isNotEmpty && used + block.length > maxLogChars) {
        break;
      }
      blocks.add(block);
      used += block.length;
    }
    out
      ..writeln()
      ..writeln(
        '== Log (last ${blocks.length} of ${entries.length} entries, '
        'oldest first; times are UTC) ==',
      )
      ..write(blocks.reversed.join());
    return out.toString();
  }
}
