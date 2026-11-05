import 'package:akshaya/core/util/money.dart';
import 'package:akshaya/features/pantry/domain/unit.dart';
import 'package:akshaya/features/settings/domain/app_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() => currentCurrencySymbol = kCurrencySymbol);

  group('AppSettings.fromMap', () {
    test('defaults when nothing is stored', () {
      final AppSettings s = AppSettings.fromMap(const <String, String>{});
      expect(s.theme, AppThemeChoice.system);
      expect(s.currencySymbol, '₹');
      expect(s.defaultUnit, Unit.pcs);
      expect(s.appLock, isFalse);
    });

    test('reads stored values', () {
      final AppSettings s = AppSettings.fromMap(const <String, String>{
        AppSettingKeys.theme: 'dark',
        AppSettingKeys.currency: '€',
        AppSettingKeys.defaultUnit: 'kg',
        AppSettingKeys.appLock: 'true',
      });
      expect(s.theme, AppThemeChoice.dark);
      expect(s.currencySymbol, '€');
      expect(s.defaultUnit, Unit.kg);
      expect(s.appLock, isTrue);
    });

    test('ignores values it does not know', () {
      final AppSettings s = AppSettings.fromMap(const <String, String>{
        AppSettingKeys.theme: 'neon',
        AppSettingKeys.currency: 'zz',
        AppSettingKeys.defaultUnit: 'furlong',
      });
      expect(s.theme, AppThemeChoice.system);
      expect(s.currencySymbol, '₹');
      expect(s.defaultUnit, Unit.pcs);
    });
  });

  group('currency', () {
    test('formatMoney follows the chosen symbol', () {
      expect(formatMoney(120), startsWith('₹'));
      currentCurrencySymbol = r'$';
      expect(formatMoney(120), startsWith(r'$'));
    });

    test('parseMoney accepts either symbol', () {
      expect(parseMoney('₹ 45'), 45);
      currentCurrencySymbol = r'$';
      expect(parseMoney(r'$45'), 45);
      expect(parseMoney('₹45'), 45);
    });
  });
}
