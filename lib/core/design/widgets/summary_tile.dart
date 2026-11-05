import 'package:flutter/material.dart';

import '../motion/animated_count.dart';
import '../motion/pressable.dart';
import '../motion/reveal.dart';
import '../theme/design_context.dart';
import '../tokens/layout_tokens.dart';
import '../tokens/status_kind.dart';

/// Home dashboard tile: a status-tinted card with an icon, a big count and a
/// label. Tappable when [onTap] is given.
class SummaryTile extends StatelessWidget {
  const SummaryTile({
    super.key,
    required this.kind,
    required this.count,
    required this.label,
    this.icon,
    this.onTap,
    this.revealIndex,
  });

  final StatusKind kind;
  final int count;
  final String label;

  /// Defaults to the status icon.
  final IconData? icon;
  final VoidCallback? onTap;

  /// Position among the tiles: when set, the tile pops in with a stagger.
  final int? revealIndex;

  @override
  Widget build(BuildContext context) {
    final colors = context.akColors.forStatus(kind);

    final Widget tile = Semantics(
      container: true,
      button: onTap != null,
      label: '$count $label',
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: colors.background,
        borderRadius: AppRadius.cardBorder,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  icon ?? kind.icon,
                  size: AppSizes.iconSm,
                  color: colors.foreground,
                ),
                const SizedBox(height: AppSpacing.xs),
                AnimatedCount(
                  value: count,
                  style: context.akText.headlineMedium!.copyWith(
                    color: colors.foreground,
                  ),
                ),
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.akText.bodySmall!.copyWith(
                    color: context.akColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final Widget pressable = Pressable(enabled: onTap != null, child: tile);
    return revealIndex == null
        ? pressable
        : Reveal(index: revealIndex!, scaleFrom: 0.92, child: pressable);
  }
}
