import 'package:flutter/material.dart';

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
  });

  final String title;
  final bool checked;
  final String? subtitle;
  final Widget? trailing;

  /// Called with the new checked state. Null disables the checkbox.
  final ValueChanged<bool>? onChanged;

  /// Tapping the body of the card (the checkbox has its own target).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.akColors;
    final TextStyle titleStyle = context.akText.titleSmall!.copyWith(
      color: checked ? colors.textSecondary : colors.textPrimary,
      decoration: checked ? TextDecoration.lineThrough : TextDecoration.none,
    );

    return Material(
      color: checked ? colors.surfaceAlt : colors.surface,
      borderRadius: AppRadius.cardBorder,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            children: <Widget>[
              Checkbox(
                value: checked,
                semanticLabel: title,
                onChanged: onChanged == null
                    ? null
                    : (bool? value) => onChanged!(value ?? false),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: titleStyle,
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
    );
  }
}
