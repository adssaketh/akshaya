import 'dart:ui' show FontVariation;

import 'package:flutter/material.dart';

/// Font family names. They must match the `fonts:` entries in pubspec.yaml.
abstract final class AkshayaFonts {
  /// Fraunces (headings, numbers, item names).
  static const String display = 'Fraunces';

  /// Nunito Sans (body, labels).
  static const String body = 'NunitoSans';
}

/// Text styles for Akshaya.
///
/// Colours are intentionally absent: [AkshayaTheme] applies them from the
/// colour tokens. Both fonts are variable fonts, so each style sets the weight
/// axis explicitly through `fontVariations` as well as `fontWeight`.
abstract final class AkshayaText {
  static FontWeight _weight(double w) {
    final int raw = (w / 100).round() - 1;
    final int index = raw < 0 ? 0 : (raw > 8 ? 8 : raw);
    return FontWeight.values[index];
  }

  static TextStyle _style(
    String family,
    double size,
    double weight, {
    required double height,
  }) {
    return TextStyle(
      fontFamily: family,
      fontSize: size,
      fontWeight: _weight(weight),
      fontVariations: <FontVariation>[FontVariation('wght', weight)],
      height: height,
    );
  }

  /// Text theme with display font for headings and body font for the rest.
  static TextTheme textTheme() {
    return TextTheme(
      // Big counts on summary tiles.
      headlineMedium: _style(AkshayaFonts.display, 26, 600, height: 1.15),
      // Screen titles.
      headlineSmall: _style(AkshayaFonts.display, 22, 600, height: 1.2),
      // App bar title, wordmark.
      titleLarge: _style(AkshayaFonts.display, 20, 600, height: 1.2),
      // Section headers.
      titleMedium: _style(AkshayaFonts.display, 16, 600, height: 1.25),
      // Item names.
      titleSmall: _style(AkshayaFonts.display, 14, 600, height: 1.3),
      bodyLarge: _style(AkshayaFonts.body, 16, 400, height: 1.45),
      bodyMedium: _style(AkshayaFonts.body, 14, 400, height: 1.45),
      bodySmall: _style(AkshayaFonts.body, 12, 400, height: 1.4),
      // Buttons.
      labelLarge: _style(AkshayaFonts.body, 14, 600, height: 1.3),
      labelMedium: _style(AkshayaFonts.body, 12, 600, height: 1.3),
      // Chips, nav labels.
      labelSmall: _style(AkshayaFonts.body, 11, 600, height: 1.3),
    );
  }
}
