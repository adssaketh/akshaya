import 'package:flutter/material.dart';

import 'status_kind.dart';

/// Foreground (text/icon) and background (tint) colours for one [StatusKind].
@immutable
class StatusColors {
  const StatusColors({required this.foreground, required this.background});

  final Color foreground;
  final Color background;

  static StatusColors lerp(StatusColors a, StatusColors b, double t) {
    return StatusColors(
      foreground: Color.lerp(a.foreground, b.foreground, t)!,
      background: Color.lerp(a.background, b.background, t)!,
    );
  }
}

Color _mix(Color a, Color b, double t) => Color.lerp(a, b, t)!;

/// Haldi colour tokens (warm terracotta, turmeric and cream).
///
/// This file is the ONLY place raw colour values may appear. Everything else
/// reads colours through `context.akColors` or the Material [ColorScheme]
/// built from these tokens. A test enforces this.
@immutable
class AkshayaColors extends ThemeExtension<AkshayaColors> {
  const AkshayaColors({
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.primary,
    required this.onPrimary,
    required this.accent,
    required this.onAccent,
    required this.textPrimary,
    required this.textSecondary,
    required this.outline,
    required this.fresh,
    required this.expiring,
    required this.expired,
    required this.lowStock,
    required this.outOfStock,
  });

  /// Page background (cream / deep brown).
  final Color background;

  /// Cards, inputs, navigation bar.
  final Color surface;

  /// Quiet tinted fill: icon circles, selected nav indicator, selected chips.
  final Color surfaceAlt;

  /// Brand colour (terracotta): buttons, links, active icons.
  final Color primary;
  final Color onPrimary;

  /// Turmeric accent: decorative motifs and highlights, never body text.
  final Color accent;
  final Color onAccent;

  final Color textPrimary;
  final Color textSecondary;

  /// Hairline borders and dividers.
  final Color outline;

  final StatusColors fresh;
  final StatusColors expiring;
  final StatusColors expired;
  final StatusColors lowStock;
  final StatusColors outOfStock;

  /// QR codes must be dark on light in every theme to scan.
  static const Color qrForeground = Color(0xFF000000);
  static const Color qrBackground = Color(0xFFFFFFFF);

  static const AkshayaColors light = AkshayaColors(
    background: Color(0xFFFBF5EC),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFF3E7D6),
    primary: Color(0xFFB5502D),
    onPrimary: Color(0xFFFFFFFF),
    accent: Color(0xFFE3A21A),
    onAccent: Color(0xFF2B1D14),
    textPrimary: Color(0xFF2B1D14),
    textSecondary: Color(0xFF6E5A4B),
    outline: Color(0xFFE6D7C3),
    fresh: StatusColors(
      foreground: Color(0xFF3F6F2E),
      background: Color(0xFFE4EFD9),
    ),
    expiring: StatusColors(
      foreground: Color(0xFF8F5400),
      background: Color(0xFFFBEBCB),
    ),
    expired: StatusColors(
      foreground: Color(0xFFB3261E),
      background: Color(0xFFF9DAD6),
    ),
    lowStock: StatusColors(
      foreground: Color(0xFF245F85),
      background: Color(0xFFD9EAF4),
    ),
    outOfStock: StatusColors(
      foreground: Color(0xFF5F5148),
      background: Color(0xFFEBE3D8),
    ),
  );

  static const AkshayaColors dark = AkshayaColors(
    background: Color(0xFF1A130E),
    surface: Color(0xFF261C15),
    surfaceAlt: Color(0xFF33261C),
    primary: Color(0xFFE88A66),
    onPrimary: Color(0xFF2B1208),
    accent: Color(0xFFF0B94A),
    onAccent: Color(0xFF1A130E),
    textPrimary: Color(0xFFF5E9DB),
    textSecondary: Color(0xFFBFA995),
    outline: Color(0xFF3C2E23),
    fresh: StatusColors(
      foreground: Color(0xFF9CCB86),
      background: Color(0xFF26361F),
    ),
    expiring: StatusColors(
      foreground: Color(0xFFF0B24A),
      background: Color(0xFF3B2A0E),
    ),
    expired: StatusColors(
      foreground: Color(0xFFF2877F),
      background: Color(0xFF402120),
    ),
    lowStock: StatusColors(
      foreground: Color(0xFF8DC4E6),
      background: Color(0xFF1B3445),
    ),
    outOfStock: StatusColors(
      foreground: Color(0xFFB8A898),
      background: Color(0xFF3A2F26),
    ),
  );

  /// Brand colours taken from a Material [scheme] (such as one made from the
  /// phone's wallpaper); the status colours keep their fixed meaning from
  /// [base] so "expired" is always red and "fresh" always green.
  static AkshayaColors fromScheme(ColorScheme scheme, AkshayaColors base) {
    return base.copyWith(
      background: scheme.surface,
      surface: scheme.surfaceContainerLow,
      surfaceAlt: scheme.secondaryContainer,
      primary: scheme.primary,
      onPrimary: scheme.onPrimary,
      accent: scheme.tertiary,
      onAccent: scheme.onTertiary,
      textPrimary: scheme.onSurface,
      textSecondary: scheme.onSurfaceVariant,
      outline: scheme.outlineVariant,
    );
  }

  /// Colours for a status kind.
  StatusColors forStatus(StatusKind kind) {
    return switch (kind) {
      StatusKind.fresh => fresh,
      StatusKind.expiring => expiring,
      StatusKind.expired => expired,
      StatusKind.lowStock => lowStock,
      StatusKind.outOfStock => outOfStock,
    };
  }

  @override
  AkshayaColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceAlt,
    Color? primary,
    Color? onPrimary,
    Color? accent,
    Color? onAccent,
    Color? textPrimary,
    Color? textSecondary,
    Color? outline,
    StatusColors? fresh,
    StatusColors? expiring,
    StatusColors? expired,
    StatusColors? lowStock,
    StatusColors? outOfStock,
  }) {
    return AkshayaColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      outline: outline ?? this.outline,
      fresh: fresh ?? this.fresh,
      expiring: expiring ?? this.expiring,
      expired: expired ?? this.expired,
      lowStock: lowStock ?? this.lowStock,
      outOfStock: outOfStock ?? this.outOfStock,
    );
  }

  @override
  AkshayaColors lerp(ThemeExtension<AkshayaColors>? other, double t) {
    if (other is! AkshayaColors) return this;
    return AkshayaColors(
      background: _mix(background, other.background, t),
      surface: _mix(surface, other.surface, t),
      surfaceAlt: _mix(surfaceAlt, other.surfaceAlt, t),
      primary: _mix(primary, other.primary, t),
      onPrimary: _mix(onPrimary, other.onPrimary, t),
      accent: _mix(accent, other.accent, t),
      onAccent: _mix(onAccent, other.onAccent, t),
      textPrimary: _mix(textPrimary, other.textPrimary, t),
      textSecondary: _mix(textSecondary, other.textSecondary, t),
      outline: _mix(outline, other.outline, t),
      fresh: StatusColors.lerp(fresh, other.fresh, t),
      expiring: StatusColors.lerp(expiring, other.expiring, t),
      expired: StatusColors.lerp(expired, other.expired, t),
      lowStock: StatusColors.lerp(lowStock, other.lowStock, t),
      outOfStock: StatusColors.lerp(outOfStock, other.outOfStock, t),
    );
  }
}
