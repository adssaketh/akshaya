import 'package:akshaya/features/ai/domain/ai_command_service.dart';
import 'package:akshaya/features/ai/domain/ai_failures.dart';
import 'package:akshaya/features/ai/domain/ai_settings.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ai_test_support.dart';

void main() {
  late MemoryUsageStore usage;
  int calls = 0;

  AiCommandService build() => AiCommandService(
    backend: FakeBackend(<Object>[kGoodJson]),
    usageStore: usage,
    readSettings: () => const AiSettings(noticeAccepted: true),
    promptTemplate: kTestPrompt,
    firebaseConfigured: true,
    now: () => DateTime(2026, 11, 4, 10),
    delay: (Duration d) async {},
  );

  Future<String> failing() async {
    calls++;
    throw Exception('503 unavailable');
  }

  setUp(() {
    usage = MemoryUsageStore();
    calls = 0;
  });

  test('by default a failing call is tried three times', () async {
    await expectLater(build().guardedCall(failing), throwsA(isA<AiFailure>()));
    expect(calls, 3);
    expect(usage.usage.count, 3);
  });

  test('attempts: 1 means one try and one counted call', () async {
    await expectLater(
      build().guardedCall(failing, attempts: 1),
      throwsA(isA<AiFailure>()),
    );
    expect(calls, 1);
    expect(usage.usage.count, 1);
  });

  test('attempts can never exceed the usual three', () async {
    await expectLater(
      build().guardedCall(failing, attempts: 50),
      throwsA(isA<AiFailure>()),
    );
    expect(calls, 3);
  });

  test('attempts below one still make one try', () async {
    await expectLater(
      build().guardedCall(failing, attempts: 0),
      throwsA(isA<AiFailure>()),
    );
    expect(calls, 1);
  });

  test('a success is one call whatever attempts says', () async {
    final String answer = await build().guardedCall(
      () async => 'fine',
      attempts: 1,
    );
    expect(answer, 'fine');
    expect(usage.usage.count, 1);
  });
}
