import 'package:akshaya/core/diagnostics/diag_redactor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('e-mail addresses are removed', () {
    expect(
      DiagRedactor.clean('Sign-in failed for asha.k+test@example.co.in today'),
      'Sign-in failed for <email> today',
    );
  });

  test('API keys, bearer tokens and secret query values are removed', () {
    final String out = DiagRedactor.clean(
      'GET https://x.test/v1?key=abc123&alt=json '
      'with Bearer eyJhbGciOi.payload.sig '
      'and AIzaSyA1234567890abcdefghijklmnopqrstuvw',
    );
    expect(out, isNot(contains('abc123')));
    expect(out, isNot(contains('eyJhbGciOi')));
    expect(out, isNot(contains('AIzaSy')));
    expect(out, contains('alt=json'));
    expect(out, contains('<key>'));
    expect(out, contains('Bearer <token>'));
    expect(out, contains('?key=<redacted>'));
  });

  test('long messages are cut', () {
    final String out = DiagRedactor.clean('x' * 1000, maxLength: 50);
    expect(out.length, 53);
    expect(out, endsWith('...'));
  });

  test('plain text is left alone', () {
    expect(DiagRedactor.clean('Sync failed'), 'Sync failed');
  });

  test('trimStack keeps the first lines and says how many were dropped', () {
    final String stack = List<String>.generate(5, (int i) => '#$i frame').join('\n');
    final String out = DiagRedactor.trimStack(stack, maxLines: 3);
    expect(out.split('\n'), <String>[
      '#0 frame',
      '#1 frame',
      '#2 frame',
      '... (2 more lines)',
    ]);
    expect(DiagRedactor.trimStack(stack), stack);
  });
}
