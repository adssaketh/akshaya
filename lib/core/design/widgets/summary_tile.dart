import 'package:flutter/material.dart';

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
  });

  final StatusKind kind;
  final int count;
  final String label;

  /// Defaults to the status icon.
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.akColors.forStatus(kind);

    return Semantics(
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
                Text(
                  '$count',
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
  }
}
