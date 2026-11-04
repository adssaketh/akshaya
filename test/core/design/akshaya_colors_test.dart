import 'package:akshaya/core/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double contrast(Color a, Color b) {
  final double la = a.computeLuminance();
  final double lb = b.computeLuminance();
  final double hi = la > lb ? la : lb;
  final double lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  final Map<String, AkshayaColors> palettes = <String, AkshayaColors>{
    'light': AkshayaColors.light,
    'dark': AkshayaColors.dark,
  };

  palettes.forEach((String mode, AkshayaColors c) {
    group('$mode palette contrast (WCAG AA)', () {
      test('body text is readable on page, card and tinted surfaces', () {
        expect(contrast(c.textPrimary, c.background), greaterThanOrEqualTo(4.5));
        expect(contrast(c.textPrimary, c.surface), greaterThanOrEqualTo(4.5));
        expect(contrast(c.textPrimary, c.surfaceAlt), greaterThanOrEqualTo(4.5));
        expect(contrast(c.textSecondary, c.background), greaterThanOrEqualTo(4.5));
        expect(contrast(c.textSecondary, c.surface), greaterThanOrEqualTo(4.5));
        expect(contrast(c.textSecondary, c.surfaceAlt), greaterThanOrEqualTo(4.5));
      });

      test('primary and accent pairs are readable', () {
        expect(contrast(c.onPrimary, c.primary), greaterThanOrEqualTo(4.5));
        expect(contrast(c.onAccent, c.accent), greaterThanOrEqualTo(4.5));
        expect(contrast(c.primary, c.background), greaterThanOrEqualTo(4.5));
        expect(contrast(c.primary, c.surface), greaterThanOrEqualTo(4.5));
      });

      test('primary icon on the selected nav indicator meets 3:1 (icons)', () {
        expect(contrast(c.primary, c.surfaceAlt), greaterThanOrEqualTo(3.0));
      });

      test('every status foreground is readable on its own tint', () {
        for (final StatusKind kind in StatusKind.values) {
          final StatusColors s = c.forStatus(kind);
          expect(
            contrast(s.foreground, s.background),
            greaterThanOrEqualTo(4.5),
            reason: '${kind.name} foreground on background',
          );
        }
      });

      test('secondary text is readable on every status tint', () {
        for (final StatusKind kind in StatusKind.values) {
          final StatusColors s = c.forStatus(kind);
          expect(
            contrast(c.textSecondary, s.background),
            greaterThanOrEqualTo(4.5),
            reason: '${kind.name} tint',
          );
        }
      });

      test('status foregrounds are all different colours', () {
        final Set<Color> foregrounds = <Color>{
          for (final StatusKind kind in StatusKind.values)
            c.forStatus(kind).foreground,
        };
        expect(foregrounds.length, StatusKind.values.length);
      });
    });
  });

  group('AkshayaColors', () {
    test('copyWith replaces only the given fields', () {
      final AkshayaColors changed = AkshayaColors.light.copyWith(
        primary: AkshayaColors.dark.primary,
      );
      expect(changed.primary, AkshayaColors.dark.primary);
      expect(changed.background, AkshayaColors.light.background);
      expect(changed.expired.foreground, AkshayaColors.light.expired.foreground);
    });

    test('lerp returns the endpoints at t = 0 and t = 1', () {
      final AkshayaColors a = AkshayaColors.light.lerp(AkshayaColors.dark, 0);
      final AkshayaColors b = AkshayaColors.light.lerp(AkshayaColors.dark, 1);
      expect(a.background, AkshayaColors.light.background);
      expect(b.background, AkshayaColors.dark.background);
      expect(b.fresh.foreground, AkshayaColors.dark.fresh.foreground);
    });

    test('lerp with a different extension type returns this', () {
      expect(
        AkshayaColors.light.lerp(null, 0.5).background,
        AkshayaColors.light.background,
      );
    });

    test('forStatus covers every StatusKind', () {
      for (final StatusKind kind in StatusKind.values) {
        expect(AkshayaColors.light.forStatus(kind), isNotNull);
      }
    });
  });

  group('StatusKind', () {
    test('has English labels and unique icons', () {
      expect(StatusKind.fresh.label, 'Fresh');
      expect(StatusKind.expiring.label, 'Expiring soon');
      expect(StatusKind.expired.label, 'Expired');
      expect(StatusKind.lowStock.label, 'Low stock');
      expect(StatusKind.outOfStock.label, 'Out of stock');
      final Set<IconData> icons = <IconData>{
        for (final StatusKind kind in StatusKind.values) kind.icon,
      };
      expect(icons.length, StatusKind.values.length);
    });
  });
}
