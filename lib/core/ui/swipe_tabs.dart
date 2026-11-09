import 'dart:async';

import 'package:akshaya/core/design/design.dart';
import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/material.dart';

/// A row of pages that can be swiped, with [index] always saying which one is
/// showing.
///
/// - Dragging follows the finger and settles with a spring.
/// - Changing [index] (the nav bar, a link from another screen) slides to the
///   page. A page two or more away is reached by jumping next to it first, so
///   the pages in between are never drawn and the slide stays one smooth move.
/// - Every page keeps its state (scroll position, a half-typed field) while
///   it is off screen, as the older stack of tabs did.
/// - [position] carries the fractional page while it moves, so a tab bar can
///   follow the finger.
/// - With reduced motion the pages switch at once.
/// - A page that scrolls sideways itself (a row of chips) keeps its own drags.
class SwipeTabs extends StatefulWidget {
  const SwipeTabs({
    super.key,
    required this.index,
    required this.onIndexChanged,
    required this.children,
    this.position,
    this.duration = const Duration(milliseconds: 380),
    this.curve = Curves.easeOutCubic,
  });

  final int index;

  /// Called when a swipe lands on another page. Not called when [index]
  /// itself was the cause.
  final ValueChanged<int> onIndexChanged;
  final List<Widget> children;

  /// Receives the page position (0 to children.length - 1) as it moves.
  final ValueNotifier<double>? position;
  final Duration duration;
  final Curve curve;

  @override
  State<SwipeTabs> createState() => _SwipeTabsState();
}

class _SwipeTabsState extends State<SwipeTabs> {
  late final PageController _controller;

  /// The page a slide started by [SwipeTabs.index] is heading for. While it is
  /// set, page changes on the way are not reported as swipes.
  int? _target;

  @override
  void initState() {
    super.initState();
    _controller = PageController(initialPage: widget.index)
      ..addListener(_report);
    // Tell whoever follows the position where the pages start, once this
    // frame is built (listeners must not be told while a frame is building).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_controller.position.isScrollingNotifier.value) {
        widget.position?.value = widget.index.toDouble();
      }
    });
  }

  void _report() {
    final ValueNotifier<double>? position = widget.position;
    if (position == null || !_controller.hasClients) {
      return;
    }
    final ScrollPosition p = _controller.position;
    if (p.haveDimensions) {
      position.value = _controller.page ?? widget.index.toDouble();
    }
  }

  @override
  void didUpdateWidget(SwipeTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.index == oldWidget.index || !_controller.hasClients) {
      return;
    }
    final int showing = (_controller.page ?? oldWidget.index).round();
    if (showing != widget.index) {
      unawaited(_slideTo(widget.index, showing));
    }
  }

  Future<void> _slideTo(int to, int from) async {
    _target = to;
    if (!AppMotion.of(context)) {
      _controller.jumpToPage(to);
      _target = null;
      return;
    }
    if ((to - from).abs() > 1) {
      // Next to the target first: one smooth move instead of a blur of pages.
      _controller.jumpToPage(from < to ? to - 1 : to + 1);
    }
    await _controller.animateToPage(
      to,
      duration: widget.duration,
      curve: widget.curve,
    );
    if (mounted && _target == to) {
      _target = null;
    }
  }

  void _onPageChanged(int page) {
    final int? target = _target;
    if (target != null) {
      if (page == target) {
        _target = null;
      }
      return;
    }
    if (page != widget.index) {
      widget.onIndexChanged(page);
    }
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_report)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollStartNotification>(
      onNotification: (ScrollStartNotification n) {
        // A finger on the pages takes over from any slide in progress.
        if (n.dragDetails != null && n.depth == 0) {
          _target = null;
        }
        return false;
      },
      child: PageView(
        controller: _controller,
        onPageChanged: _onPageChanged,
        physics: const PageScrollPhysics(parent: ClampingScrollPhysics()),
        dragStartBehavior: DragStartBehavior.down,
        // Neighbouring pages are built ahead, so a swipe never waits for one.
        allowImplicitScrolling: true,
        children: <Widget>[
          for (final (int i, Widget child) in widget.children.indexed)
            _KeepAlive(
              child: _PageEffect(
                controller: _controller,
                index: i,
                initialPage: widget.index,
                child: child,
              ),
            ),
        ],
      ),
    );
  }
}

/// Keeps a page's state while it is off screen.
class _KeepAlive extends StatefulWidget {
  const _KeepAlive({required this.child});

  final Widget child;

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive>
    with AutomaticKeepAliveClientMixin<_KeepAlive> {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

/// A page eases back a little (smaller and fainter) as it slides away, so the
/// swipe feels like depth rather than a flat slide. At rest the opacity is 1
/// and the scale 1, which Flutter paints without any extra layer.
class _PageEffect extends StatelessWidget {
  const _PageEffect({
    required this.controller,
    required this.index,
    required this.initialPage,
    required this.child,
  });

  final PageController controller;
  final int index;
  final int initialPage;
  final Widget child;

  static const double _shrink = 0.05;
  static const double _fade = 0.30;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      child: child,
      builder: (BuildContext context, Widget? child) {
        final double page =
            controller.hasClients && controller.position.haveDimensions
            ? (controller.page ?? initialPage.toDouble())
            : initialPage.toDouble();
        final double away = (page - index).abs().clamp(0, 1).toDouble();
        // The same wrappers at rest and in motion (a page's state is lost if
        // its parents change); at rest they draw nothing extra.
        return Opacity(
          opacity: 1 - _fade * away,
          child: Transform.scale(scale: 1 - _shrink * away, child: child),
        );
      },
    );
  }
}
