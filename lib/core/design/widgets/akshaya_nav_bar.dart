import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../motion/app_motion.dart';
import '../motion/pressable.dart';
import '../theme/design_context.dart';
import '../tokens/akshaya_colors.dart';
import '../tokens/layout_tokens.dart';

/// One tab of [AkshayaNavBar].
@immutable
class AkshayaNavDestination {
  const AkshayaNavDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// Frosted-glass look for [AkshayaNavBar]: the bar colour at [opacity] over a
/// blurred copy of the page, with an optional thin light rim.
@immutable
class NavBarGlass {
  const NavBarGlass({
    required this.opacity,
    required this.blurSigma,
    required this.edge,
  });

  /// 0..1, how much of the bar colour stays opaque.
  final double opacity;
  final double blurSigma;
  final bool edge;
}

/// The bottom navigation bar: a floating, fully rounded pill with a soft
/// shadow, a rounded indicator that slides (with a small overshoot) behind the
/// selected icon, and a bold label under the selected tab. It arrives with a
/// short slide-up on first build. Same shape and motion as the bar in Ping.
class AkshayaNavBar extends StatelessWidget {
  const AkshayaNavBar({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
    this.glass,
    this.position,
  });

  final List<AkshayaNavDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  /// The page position (0 to destinations.length - 1) while pages are being
  /// swiped. The indicator then follows it exactly, with no animation of its
  /// own. Null: the indicator slides to [selectedIndex] as before.
  final ValueListenable<double>? position;

  /// Null for the solid bar.
  final NavBarGlass? glass;

  @override
  Widget build(BuildContext context) {
    final bool animate = AppMotion.of(context);
    final Widget bar = SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.xs,
          AppSpacing.md,
          AppSpacing.sm,
        ),
        // heightFactor: 1 keeps the bar as tall as its content. A plain Center
        // would fill all the height the Scaffold offers and squeeze the body.
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppSizes.navMaxWidth),
            child: _Pill(
              destinations: destinations,
              selectedIndex: selectedIndex,
              onSelected: onSelected,
              animate: animate,
              glass: glass,
              position: position,
            ),
          ),
        ),
      ),
    );
    if (!animate) {
      return bar;
    }
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 1, end: 0),
      duration: AppMotion.slow,
      curve: AppMotion.enter,
      child: bar,
      builder: (BuildContext context, double t, Widget? child) {
        return Opacity(
          opacity: 1 - t,
          child: FractionalTranslation(
            translation: Offset(0, t),
            child: child,
          ),
        );
      },
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
    required this.animate,
    required this.glass,
    required this.position,
  });

  final List<AkshayaNavDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final bool animate;
  final NavBarGlass? glass;
  final ValueListenable<double>? position;

  @override
  Widget build(BuildContext context) {
    final colors = context.akColors;
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color shadow = Theme.of(context).shadowColor.withValues(
          alpha: dark ? AppSizes.navShadowAlphaDark : AppSizes.navShadowAlpha,
        );

    final NavBarGlass? g = glass;
    final BorderRadius radius = BorderRadius.circular(AppRadius.navBar);
    final Widget content = _content(context, colors);

    // At least navBarHeight tall; grows when the system font is enlarged.
    final Widget bar = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppSizes.navBarHeight),
      child: g == null
          ? DecoratedBox(
              // Tinted bar (not the page colour) so it stands out.
              decoration: BoxDecoration(
                color: colors.surfaceAlt,
                borderRadius: radius,
                boxShadow: _shadow(shadow),
              ),
              child: content,
            )
          : DecoratedBox(
              // The shadow sits outside the clip so the blur is not cut off.
              decoration: BoxDecoration(
                borderRadius: radius,
                boxShadow: _shadow(shadow),
              ),
              child: ClipRRect(
                borderRadius: radius,
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: g.blurSigma,
                    sigmaY: g.blurSigma,
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.surfaceAlt.withValues(alpha: g.opacity),
                      borderRadius: radius,
                      border: g.edge
                          ? Border.all(
                              width: AppSizes.navGlassEdgeWidth,
                              color: colors.surface.withValues(
                                alpha: dark
                                    ? AppSizes.navGlassEdgeAlphaDark
                                    : AppSizes.navGlassEdgeAlpha,
                              ),
                            )
                          : null,
                    ),
                    child: content,
                  ),
                ),
              ),
            ),
    );
    return bar;
  }

  Widget _indicator(AkshayaColors colors) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.primary,
        borderRadius: BorderRadius.circular(AppSizes.navIndicatorHeight),
      ),
    );
  }

  static List<BoxShadow> _shadow(Color color) => <BoxShadow>[
        BoxShadow(
          color: color,
          blurRadius: AppSizes.navShadowBlur,
          offset: const Offset(0, AppSizes.navShadowOffset),
        ),
      ];

  Widget _content(BuildContext context, AkshayaColors colors) {
    return Center(
          heightFactor: 1,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.navPadding,
            ),
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints box) {
                final double slot = box.maxWidth / destinations.length;
                final double left = slot * selectedIndex +
                    (slot - AppSizes.navIndicatorWidth) / 2;
                return Stack(
                  children: <Widget>[
                    // The indicator slides between tabs instead of fading, or
                    // follows the pages exactly while they are swiped.
                    if (position == null)
                      AnimatedPositioned(
                        duration: animate ? AppMotion.base : Duration.zero,
                        curve: AppMotion.pop,
                        left: left,
                        top: AppSpacing.xs / 2,
                        width: AppSizes.navIndicatorWidth,
                        height: AppSizes.navIndicatorHeight,
                        child: _indicator(colors),
                      )
                    else
                      ValueListenableBuilder<double>(
                        valueListenable: position!,
                        child: _indicator(colors),
                        builder: (BuildContext context, double page, Widget? child) {
                          final double at = page
                              .clamp(0, destinations.length - 1)
                              .toDouble();
                          return Positioned(
                            left: slot * at +
                                (slot - AppSizes.navIndicatorWidth) / 2,
                            top: AppSpacing.xs / 2,
                            width: AppSizes.navIndicatorWidth,
                            height: AppSizes.navIndicatorHeight,
                            child: child!,
                          );
                        },
                      ),
                    Row(
                      children: <Widget>[
                        for (final (int i, AkshayaNavDestination d)
                            in destinations.indexed)
                          Expanded(
                            child: _Item(
                              destination: d,
                              selected: i == selectedIndex,
                              onTap: () => onSelected(i),
                            ),
                          ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final AkshayaNavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.akColors;
    final TextStyle base = context.akText.labelMedium!;

    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Pressable(
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppSizes.touchTarget),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs / 2),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  SizedBox(
                    height: AppSizes.navIndicatorHeight,
                    child: Center(
                      child: Icon(
                        selected ? destination.selectedIcon : destination.icon,
                        size: AppSizes.navIcon,
                        color: selected ? colors.onPrimary : colors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs / 2),
                  Text(
                    destination.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: base.copyWith(
                      color:
                          selected ? colors.textPrimary : colors.textSecondary,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      fontVariations: <FontVariation>[
                        FontVariation('wght', selected ? 700 : 500),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
