import 'package:flutter/widgets.dart';

/// Spacing scale. Use these for every padding, margin and gap.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

/// Corner radii (Haldi: soft, generous).
abstract final class AppRadius {
  static const double control = 16;
  static const double card = 20;
  static const double sheet = 28;
  static const double fab = 28;

  static const BorderRadius controlBorder =
      BorderRadius.all(Radius.circular(control));
  static const BorderRadius cardBorder =
      BorderRadius.all(Radius.circular(card));
  static const BorderRadius sheetTop =
      BorderRadius.vertical(top: Radius.circular(sheet));
}

/// Fixed component sizes.
abstract final class AppSizes {
  /// Minimum interactive target (one-handed use, large touch targets).
  static const double touchTarget = 48;

  static const double iconXs = 12;
  static const double iconSm = 18;
  static const double iconMd = 20;
  static const double iconLg = 24;
  static const double iconXl = 32;

  /// Round icon holder inside item cards.
  static const double avatar = 40;

  static const double logo = 24;
  static const double kolamHeader = 48;
  static const double kolamEmpty = 96;

  static const double navBarHeight = 72;
  static const double fab = 56;

  /// Status chips ellipsise beyond this so large font scales never overflow.
  static const double chipMaxWidth = 144;

  static const double borderWidth = 1;
}
