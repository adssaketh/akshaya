import 'package:akshaya/features/alerts/domain/alert_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AlertSettings', () {
    test('defaults: on, 8:00 am, 3 days, low stock included', () {
      const AlertSettings settings = AlertSettings();
      expect(settings.enabled, isTrue);
      expect(settings.minutesOfDay, 480);
      expect(settings.hour, 8);
      expect(settings.minute, 0);
      expect(settings.warningDays, 3);
      expect(settings.lowStock, isTrue);
      expect(AlertSettings.fromMap(const <String, String>{}), settings);
    });

    test('round-trips through the stored text form', () {
      const AlertSettings settings = AlertSettings(
        enabled: false,
        minutesOfDay: 19 * 60 + 45,
        warningDays: 7,
        lowStock: false,
      );
      expect(AlertSettings.fromMap(settings.toMap()), settings);
    });

    test('unreadable values fall back to the defaults', () {
      final AlertSettings settings = AlertSettings.fromMap(
        const <String, String>{
          AlertSettingKeys.enabled: 'maybe',
          AlertSettingKeys.minutesOfDay: 'noon',
          AlertSettingKeys.warningDays: '',
          AlertSettingKeys.lowStock: '1',
        },
      );
      expect(settings, const AlertSettings());
    });

    test('out-of-range numbers are brought back into range', () {
      final AlertSettings high = AlertSettings.fromMap(
        const <String, String>{
          AlertSettingKeys.minutesOfDay: '5000',
          AlertSettingKeys.warningDays: '99',
        },
      );
      expect(high.minutesOfDay, 1439);
      expect(high.warningDays, AlertSettings.maxWarningDays);

      final AlertSettings low = AlertSettings.fromMap(
        const <String, String>{
          AlertSettingKeys.minutesOfDay: '-5',
          AlertSettingKeys.warningDays: '0',
        },
      );
      expect(low.minutesOfDay, 0);
      expect(low.warningDays, AlertSettings.minWarningDays);
    });

    test('copyWith changes only what is named', () {
      const AlertSettings settings = AlertSettings();
      final AlertSettings changed = settings.copyWith(warningDays: 5);
      expect(changed.warningDays, 5);
      expect(changed.enabled, settings.enabled);
      expect(changed.minutesOfDay, settings.minutesOfDay);
      expect(changed.lowStock, settings.lowStock);
      expect(changed == settings, isFalse);
      expect(changed.hashCode == settings.hashCode, isFalse);
    });

    test('time labels', () {
      expect(formatMinutesOfDay(0), '12:00 am');
      expect(formatMinutesOfDay(8 * 60), '8:00 am');
      expect(formatMinutesOfDay(12 * 60 + 30), '12:30 pm');
      expect(formatMinutesOfDay(13 * 60 + 5), '1:05 pm');
      expect(formatMinutesOfDay(23 * 60 + 59), '11:59 pm');
      expect(const AlertSettings(minutesOfDay: 450).timeLabel, '7:30 am');
    });
  });
}
