import 'package:flutter/material.dart';

import 'app_motion.dart';

/// Scales its child in with a small overshoot, each time it is first built
/// (a selected tab icon, a check mark).
class PopIn extends StatelessWidget {
  const PopIn({super.key, required this.child, this.from = 0.6});

  final Widget child;
  final double from;

  @override
  Widget build(BuildContext context) {
    if (!AppMotion.of(context)) {
      return child;
    }
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: from, end: 1),
      duration: AppMotion.base,
      curve: AppMotion.pop,
      child: child,
      builder: (BuildContext context, double scale, Widget? child) =>
          Transform.scale(scale: scale, child: child),
    );
  }
}
