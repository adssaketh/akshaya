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

  /// Fully rounded (search box, buttons, chips, segmented switches).
  static const double pill = 999;

  /// Floating bottom navigation bar (a rounded pill, as in Ping).
  static const double navBar = 38;

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

  /// The basket logo has fine detail, so it needs more room than an icon.
  static const double logo = 36;
  static const double sarukuluHeader = 48;
  static const double sarukuluEmpty = 96;

  /// Barcode scanner viewfinder.
  static const double scanFrameWidth = 280;
  static const double scanFrameHeight = 160;
  static const double scanFrameBorder = 3;
  static const double qrScanFrame = 240;
  static const double qrCode = 180;

  static const double navBarHeight = 76;

  /// Floating navigation bar: indicator pill behind the selected icon, icon
  /// size, inner padding and the widest the bar grows on tablets.
  static const double navIndicatorWidth = 60;
  static const double navIndicatorHeight = 36;
  static const double navIcon = 26;
  static const double navPadding = 8;
  static const double navMaxWidth = 576;
  static const double navShadowBlur = 16;
  static const double navShadowOffset = 6;
  static const double navShadowAlpha = 0.22;
  static const double navShadowAlphaDark = 0.55;
  static const double navGlassEdgeWidth = 1;
  static const double navGlassEdgeAlpha = 0.5;
  static const double navGlassEdgeAlphaDark = 0.2;
  static const double fab = 56;

  /// Status chips ellipsise beyond this so large font scales never overflow.
  static const double chipMaxWidth = 144;

  static const double borderWidth = 1;
}
