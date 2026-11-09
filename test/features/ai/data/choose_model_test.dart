import 'package:akshaya/features/ai/data/firebase_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const String fallback = 'gemini-default';

  group('chooseModelName', () {
    test('the phone\'s own choice wins over the server and the default', () {
      expect(
        chooseModelName(
          override: 'gemini-3.5-flash-lite',
          remote: 'gemini-3.8-flash',
          fallback: fallback,
        ),
        'gemini-3.5-flash-lite',
      );
    });

    test('with no choice, the server decides', () {
      expect(
        chooseModelName(
          override: '',
          remote: 'gemini-3.8-flash',
          fallback: fallback,
        ),
        'gemini-3.8-flash',
      );
      expect(
        chooseModelName(override: null, remote: 'x', fallback: fallback),
        'x',
      );
    });

    test('with neither, the built-in default is used', () {
      expect(chooseModelName(fallback: fallback), fallback);
      expect(
        chooseModelName(override: '  ', remote: ' ', fallback: fallback),
        fallback,
      );
    });

    test('stray spaces are ignored', () {
      expect(
        chooseModelName(override: '  gemini-x ', fallback: fallback),
        'gemini-x',
      );
    });
  });

  test('the runtime reads the phone\'s choice each time it is asked', () {
    String? chosen;
    final FirebaseRuntime runtime = FirebaseRuntime(modelOverride: () => chosen);
    chosen = 'gemini-3.1-flash-lite';
    expect(runtime.modelName(), 'gemini-3.1-flash-lite');
    chosen = 'gemini-3.5-flash-lite';
    expect(runtime.modelName(), 'gemini-3.5-flash-lite');
    chosen = '';
    expect(runtime.modelName(), isNotEmpty);
    expect(runtime.modelName(), isNot('gemini-3.5-flash-lite'));
  });
}
