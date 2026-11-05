import 'package:animations/animations.dart';
import 'package:flutter/material.dart';

import 'app_motion.dart';

/// Screen-to-screen transition: Material "shared axis" (the new screen slides
/// in sideways while fading, the old one eases away). Falls back to an instant
/// switch when motion is off.
class AkshayaPageTransitionsBuilder extends PageTransitionsBuilder {
  const AkshayaPageTransitionsBuilder();

  static const SharedAxisPageTransitionsBuilder _shared =
      SharedAxisPageTransitionsBuilder(
    transitionType: SharedAxisTransitionType.horizontal,
  );

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (!AppMotion.of(context)) {
      return child;
    }
    return _shared.buildTransitions<T>(
      route,
      context,
      animation,
      secondaryAnimation,
      child,
    );
  }
}

/// Tab pane that fades and rises a little each time it becomes the visible
/// tab. The pane stays built while hidden, so its scroll position and state
/// survive.
class TabPane extends StatefulWidget {
  const TabPane({super.key, required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  State<TabPane> createState() => _TabPaneState();
}

class _TabPaneState extends State<TabPane> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.base,
    value: 1,
  );
  late final Animation<double> _t =
      CurvedAnimation(parent: _controller, curve: AppMotion.enter);

  @override
  void didUpdateWidget(TabPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active && AppMotion.of(context)) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      child: widget.child,
      builder: (BuildContext context, Widget? child) {
        final double t = _t.value;
        if (t >= 1) {
          return child!;
        }
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 14),
            child: child,
          ),
        );
      },
    );
  }
}
