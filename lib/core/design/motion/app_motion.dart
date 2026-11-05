import 'package:flutter/material.dart';

/// Motion tokens. Every animation in the app takes its timing and curve from
/// here, and checks [AppMotion.of] so it stays still when the phone's
/// "Remove animations" is on or the person turned animations off in Settings.
abstract final class AppMotion {
  /// The Settings switch. Set from the app root; defaults to on.
  static bool userEnabled = true;

  /// Quick feedback: presses, chip swaps.
  static const Duration fast = Duration(milliseconds: 160);

  /// Most transitions.
  static const Duration base = Duration(milliseconds: 280);

  /// Entrances and page changes.
  static const Duration slow = Duration(milliseconds: 420);

  /// Gap between neighbours in a staggered entrance.
  static const Duration stagger = Duration(milliseconds: 45);

  /// Rows beyond this appear together, so long lists never feel slow.
  static const int maxStaggered = 10;

  /// Things arriving: quick start, soft landing.
  static const Curve enter = Curves.easeOutCubic;

  /// A small overshoot for pops (selected icon, check mark).
  static const Curve pop = Curves.easeOutBack;

  /// True when this widget may animate.
  static bool of(BuildContext context) {
    return userEnabled && !MediaQuery.disableAnimationsOf(context);
  }
}
