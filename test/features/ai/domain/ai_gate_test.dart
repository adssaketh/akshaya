import 'package:akshaya/features/ai/domain/ai_gate.dart';
import 'package:akshaya/features/ai/domain/ai_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final DateTime today = DateTime(2026, 11, 4);
  final DateTime now = DateTime(2026, 11, 4, 10);
  const AiSettings on = AiSettings(noticeAccepted: true);

  AiAvailability check({
    AiSettings settings = on,
    AiUsage usage = const AiUsage(),
    bool configured = true,
    DateTime? cooldownUntil,
  }) {
    return AiGate.check(
      settings: settings,
      usage: usage,
      today: today,
      firebaseConfigured: configured,
      now: now,
      cooldownUntil: cooldownUntil,
    );
  }

  group('AiGate', () {
    test('is ready with everything in place', () {
      expect(check(), AiAvailability.ready);
      expect(AiAvailability.ready.message, isNull);
    });

    test('switched off wins over everything', () {
      expect(
        check(settings: on.copyWith(enabled: false), configured: false),
        AiAvailability.disabled,
      );
    });

    test('needs Firebase, then the notice', () {
      expect(check(configured: false), AiAvailability.notConfigured);
      expect(
        check(settings: const AiSettings()),
        AiAvailability.noticeNeeded,
      );
    });

    test('daily cap: allowed below it, blocked at it', () {
      final String key = AiUsage.dayKey(today);
      expect(
        check(usage: AiUsage(date: key, count: 49)),
        AiAvailability.ready,
      );
      expect(
        check(usage: AiUsage(date: key, count: 50)),
        AiAvailability.capReached,
      );
      expect(
        check(usage: AiUsage(date: key, count: 80)),
        AiAvailability.capReached,
      );
    });

    test('the cap follows the setting', () {
      final String key = AiUsage.dayKey(today);
      expect(
        check(
          settings: on.copyWith(dailyCap: 10),
          usage: AiUsage(date: key, count: 10),
        ),
        AiAvailability.capReached,
      );
    });

    test('a new day starts again at zero', () {
      expect(
        check(usage: const AiUsage(date: '2026-11-03', count: 50)),
        AiAvailability.ready,
      );
    });

    test('cooldown blocks until it ends', () {
      expect(
        check(cooldownUntil: now.add(const Duration(seconds: 30))),
        AiAvailability.coolingDown,
      );
      expect(
        check(cooldownUntil: now.subtract(const Duration(seconds: 1))),
        AiAvailability.ready,
      );
    });

    test('cap message tells the person offline mode is on', () {
      expect(
        AiAvailability.capReached.message,
        'AI limit reached for today, using offline mode.',
      );
    });
  });

  group('AiSettings and AiUsage', () {
    test('defaults', () {
      final AiSettings s = AiSettings.fromMap(const <String, String>{});
      expect(s.enabled, isTrue);
      expect(s.dailyCap, 50);
      expect(s.noticeAccepted, isFalse);
    });

    test('the cap is kept within limits', () {
      expect(
        AiSettings.fromMap(const <String, String>{AiSettingKeys.dailyCap: '1'})
            .dailyCap,
        kMinAiDailyCap,
      );
      expect(
        AiSettings.fromMap(
          const <String, String>{AiSettingKeys.dailyCap: '9999'},
        ).dailyCap,
        kMaxAiDailyCap,
      );
      expect(
        AiSettings.fromMap(
          const <String, String>{AiSettingKeys.dailyCap: 'abc'},
        ).dailyCap,
        50,
      );
    });

    test('incrementing counts within a day and resets on a new one', () {
      AiUsage usage = const AiUsage();
      usage = usage.incremented(today).incremented(today);
      expect(usage.countOn(today), 2);
      expect(usage.countOn(DateTime(2026, 11, 5)), 0);
      expect(usage.incremented(DateTime(2026, 11, 5)).count, 1);
    });
  });
}
