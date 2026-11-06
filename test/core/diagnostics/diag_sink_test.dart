import 'dart:io';

import 'package:akshaya/core/diagnostics/diag_sink.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('akshaya-diag-test');
  });

  tearDown(() async {
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  });

  group('MemoryDiagSink', () {
    test('keeps what is written', () async {
      final MemoryDiagSink sink = MemoryDiagSink()..write('a\n')..write('b\n');
      expect(await sink.read(), 'a\nb\n');
      await sink.clear();
      expect(await sink.read(), '');
    });

    test('drops the oldest whole lines past its limit', () async {
      final MemoryDiagSink sink = MemoryDiagSink(maxChars: 20);
      for (int i = 0; i < 10; i++) {
        sink.write('line $i\n');
      }
      final String text = await sink.read();
      expect(text.length, lessThanOrEqualTo(20));
      expect(text, endsWith('line 9\n'));
      expect(text, startsWith('line'));
    });
  });

  group('FileDiagSink', () {
    FileDiagSink make({int maxBytes = 1000}) =>
        FileDiagSink(directory: () async => dir, maxBytes: maxBytes);

    test('text written before open is kept and written afterwards', () async {
      final FileDiagSink sink = make()..write('early\n');
      await sink.open();
      sink.write('late\n');
      expect(await sink.read(), 'early\nlate\n');
      expect(File('${dir.path}/diagnostics.log').existsSync(), isTrue);
    });

    test('a second sink sees what the first one wrote', () async {
      final FileDiagSink first = make();
      await first.open();
      first.write('from the app\n');
      final FileDiagSink second = make();
      await second.open();
      second.write('from the worker\n');
      expect(await first.read(), 'from the app\nfrom the worker\n');
    });

    test('rotates into an older copy and keeps both readable', () async {
      final FileDiagSink sink = make(maxBytes: 30);
      await sink.open();
      for (int i = 0; i < 6; i++) {
        sink.write('entry number $i\n'); // 15 characters each
      }
      expect(File('${dir.path}/diagnostics.log.1').existsSync(), isTrue);
      final String text = await sink.read();
      expect(text, endsWith('entry number 5\n'));
      expect(text, contains('entry number 3'));
      // The oldest were dropped by a second rotation.
      expect(text, isNot(contains('entry number 0')));
    });

    test('clear removes both files', () async {
      final FileDiagSink sink = make(maxBytes: 20);
      await sink.open();
      for (int i = 0; i < 4; i++) {
        sink.write('entry number $i\n');
      }
      await sink.clear();
      expect(await sink.read(), '');
      expect(File('${dir.path}/diagnostics.log').existsSync(), isFalse);
      expect(File('${dir.path}/diagnostics.log.1').existsSync(), isFalse);
    });

    test('a folder that cannot be found never throws', () async {
      final FileDiagSink sink = FileDiagSink(
        directory: () async => throw const FileSystemException('no folder'),
      );
      sink.write('lost\n');
      await sink.open();
      sink.write('also lost\n');
      expect(await sink.read(), '');
      await sink.clear();
    });
  });
}
