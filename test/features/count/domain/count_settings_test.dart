import 'package:akshaya/features/count/domain/count_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CountSettings.fromMap', () {
    test('uses defaults when nothing is stored', () {
      final CountSettings s = CountSettings.fromMap(const <String, String>{});
      expect(s.reminderEnabled, isFalse);
      expect(s.reminderDay, 1);
      expect(s.lastCompletedOn, isNull);
      expect(s.lastCountedLabel, 'Never counted');
    });

    test('reads stored values', () {
      final CountSettings s = CountSettings.fromMap(const <String, String>{
        CountSettingKeys.reminderEnabled: 'true',
        CountSettingKeys.reminderDay: '15',
        CountSettingKeys.lastCompletedOn: '2026-11-04',
      });
      expect(s.reminderEnabled, isTrue);
      expect(s.reminderDay, 15);
      expect(s.lastCompletedOn, DateTime(2026, 11, 4));
      expect(s.lastCountedLabel, 'Last counted 4 Nov 2026');
    });

    test('clamps the day and ignores damaged values', () {
      expect(
        CountSettings.fromMap(const <String, String>{
          CountSettingKeys.reminderDay: '40',
        }).reminderDay,
        28,
      );
      expect(
        CountSettings.fromMap(const <String, String>{
          CountSettingKeys.reminderDay: '0',
        }).reminderDay,
        1,
      );
      final CountSettings bad = CountSettings.fromMap(const <String, String>{
        CountSettingKeys.reminderDay: 'x',
        CountSettingKeys.lastCompletedOn: 'yesterday',
      });
      expect(bad.reminderDay, 1);
      expect(bad.lastCompletedOn, isNull);
    });

    test('toMap round-trips', () {
      final CountSettings s = CountSettings(
        reminderEnabled: true,
        reminderDay: 9,
        lastCompletedOn: DateTime(2026, 10, 2),
      );
      expect(CountSettings.fromMap(s.toMap()), s);
    });
  });

  group('reminderDueOn', () {
    final CountSettings on = CountSettings(
      reminderEnabled: true,
      reminderDay: 6,
      lastCompletedOn: DateTime(2026, 10, 20),
    );

    test('is due on the chosen day', () {
      expect(on.reminderDueOn(DateTime(2026, 11, 6)), isTrue);
      expect(on.reminderDueOn(DateTime(2026, 11, 7)), isFalse);
    });

    test('is off by default', () {
      expect(const CountSettings().reminderDueOn(DateTime(2026, 11, 1)), isFalse);
    });

    test('is skipped when already counted that month', () {
      final CountSettings done = CountSettings(
        reminderEnabled: true,
        reminderDay: 6,
        lastCompletedOn: DateTime(2026, 11, 2),
      );
      expect(done.reminderDueOn(DateTime(2026, 11, 6)), isFalse);
      expect(done.reminderDueOn(DateTime(2026, 12, 6)), isFalse);
      expect(done.countedInMonthOf(DateTime(2026, 11, 30)), isTrue);
    });
  });
}
