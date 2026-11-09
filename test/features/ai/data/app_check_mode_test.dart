import 'package:akshaya/features/ai/data/firebase_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('chooseAppCheckMode', () {
    test('a fixed token is used in a release build', () {
      expect(
        chooseAppCheckMode(debugBuild: false, debugToken: 'abc-123'),
        AppCheckMode.fixedDebugToken,
      );
    });

    test('a fixed token is used in a debug build too', () {
      expect(
        chooseAppCheckMode(debugBuild: true, debugToken: 'abc-123'),
        AppCheckMode.fixedDebugToken,
      );
    });

    test('without a token a release build uses Play Integrity', () {
      expect(
        chooseAppCheckMode(debugBuild: false, debugToken: ''),
        AppCheckMode.playIntegrity,
      );
    });

    test('without a token a debug build uses the debug provider', () {
      expect(
        chooseAppCheckMode(debugBuild: true, debugToken: ''),
        AppCheckMode.debug,
      );
    });

    test('a token of only spaces counts as no token', () {
      expect(
        chooseAppCheckMode(debugBuild: false, debugToken: '   '),
        AppCheckMode.playIntegrity,
      );
    });
  });
}
