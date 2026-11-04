import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Enforces the design-system rule: raw colour values live only in
/// lib/core/design/tokens/akshaya_colors.dart. Everything else must read
/// colours from the theme tokens.
void main() {
  test('no raw colours in lib/ outside the token file', () {
    final RegExp rawColor = RegExp(
      r'\bColor\(\s*0x|\bColor\.fromARGB|\bColor\.fromRGBO|\bColors\.(?!transparent)',
    );
    final List<String> offenders = <String>[];

    final Iterable<File> files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((File f) => f.path.endsWith('.dart'));

    for (final File file in files) {
      final String path = file.path.replaceAll(r'\', '/');
      if (path.endsWith('core/design/tokens/akshaya_colors.dart')) continue;
      final List<String> lines = file.readAsLinesSync();
      for (int i = 0; i < lines.length; i++) {
        if (rawColor.hasMatch(lines[i])) {
          offenders.add('$path:${i + 1}: ${lines[i].trim()}');
        }
      }
    }

    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}
