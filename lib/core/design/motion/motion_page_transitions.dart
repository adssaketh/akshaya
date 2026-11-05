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

/// Tab pane that eases in each time it becomes the visible tab. The pane stays
/// built while hidden, so its scroll position and state survive.
///
/// The widget tree below this pane is the same on every frame (fade and slide
/// wrappers are always present, just at rest when done). Swapping the wrapper
/// in and out would make Flutter rebuild the whole screen from scratch at the
/// start and end of every switch: a blank flash, counters restarting from 0
/// and list rows re-animating. Do not "optimise" the wrappers away.
class TabPane extends StatefulWidget {
  const TabPane({super.key, required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  State<TabPane> createState() => _TabPaneState();
}

class _TabPaneState extends State<TabPane> with SingleTickerProviderStateMixin {
  /// A tab never starts fully transparent: that reads as a blank flash.
  static const double _startOpacity = 0.4;

  /// Fraction of the pane's height it rises while easing in (about 10 dp).
  static const double _rise = 0.012;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.base,
    value: 1,
  );
  late final Animation<double> _t =
      CurvedAnimation(parent: _controller, curve: AppMotion.enter);
  late final Animation<double> _opacity =
      Tween<double>(begin: _startOpacity, end: 1).animate(_t);
  late final Animation<Offset> _slide =
      Tween<Offset>(begin: const Offset(0, _rise), end: Offset.zero)
          .animate(_t);

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
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}
