import 'package:flutter/material.dart';

import '../theme/design_context.dart';
import '../tokens/layout_tokens.dart';
import '../tokens/status_kind.dart';
import 'status_chip.dart';

/// Pantry/home list row: round icon, item name, "location · quantity left"
/// subtitle and a [StatusChip]. Leave 8 logical pixels ([AppSpacing.sm])
/// between stacked cards.
class ItemCard extends StatelessWidget {
  const ItemCard({
    super.key,
    required this.name,
    required this.subtitle,
    required this.icon,
    required this.status,
    this.statusLabel,
    this.onTap,
  });

  final String name;
  final String subtitle;
  final IconData icon;
  final StatusKind status;

  /// Overrides the chip's default label, e.g. "In 2 days".
  final String? statusLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.akColors;

    return Material(
      color: colors.surface,
      borderRadius: AppRadius.cardBorder,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: <Widget>[
              Container(
                width: AppSizes.avatar,
                height: AppSizes.avatar,
                decoration: BoxDecoration(
                  color: colors.surfaceAlt,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: AppSizes.iconMd, color: colors.primary),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.akText.titleSmall,
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.akText.bodySmall!.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              StatusChip(kind: status, label: statusLabel),
            ],
          ),
        ),
      ),
    );
  }
}
