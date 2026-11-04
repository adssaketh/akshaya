import 'package:akshaya/core/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AkshayaTheme', () {
    test('light theme is Material 3 and carries the light tokens', () {
      final ThemeData theme = AkshayaTheme.light();
      expect(theme.useMaterial3, isTrue);
      expect(theme.brightness, Brightness.light);
      expect(theme.extension<AkshayaColors>(), isNotNull);
      expect(theme.scaffoldBackgroundColor, AkshayaColors.light.background);
      expect(theme.colorScheme.primary, AkshayaColors.light.primary);
      expect(theme.colorScheme.onSurface, AkshayaColors.light.textPrimary);
    });

    test('dark theme is Material 3 and carries the dark tokens', () {
      final ThemeData theme = AkshayaTheme.dark();
      expect(theme.brightness, Brightness.dark);
      expect(theme.scaffoldBackgroundColor, AkshayaColors.dark.background);
      expect(theme.colorScheme.primary, AkshayaColors.dark.primary);
      expect(theme.extension<AkshayaColors>()!.surface,
          AkshayaColors.dark.surface);
    });

    test('headings use Fraunces and body text uses Nunito Sans', () {
      final TextTheme text = AkshayaTheme.light().textTheme;
      expect(text.headlineSmall!.fontFamily, AkshayaFonts.display);
      expect(text.titleSmall!.fontFamily, AkshayaFonts.display);
      expect(text.bodyMedium!.fontFamily, AkshayaFonts.body);
      expect(text.labelSmall!.fontFamily, AkshayaFonts.body);
      expect(AkshayaFonts.display, 'Fraunces');
      expect(AkshayaFonts.body, 'NunitoSans');
    });

    test('text styles set the variable weight axis', () {
      final TextStyle style = AkshayaTheme.light().textTheme.titleSmall!;
      expect(style.fontVariations, isNotNull);
      expect(style.fontVariations!.single.axis, 'wght');
      expect(style.fontVariations!.single.value, 600);
      expect(style.fontWeight, FontWeight.w600);
    });

    test('text colour comes from the tokens', () {
      expect(
        AkshayaTheme.dark().textTheme.bodyMedium!.color,
        AkshayaColors.dark.textPrimary,
      );
    });

    test('buttons meet the 48 dp touch target', () {
      final ThemeData theme = AkshayaTheme.light();
      final Size? filled = theme.filledButtonTheme.style!.minimumSize!
          .resolve(<WidgetState>{});
      final Size? text =
          theme.textButtonTheme.style!.minimumSize!.resolve(<WidgetState>{});
      expect(filled!.height, AppSizes.touchTarget);
      expect(text!.height, AppSizes.touchTarget);
    });

    test('navigation bar uses the tinted indicator', () {
      expect(
        AkshayaTheme.light().navigationBarTheme.indicatorColor,
        AkshayaColors.light.surfaceAlt,
      );
    });
  });

  group('context extension', () {
    testWidgets('akColors reads the extension from the theme', (tester) async {
      late AkshayaColors read;
      await tester.pumpWidget(
        MaterialApp(
          theme: AkshayaTheme.dark(),
          home: Builder(
            builder: (BuildContext context) {
              read = context.akColors;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(read.background, AkshayaColors.dark.background);
    });

    testWidgets('akColors falls back for a plain MaterialApp', (tester) async {
      late AkshayaColors read;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (BuildContext context) {
              read = context.akColors;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(read.background, AkshayaColors.light.background);
    });
  });
}
