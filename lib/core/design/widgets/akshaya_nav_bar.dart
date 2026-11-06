import 'package:flutter/material.dart';

import '../motion/app_motion.dart';
import '../theme/design_context.dart';
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
  });

  final List<AkshayaNavDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

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
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppSizes.navMaxWidth),
            child: _Pill(
              destinations: destinations,
              selectedIndex: selectedIndex,
              onSelected: onSelected,
              animate: animate,
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
  });

  final List<AkshayaNavDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final colors = context.akColors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.navBar),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: colors.textPrimary.withValues(alpha: 0.10),
            blurRadius: AppSizes.navShadowBlur,
            offset: const Offset(0, AppSizes.navShadowOffset),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.navPadding),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints box) {
            final double slot = box.maxWidth / destinations.length;
            final double left = slot * selectedIndex +
                (slot - AppSizes.navIndicatorWidth) / 2;
            return Stack(
              children: <Widget>[
                // The indicator slides between tabs instead of fading.
                AnimatedPositioned(
                  duration: animate ? AppMotion.base : Duration.zero,
                  curve: AppMotion.pop,
                  left: left,
                  top: AppSpacing.xs / 2,
                  width: AppSizes.navIndicatorWidth,
                  height: AppSizes.navIndicatorHeight,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.surfaceAlt,
                      borderRadius: BorderRadius.circular(
                        AppSizes.navIndicatorHeight,
                      ),
                    ),
                  ),
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
    final TextStyle base = context.akText.labelSmall!;

    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: AppSizes.touchTarget,
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
                      color: selected ? colors.primary : colors.textSecondary,
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
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    fontVariations: <FontVariation>[
                      FontVariation('wght', selected ? 800 : 600),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
