import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../theme/design_context.dart';
import '../tokens/layout_tokens.dart';

/// What happens to content as it slides under the floating bottom bar.
enum ScrollEdgeKind { off, fade, blur }

/// Fades (and optionally blurs) the bottom of [child], so lists vanish
/// cleanly under the floating bar instead of being cut off or showing through
/// as readable text. The same idea as Ping's "Scroll edge effect".
///
/// [barHeight] is the height of the bar the content runs under, measured from
/// the screen bottom. A solid bar hides content itself, so the fade is gone
/// by the middle of the bar and back in full a little above it; a glass bar
/// shows content through it, so the fade starts at the screen edge.
class ScrollEdgeEffect extends StatelessWidget {
  const ScrollEdgeEffect({
    super.key,
    required this.child,
    required this.kind,
    required this.barHeight,
    required this.glass,
    this.fadeExtra = AppSizes.edgeFadeMedium,
    this.blurSigma = AppSizes.edgeBlurMedium,
  });

  final Widget child;
  final ScrollEdgeKind kind;
  final double barHeight;
  final bool glass;

  /// Extra height of the fade zone above the bar.
  final double fadeExtra;

  /// Gaussian sigma of the strongest blur band (blur kind only).
  final double blurSigma;

  /// Distance from the screen bottom where content is fully gone.
  double get hide => glass ? 0 : barHeight * AppSizes.edgeSolidHideFactor;

  /// Distance from the screen bottom where content is fully visible again.
  double get full => glass
      ? barHeight * AppSizes.edgeGlassFullFactor +
            fadeExtra * AppSizes.edgeGlassExtraFactor
      : barHeight + fadeExtra;

  /// Bands blurring less than this (Gaussian sigma) are not drawn.
  static const double _minVisibleSigma = 0.6;

  /// Blur of band [i] (0 is next to the bar): strongest there, near zero at
  /// the top band so the zone has no visible upper edge.
  double _sigma(int i) {
    final double t = 1 - i / AppSizes.edgeBlurBands;
    return blurSigma * math.pow(t, AppSizes.edgeBlurEase).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    // The child always sits in the same Stack at the same position, whatever
    // the settings or bar height are. The bar height drops to 0 while the
    // keyboard is open; returning the bare child then would re-parent the
    // whole tab tree, which rebuilds every screen from scratch and closes the
    // keyboard the moment it opens.
    final bool active = kind != ScrollEdgeKind.off && barHeight > 0;
    return Stack(
      children: <Widget>[
        Positioned.fill(child: child),
        if (active) ..._overlays(context),
      ],
    );
  }

  /// The fade (and, for the blur kind, the blur bands) painted over the
  /// bottom of the content.
  List<Widget> _overlays(BuildContext context) {
    final Color page = context.akColors.background;
    final double hideAt = hide;
    final double fullAt = full;

    // A gradient from the page colour (opaque at the bar, clear at the top of
    // the zone) painted over the list. Unlike a ShaderMask this needs no
    // offscreen layer, so scrolling stays cheap on every frame.
    final double opaqueFrom = fullAt <= 0
        ? 1.0
        : ((fullAt - hideAt) / fullAt).clamp(0.0, 1.0);
    final Widget fade = Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      height: fullAt,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[page.withValues(alpha: 0), page, page],
              stops: <double>[0, opaqueFrom, 1],
            ),
          ),
        ),
      ),
    );
    if (kind == ScrollEdgeKind.fade) {
      return <Widget>[fade];
    }

    // Blur: thin bands, strongest next to the bar and easing to nothing where
    // content is fully visible. A real gradient blur is not available, so the
    // steps are made small enough (and eased) that no edge can be seen.
    final double band = fullAt / AppSizes.edgeBlurBands;
    return <Widget>[
      fade,
      for (int i = 0; i < AppSizes.edgeBlurBands; i++)
        // The faintest bands blur by a fraction of a pixel, which cannot be
        // seen but still costs a full backdrop pass every frame, so they are
        // left out. The other bands keep their places.
        if (_sigma(i) >= _minVisibleSigma)
          Positioned(
            left: 0,
            right: 0,
            bottom: band * i,
            height: band,
            child: IgnorePointer(
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: _sigma(i),
                    sigmaY: _sigma(i),
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
    ];
  }
}
