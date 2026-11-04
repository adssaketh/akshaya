import 'package:flutter/material.dart';

import '../tokens/akshaya_colors.dart';
import '../tokens/layout_tokens.dart';
import '../typography/akshaya_text.dart';

/// Builds the Material 3 [ThemeData] for Akshaya from the colour, spacing,
/// radius and text tokens. Requires Flutter 3.27 or newer.
abstract final class AkshayaTheme {
  static ThemeData light() => _build(AkshayaColors.light, Brightness.light);

  static ThemeData dark() => _build(AkshayaColors.dark, Brightness.dark);

  static ThemeData _build(AkshayaColors c, Brightness brightness) {
    final ColorScheme scheme = ColorScheme(
      brightness: brightness,
      primary: c.primary,
      onPrimary: c.onPrimary,
      primaryContainer: c.surfaceAlt,
      onPrimaryContainer: c.textPrimary,
      secondary: c.accent,
      onSecondary: c.onAccent,
      secondaryContainer: c.surfaceAlt,
      onSecondaryContainer: c.textPrimary,
      tertiary: c.accent,
      onTertiary: c.onAccent,
      error: c.expired.foreground,
      onError: c.background,
      errorContainer: c.expired.background,
      onErrorContainer: c.expired.foreground,
      surface: c.background,
      onSurface: c.textPrimary,
      onSurfaceVariant: c.textSecondary,
      surfaceContainerLowest: c.surface,
      surfaceContainerLow: c.surface,
      surfaceContainer: c.surface,
      surfaceContainerHigh: c.surfaceAlt,
      surfaceContainerHighest: c.surfaceAlt,
      outline: c.outline,
      outlineVariant: c.outline,
      inverseSurface: c.textPrimary,
      onInverseSurface: c.background,
      inversePrimary: c.accent,
      surfaceTint: Colors.transparent,
    );

    final TextTheme text = AkshayaText.textTheme().apply(
      bodyColor: c.textPrimary,
      displayColor: c.textPrimary,
    );

    const Size minTarget = Size(AppSizes.touchTarget, AppSizes.touchTarget);
    const RoundedRectangleBorder controlShape = RoundedRectangleBorder(
      borderRadius: AppRadius.controlBorder,
    );

    OutlineInputBorder inputBorder(Color color, {double width = 1}) {
      return OutlineInputBorder(
        borderRadius: AppRadius.controlBorder,
        borderSide: BorderSide(color: color, width: width),
      );
    }

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: AkshayaFonts.body,
      textTheme: text,
      scaffoldBackgroundColor: c.background,
      extensions: <ThemeExtension<dynamic>>[c],
      dividerTheme: DividerThemeData(
        color: c.outline,
        thickness: AppSizes.borderWidth,
        space: AppSizes.borderWidth,
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.cardBorder),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: c.background,
        foregroundColor: c.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.surface,
        indicatorColor: c.surfaceAlt,
        elevation: 0,
        height: AppSizes.navBarHeight,
        iconTheme: WidgetStateProperty.resolveWith<IconThemeData>(
          (Set<WidgetState> states) => IconThemeData(
            size: AppSizes.iconMd,
            color: states.contains(WidgetState.selected)
                ? c.primary
                : c.textSecondary,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>(
          (Set<WidgetState> states) => text.labelSmall!.copyWith(
            color: states.contains(WidgetState.selected)
                ? c.textPrimary
                : c.textSecondary,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: c.primary,
        foregroundColor: c.onPrimary,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.fab)),
        ),
        extendedTextStyle: text.labelLarge,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.primary,
          foregroundColor: c.onPrimary,
          minimumSize: minTarget,
          shape: controlShape,
          textStyle: text.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.primary,
          side: BorderSide(color: c.outline),
          minimumSize: minTarget,
          shape: controlShape,
          textStyle: text.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.primary,
          minimumSize: minTarget,
          textStyle: text.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        hintStyle: text.bodyMedium!.copyWith(color: c.textSecondary),
        border: inputBorder(c.outline),
        enabledBorder: inputBorder(c.outline),
        focusedBorder: inputBorder(c.primary, width: 2),
        errorBorder: inputBorder(c.expired.foreground),
        focusedErrorBorder: inputBorder(c.expired.foreground, width: 2),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.surface,
        selectedColor: c.surfaceAlt,
        side: BorderSide(color: c.outline),
        shape: const StadiumBorder(),
        labelStyle: text.labelMedium!.copyWith(color: c.textPrimary),
        checkmarkColor: c.primary,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.textPrimary,
        contentTextStyle: text.bodyMedium!.copyWith(color: c.background),
        actionTextColor: c.accent,
        shape: controlShape,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.sheet)),
        ),
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        showDragHandle: true,
        dragHandleColor: c.outline,
        clipBehavior: Clip.antiAlias,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheetTop),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.primary,
        linearTrackColor: c.outline,
      ),
    );
  }
}
