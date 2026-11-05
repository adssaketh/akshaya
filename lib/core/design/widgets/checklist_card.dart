import 'package:flutter/material.dart';

import '../motion/app_motion.dart';
import '../motion/pressable.dart';
import '../motion/reveal.dart';
import '../theme/design_context.dart';
import '../tokens/layout_tokens.dart';

/// Check-off row for lists such as shopping: checkbox, title, optional
/// subtitle and an optional trailing widget (a status chip, say). Leave
/// [AppSpacing.sm] between stacked cards.
///
/// A checked card strikes its title through and softens its colours, so the
/// state is never carried by colour alone. Pass a null [onChanged] to show the
/// checkbox disabled (for rows that cannot be ticked yet).
class ChecklistCard extends StatelessWidget {
  const ChecklistCard({
    super.key,
    required this.title,
    required this.checked,
    this.subtitle,
    this.trailing,
    this.onChanged,
    this.onTap,
    this.revealIndex,
  });

  final String title;
  final bool checked;
  final String? subtitle;
  final Widget? trailing;

  /// Called with the new checked state. Null disables the checkbox.
  final ValueChanged<bool>? onChanged;

  /// Tapping the body of the card (the checkbox has its own target).
  final VoidCallback? onTap;

  /// Position in a list: when set, the card slides in with a stagger.
  final int? revealIndex;

  @override
  Widget build(BuildContext context) {
    final colors = context.akColors;
    final TextStyle titleStyle = context.akText.titleSmall!.copyWith(
      color: checked ? colors.textSecondary : colors.textPrimary,
      decoration: checked ? TextDecoration.lineThrough : TextDecoration.none,
    );

    final bool animate = AppMotion.of(context);
    final Widget card = AnimatedContainer(
      duration: animate ? AppMotion.base : Duration.zero,
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: checked ? colors.surfaceAlt : colors.surface,
        borderRadius: AppRadius.cardBorder,
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            children: <Widget>[
              AnimatedScale(
                scale: checked ? 1.12 : 1,
                duration: animate ? AppMotion.fast : Duration.zero,
                curve: AppMotion.pop,
                child: Checkbox(
                  value: checked,
                  semanticLabel: title,
                  onChanged: onChanged == null
                      ? null
                      : (bool? value) => onChanged!(value ?? false),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      AnimatedDefaultTextStyle(
                        style: titleStyle,
                        duration: animate ? AppMotion.base : Duration.zero,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        child: Text(title),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: context.akText.bodySmall!.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (trailing != null) ...<Widget>[
                const SizedBox(width: AppSpacing.sm),
                trailing!,
                const SizedBox(width: AppSpacing.sm),
              ],
            ],
          ),
        ),
        ),
      ),
    );

    final Widget pressable = Pressable(child: card);
    return revealIndex == null
        ? pressable
        : Reveal(index: revealIndex!, child: pressable);
  }
}
