import 'package:akshaya/core/design/design.dart';
import 'package:flutter/material.dart';

import '../domain/app_settings.dart';

/// Three cards (Follow phone / Light / Dark), each with an icon and a label.
class ThemeChoicePicker extends StatelessWidget {
  const ThemeChoicePicker({
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final AppThemeChoice selected;
  final ValueChanged<AppThemeChoice> onChanged;

  static IconData _icon(AppThemeChoice c) {
    switch (c) {
      case AppThemeChoice.system:
        return Icons.brightness_auto_rounded;
      case AppThemeChoice.light:
        return Icons.light_mode_rounded;
      case AppThemeChoice.dark:
        return Icons.dark_mode_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        for (final AppThemeChoice c in AppThemeChoice.values) ...<Widget>[
          if (c != AppThemeChoice.values.first)
            const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _ThemeChoiceCard(
              choice: c,
              icon: _icon(c),
              isSelected: c == selected,
              onTap: () => onChanged(c),
            ),
          ),
        ],
      ],
    );
  }
}

class _ThemeChoiceCard extends StatelessWidget {
  const _ThemeChoiceCard({
    required this.choice,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final AppThemeChoice choice;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AkshayaColors colors = context.akColors;
    final TextTheme text = Theme.of(context).textTheme;
    final Color foreground = isSelected ? colors.primary : colors.textSecondary;
    return Semantics(
      button: true,
      selected: isSelected,
      label: choice.label,
      child: Material(
        color: isSelected ? colors.surfaceAlt : colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.cardBorder,
          side: BorderSide(
            color: isSelected ? colors.primary : colors.outline,
            width: isSelected ? 2 : AppSizes.borderWidth,
          ),
        ),
        child: InkWell(
          borderRadius: AppRadius.cardBorder,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.md,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(icon, size: AppSizes.iconLg, color: foreground),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  choice.label,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelLarge?.copyWith(
                    color: isSelected ? colors.textPrimary : colors.textSecondary,
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
