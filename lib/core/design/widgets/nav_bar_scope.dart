import 'package:flutter/widgets.dart';

/// How much of the screen's bottom the floating navigation bar covers
/// (bar, its margins and the system inset), measured by the shell once it is
/// laid out. Floating buttons on a tab read it to sit above the bar.
///
/// It is measured, not derived from MediaQuery, because the padding the
/// Scaffold reports under `extendBody` differs between Flutter versions.
class NavBarScope extends InheritedNotifier<ValueNotifier<double>> {
  const NavBarScope({
    super.key,
    required ValueNotifier<double> covered,
    required super.child,
  }) : super(notifier: covered);

  /// The covered height in logical pixels, or null outside the tab shell (or
  /// before the first measurement).
  static double? maybeOf(BuildContext context) {
    final NavBarScope? scope =
        context.dependOnInheritedWidgetOfExactType<NavBarScope>();
    final double? value = scope?.notifier?.value;
    return value == null || value <= 0 ? null : value;
  }
}
