import 'dart:io';

import 'package:akshaya/core/diagnostics/diag.dart';
import 'package:akshaya/core/diagnostics/diag_entry.dart';
import 'package:akshaya/core/diagnostics/diag_log.dart';
import 'package:akshaya/core/diagnostics/diag_sink.dart';
import 'package:flutter_test/flutter_test.dart';

class _ThrowingSink implements DiagSink {
  @override
  void write(String text) => throw StateError('disk full');

  @override
  Future<String> read() async => '';

  @override
  Future<void> clear() async {}
}

void main() {
  final DateTime fixed = DateTime.utc(2026, 11, 6, 9, 25);

  DiagLog make([DiagSink? sink]) =>
      DiagLog(sink: sink, clock: () => fixed);

  test('logs a message with its level, tag and time', () async {
    final DiagLog log = make();
    log.log(DiagLevel.warning, 'ai', 'Quota reached');
    final List<DiagEntry> entries = await log.entries();
    expect(entries, hasLength(1));
    expect(entries.single.level, DiagLevel.warning);
    expect(entries.single.tag, 'ai');
    expect(entries.single.message, 'Quota reached');
    expect(entries.single.time, fixed);
  });

  test('an error adds its type and text, and keeps the stack', () async {
    final DiagLog log = make();
    log.log(
      DiagLevel.error,
      'sync',
      'Sync failed',
      error: StateError('boom'),
      stack: StackTrace.fromString('#0 a (package:x/a.dart:1)\n#1 b'),
    );
    final DiagEntry entry = (await log.entries()).single;
    expect(entry.message, 'Sync failed: StateError: Bad state: boom');
    expect(entry.stack, '#0 a (package:x/a.dart:1)\n#1 b');
  });

  test('e-mail addresses never reach the log', () async {
    final DiagLog log = make();
    log.log(
      DiagLevel.error,
      'sync',
      'Sign-in failed',
      error: Exception('user asha@example.com not found'),
    );
    final String raw = await log.rawText();
    expect(raw, isNot(contains('asha@example.com')));
    expect(raw, contains('<email>'));
  });

  test('listeners are told about each entry', () {
    final DiagLog log = make();
    int calls = 0;
    log.addListener(() => calls++);
    log.log(DiagLevel.info, 'app', 'one');
    log.log(DiagLevel.info, 'app', 'two');
    expect(calls, 2);
  });

  test('a sink that throws does not throw out of log()', () {
    final DiagLog log = make(_ThrowingSink());
    expect(() => log.log(DiagLevel.error, 'app', 'x'), returnsNormally);
  });

  test('clear empties the log and tells listeners', () async {
    final DiagLog log = make();
    log.log(DiagLevel.info, 'app', 'one');
    int calls = 0;
    log.addListener(() => calls++);
    await log.clear();
    expect(await log.entries(), isEmpty);
    expect(calls, 1);
  });

  test('Diag.init moves early entries into the file', () async {
    final Directory dir =
        await Directory.systemTemp.createTemp('akshaya-diag-init');
    addTearDown(() => dir.delete(recursive: true));

    Diag.info('app', 'logged before the file was ready');
    await Diag.init(directory: () async => dir);
    Diag.error('app', 'logged after', error: StateError('x'));

    final String file =
        await File('${dir.path}/diagnostics.log').readAsString();
    expect(file, contains('logged before the file was ready'));
    expect(file, contains('logged after: StateError: Bad state: x'));

    // A second call does nothing.
    await Diag.init(directory: () async => dir);
    expect(
      'logged before the file was ready'.allMatches(file).length,
      1,
    );
  });
}
