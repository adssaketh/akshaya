import 'package:flutter/material.dart';

import 'app_motion.dart';

/// A whole number that counts up to its value, and counts again whenever the
/// value changes.
class AnimatedCount extends StatelessWidget {
  const AnimatedCount({super.key, required this.value, this.style});

  final int value;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    if (!AppMotion.of(context)) {
      return Text('$value', style: style);
    }
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: value),
      duration: AppMotion.slow,
      curve: AppMotion.enter,
      builder: (BuildContext context, int shown, Widget? _) =>
          Text('$shown', style: style),
    );
  }
}
