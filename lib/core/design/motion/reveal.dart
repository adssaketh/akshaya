import 'package:flutter/material.dart';

import 'app_motion.dart';

/// Fades and slides its child up the first time it appears. Give list rows
/// their [index] to get a staggered entrance (capped at
/// [AppMotion.maxStaggered] so long lists do not drag).
///
/// Plays once per widget: scrolling back or a data refresh does not replay it.
/// Rows at [AppMotion.maxStaggered] or later (and any row built while motion is
/// off) appear at once, so scrolling a long list never trickles in.
///
/// The widget tree below a Reveal never changes shape once it is built (the
/// wrappers stay at rest when done). Swapping them out would make Flutter
/// rebuild the child from scratch, which shows up as a flicker.
class Reveal extends StatefulWidget {
  const Reveal({
    super.key,
    required this.child,
    this.index = 0,
    this.distance = 18,
    this.scaleFrom = 1,
  });

  final Widget child;

  /// Position in the list; later rows start a little later.
  final int index;

  /// How far (logical pixels) the child rises while appearing.
  final double distance;

  /// Starting scale (1 = no scaling).
  final double scaleFrom;

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  late final Duration _delay =
      AppMotion.stagger * widget.index.clamp(0, AppMotion.maxStaggered);
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _delay + AppMotion.slow,
  );
  late final Animation<double> _t = CurvedAnimation(
    parent: _controller,
    curve: Interval(
      _delay.inMilliseconds / _controller.duration!.inMilliseconds,
      1,
      curve: AppMotion.enter,
    ),
  );
  bool _started = false;

  /// Decided once, on the first build, so the tree shape stays constant.
  bool _wrapped = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) {
      return;
    }
    _started = true;
    if (AppMotion.of(context) && widget.index < AppMotion.maxStaggered) {
      _wrapped = true;
      _controller.forward();
    } else {
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_wrapped) {
      return widget.child;
    }
    return AnimatedBuilder(
      animation: _t,
      child: widget.child,
      builder: (BuildContext context, Widget? child) {
        final double t = _t.value;
        return Opacity(
          opacity: t.clamp(0, 1),
          child: Transform.translate(
            offset: Offset(0, (1 - t) * widget.distance),
            child: widget.scaleFrom == 1
                ? child
                : Transform.scale(
                    scale: widget.scaleFrom + (1 - widget.scaleFrom) * t,
                    child: child,
                  ),
          ),
        );
      },
    );
  }
}
