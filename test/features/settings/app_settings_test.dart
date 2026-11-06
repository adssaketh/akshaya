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
      expect(s.animations, isTrue);
    });

    test('animations can be switched off', () {
      expect(
        AppSettings.fromMap(const <String, String>{
          AppSettingKeys.animations: 'false',
        }).animations,
        isFalse,
      );
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

  group('bar style', () {
    test('defaults to a solid bar with strong glass', () {
      final AppSettings s = AppSettings.fromMap(const <String, String>{});
      expect(s.barStyle, BarStyle.solid);
      expect(s.glassAlpha, kGlassAlphaDefault);
      expect(s.glassBlur, GlassBlur.strong);
      expect(s.glassEdge, isTrue);
    });

    test('reads stored values and clamps the opacity', () {
      final AppSettings s = AppSettings.fromMap(const <String, String>{
        AppSettingKeys.barStyle: 'glass',
        AppSettingKeys.glassAlpha: '1',
        AppSettingKeys.glassBlur: 'soft',
        AppSettingKeys.glassEdge: 'false',
      });
      expect(s.barStyle, BarStyle.glass);
      expect(s.glassAlpha, kGlassAlphaMin);
      expect(s.glassBlur, GlassBlur.soft);
      expect(s.glassEdge, isFalse);
      expect(
        AppSettings.fromMap(const <String, String>{
          AppSettingKeys.glassAlpha: '500',
        }).glassAlpha,
        kGlassAlphaMax,
      );
    });

    test('bad values fall back and equality includes the new fields', () {
      final AppSettings bad = AppSettings.fromMap(const <String, String>{
        AppSettingKeys.barStyle: 'jelly',
        AppSettingKeys.glassAlpha: 'x',
        AppSettingKeys.glassBlur: 'huge',
      });
      expect(bad, const AppSettings());
      expect(
        const AppSettings(barStyle: BarStyle.glass),
        isNot(const AppSettings()),
      );
      expect(GlassBlur.strong.sigma, 14);
    });
  });

  group('scroll edge effect', () {
    test('defaults to fade, medium blur and medium height', () {
      final AppSettings s = AppSettings.fromMap(const <String, String>{});
      expect(s.edgeEffect, EdgeEffect.fade);
      expect(s.edgeBlur, EdgeBlur.medium);
      expect(s.edgeFade, EdgeFade.medium);
    });

    test('reads stored values, ignores bad ones, equality includes them', () {
      final AppSettings s = AppSettings.fromMap(const <String, String>{
        AppSettingKeys.edgeEffect: 'blur',
        AppSettingKeys.edgeBlur: 'strong',
        AppSettingKeys.edgeFade: 'tall',
      });
      expect(s.edgeEffect, EdgeEffect.blur);
      expect(s.edgeBlur, EdgeBlur.strong);
      expect(s.edgeFade, EdgeFade.tall);
      expect(
        AppSettings.fromMap(const <String, String>{
          AppSettingKeys.edgeEffect: 'sparkle',
        }).edgeEffect,
        EdgeEffect.fade,
      );
      expect(s, isNot(const AppSettings()));
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
