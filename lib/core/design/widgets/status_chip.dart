import 'package:flutter/material.dart';

import '../motion/app_motion.dart';
import '../theme/design_context.dart';
import '../tokens/layout_tokens.dart';
import '../tokens/status_kind.dart';

/// Pill showing an item's status as icon + word on a tinted background.
///
/// Colour is never the only cue: each [StatusKind] has its own icon and label.
/// Long labels ellipsise at [AppSizes.chipMaxWidth] so large font scales never
/// overflow a row.
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.kind, this.label});

  final StatusKind kind;

  /// Overrides [StatusKind.label], e.g. "In 2 days" or "Expired 1d ago".
  final String? label;

  @override
  Widget build(BuildContext context) {
    final colors = context.akColors.forStatus(kind);
    final String text = label ?? kind.label;

    final Widget chip = ConstrainedBox(
      key: ValueKey<String>('${kind.name}|$text'),
      constraints: const BoxConstraints(maxWidth: AppSizes.chipMaxWidth),
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: colors.background,
          shape: const StadiumBorder(),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(kind.icon, size: AppSizes.iconXs, color: colors.foreground),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.akText.labelSmall!.copyWith(
                    color: colors.foreground,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // A changed status or label fades and scales into place.
    return AnimatedSwitcher(
      duration: AppMotion.of(context) ? AppMotion.fast : Duration.zero,
      switchInCurve: AppMotion.pop,
      transitionBuilder: (Widget child, Animation<double> animation) =>
          FadeTransition(
        opacity: animation,
        child: ScaleTransition(scale: animation, child: child),
      ),
      child: chip,
    );
  }
}
