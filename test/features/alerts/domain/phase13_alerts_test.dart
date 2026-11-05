import 'package:akshaya/features/alerts/domain/alert_action.dart';
import 'package:akshaya/features/alerts/domain/alert_plan.dart';
import 'package:akshaya/features/alerts/domain/alert_settings.dart';
import 'package:akshaya/features/alerts/domain/alert_snoozes.dart';
import 'package:akshaya/features/alerts/domain/quiet_hours.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('QuietHours', () {
    const AlertSettings s = AlertSettings(
      quietEnabled: true,
      quietStart: 22 * 60,
      quietEnd: 7 * 60,
    );

    test('leaves daytime alone', () {
      final DateTime at = DateTime.utc(2026, 11, 4, 9);
      expect(QuietHours.shift(at, s), at);
    });

    test('moves a late-night time to next morning', () {
      expect(
        QuietHours.shift(DateTime.utc(2026, 11, 4, 23, 30), s),
        DateTime.utc(2026, 11, 5, 7),
      );
    });

    test('moves an early-morning time to the same morning', () {
      expect(
        QuietHours.shift(DateTime.utc(2026, 11, 5, 5), s),
        DateTime.utc(2026, 11, 5, 7),
      );
    });

    test('disabled means no shift', () {
      final DateTime at = DateTime.utc(2026, 11, 4, 23);
      expect(QuietHours.shift(at, s.copyWith(quietEnabled: false)), at);
    });
  });

  group('AlertSnoozes', () {
    test('hides through tomorrow, then shows again', () {
      final AlertSnoozes s =
          const AlertSnoozes().snooze(<String>['a'], today: DateTime(2026, 11, 4));
      expect(s.hides('a', DateTime(2026, 11, 4)), isTrue);
      expect(s.hides('a', DateTime(2026, 11, 5)), isTrue);
      expect(s.hides('a', DateTime(2026, 11, 6)), isFalse);
      expect(s.hides('b', DateTime(2026, 11, 4)), isFalse);
    });

    test('round-trips and prunes old snoozes', () {
      final AlertSnoozes s = const AlertSnoozes()
          .snooze(<String>['a'], today: DateTime(2026, 11, 1))
          .snooze(<String>['b'], today: DateTime(2026, 11, 10));
      expect(s.hiddenThrough.containsKey('a'), isFalse);
      expect(AlertSnoozes.fromMap(s.toMap()), s);
    });
  });

  group('AlertSettings', () {
    test('new options default and round-trip', () {
      const AlertSettings d = AlertSettings();
      expect(d.expired && d.expiring && d.prep && d.household, isTrue);
      expect(d.quietEnabled, isFalse);
      final AlertSettings c = d.copyWith(
        expired: false,
        household: false,
        quietEnabled: true,
        quietStart: 23 * 60,
      );
      expect(AlertSettings.fromMap(c.toMap()), c);
    });
  });

  group('AlertAction and AlertPayload', () {
    test('ids map back', () {
      for (final AlertAction a in AlertAction.values) {
        expect(AlertAction.fromId(a.id), a);
      }
      expect(AlertAction.fromId('nope'), isNull);
      expect(AlertAction.showRecipes.opensApp, isTrue);
      expect(AlertAction.usedIt.opensApp, isFalse);
    });

    test('payload round-trips with and without an item', () {
      final AlertPayload p =
          AlertPayload(AlertTarget.pantryExpiring, itemId: 'item-1');
      final AlertPayload? back = AlertPayload.parse(p.encode());
      expect(back?.target, AlertTarget.pantryExpiring);
      expect(back?.itemId, 'item-1');
      expect(AlertPayload.parse('recipes:open')?.itemId, isNull);
    });
  });
}
