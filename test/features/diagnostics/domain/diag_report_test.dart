import 'package:akshaya/core/diagnostics/app_info.dart';
import 'package:akshaya/core/diagnostics/diag_entry.dart';
import 'package:akshaya/features/diagnostics/domain/diag_report.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const AppInfo info = AppInfo(
    version: '1.0.8',
    build: '9',
    mode: 'release',
    device: 'Google Pixel 7',
    system: 'Android 15 (API 35)',
    locale: 'en_IN',
  );
  final DateTime created = DateTime.utc(2026, 11, 6, 10);

  DiagEntry entry(int i, {DiagLevel level = DiagLevel.info, String? stack}) =>
      DiagEntry(
        time: DateTime.utc(2026, 11, 6, 9, i),
        level: level,
        tag: 'app',
        message: 'event $i',
        stack: stack,
      );

  test('has the build, the counts and the log, in that order', () {
    final String report = DiagReport.build(
      info: info,
      state: const <MapEntry<String, String>>[
        MapEntry<String, String>('Items', '12'),
        MapEntry<String, String>('Sync', 'off'),
      ],
      entries: <DiagEntry>[entry(1), entry(2, level: DiagLevel.error, stack: '#0 a')],
      createdAt: created,
    );
    final int build = report.indexOf('== Build ==');
    final int state = report.indexOf('== State (counts only) ==');
    final int log = report.indexOf('== Log');
    expect(build, greaterThanOrEqualTo(0));
    expect(state, greaterThan(build));
    expect(log, greaterThan(state));
    expect(report, contains('App: 1.0.8+9'));
    expect(report, contains('Phone: Google Pixel 7'));
    expect(report, contains('Items: 12'));
    expect(report, contains('Created: 2026-11-06T10:00:00.000Z'));
    expect(report, contains('last 2 of 2 entries'));
    expect(report, contains(' E app event 2\n\t#0 a\n'));
    expect(report.indexOf('event 1'), lessThan(report.indexOf('event 2')));
  });

  test('a long log keeps the newest entries', () {
    final List<DiagEntry> entries = <DiagEntry>[
      for (int i = 0; i < 50; i++) entry(i),
    ];
    final String report = DiagReport.build(
      info: info,
      state: const <MapEntry<String, String>>[],
      entries: entries,
      createdAt: created,
      maxLogChars: 300,
    );
    expect(report, contains('event 49'));
    expect(report, isNot(contains('event 0\n')));
    expect(report, matches(RegExp(r'last \d+ of 50 entries')));
  });

  test('an empty log still produces a report', () {
    final String report = DiagReport.build(
      info: info,
      state: const <MapEntry<String, String>>[],
      entries: const <DiagEntry>[],
      createdAt: created,
    );
    expect(report, contains('last 0 of 0 entries'));
  });
}
