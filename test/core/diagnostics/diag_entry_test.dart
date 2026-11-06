import 'package:akshaya/core/diagnostics/diag_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final DateTime t = DateTime.utc(2026, 11, 6, 9, 25, 1, 123);

  test('format writes one line, then one tab-indented line per frame', () {
    final DiagEntry entry = DiagEntry(
      time: t,
      level: DiagLevel.error,
      tag: 'sync',
      message: 'Sync failed',
      stack: '#0 a (package:x/a.dart:1)\n#1 b (package:x/b.dart:2)',
    );
    expect(
      entry.format(),
      '2026-11-06T09:25:01.123Z E sync Sync failed\n'
      '\t#0 a (package:x/a.dart:1)\n'
      '\t#1 b (package:x/b.dart:2)\n',
    );
  });

  test('parseAll reads entries and their frames back', () {
    final DiagEntry a = DiagEntry(
      time: t,
      level: DiagLevel.error,
      tag: 'sync',
      message: 'Sync failed',
      stack: '#0 a\n#1 b',
    );
    final DiagEntry b = DiagEntry(
      time: t.add(const Duration(seconds: 5)),
      level: DiagLevel.info,
      tag: 'app',
      message: 'Resumed',
    );
    final List<DiagEntry> parsed = DiagEntry.parseAll(a.format() + b.format());
    expect(parsed, hasLength(2));
    expect(parsed[0].level, DiagLevel.error);
    expect(parsed[0].tag, 'sync');
    expect(parsed[0].message, 'Sync failed');
    expect(parsed[0].stack, '#0 a\n#1 b');
    expect(parsed[0].time, t);
    expect(parsed[1].level, DiagLevel.info);
    expect(parsed[1].stack, isNull);
    expect(parsed[1].time, t.add(const Duration(seconds: 5)));
  });

  test('newlines inside a message survive a round trip', () {
    final DiagEntry entry = DiagEntry(
      time: t,
      level: DiagLevel.warning,
      tag: 'ai',
      message: 'first\nsecond',
    );
    final String text = entry.format();
    expect('\n'.allMatches(text).length, 1);
    expect(DiagEntry.parseAll(text).single.message, 'first\nsecond');
  });

  test('a tag with spaces is stored without them', () {
    final DiagEntry entry = DiagEntry(
      time: t,
      level: DiagLevel.info,
      tag: 'two words',
      message: 'x',
    );
    expect(DiagEntry.parseAll(entry.format()).single.tag, 'two_words');
  });

  test('garbage and orphan frames are skipped', () {
    final String text = '\t#0 orphan frame\n'
        'not a log line\n'
        '2026-11-06T09:25:01.123Z I app Start\n'
        'another bad line\n'
        '\t#0 real frame\n';
    final List<DiagEntry> parsed = DiagEntry.parseAll(text);
    expect(parsed, hasLength(1));
    expect(parsed.single.message, 'Start');
    expect(parsed.single.stack, '#0 real frame');
  });

  test('an empty message still parses', () {
    final DiagEntry entry = DiagEntry(
      time: t,
      level: DiagLevel.info,
      tag: 'app',
      message: '',
    );
    expect(DiagEntry.parseAll(entry.format()).single.message, '');
  });
}
