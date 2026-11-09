import 'package:akshaya/features/ai/domain/ai_command_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('failureHint', () {
    test('picks out the error code, the keyword and the status', () {
      final String hint = AiCommandService.failureHint(
        Exception(
          '[firebase_app_check/unknown] App attestation failed: '
          'Play Integrity returned 403',
        ),
      );
      expect(hint, contains('[firebase_app_check/unknown]'));
      expect(hint, contains('attestation'));
      expect(hint, contains('play integrity'));
      expect(hint, contains('403'));
    });

    test('recognises a model that is not found', () {
      final String hint = AiCommandService.failureHint(
        Exception('models/gemini-x is not found for API version (404)'),
      );
      expect(hint, contains('not found'));
      expect(hint, contains('404'));
    });

    test('never repeats free text such as what the person said', () {
      final String hint = AiCommandService.failureHint(
        Exception('Bad request for "add 2 kg rice and 6 eggs" (400)'),
      );
      expect(hint, isNot(contains('rice')));
      expect(hint, isNot(contains('eggs')));
      expect(hint, '400');
    });

    test('is empty when the error says nothing useful', () {
      expect(AiCommandService.failureHint(Exception('boom')), isEmpty);
    });
  });
}
