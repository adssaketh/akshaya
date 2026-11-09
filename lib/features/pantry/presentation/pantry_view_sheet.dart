import 'dart:async';

import 'package:akshaya/core/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'pantry_view_settings.dart';

/// Opens the "View mode" and "Zoom" sheet of the Pantry.
Future<void> showPantryViewSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (BuildContext _) => const _PantryViewSheet(),
  );
}

class _PantryViewSheet extends ConsumerWidget {
  const _PantryViewSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PantryViewSettings view = ref.watch(pantryViewProvider);
    final AkshayaColors colors = context.akColors;
    final bool listLike = view.mode == PantryViewMode.list ||
        view.mode == PantryViewMode.compact;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('View mode', style: context.akText.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: <Widget>[
                for (final PantryViewMode m in PantryViewMode.values)
                  Expanded(
                    child: _ModeTile(
                      icon: m.icon,
                      label: m.label,
                      selected: view.mode == m,
                      onTap: () => unawaited(savePantryView(ref, mode: m)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Zoom', style: context.akText.titleSmall),
            Row(
              children: <Widget>[
                Icon(
                  Icons.zoom_out_rounded,
                  size: AppSizes.iconMd,
                  color: colors.textSecondary,
                ),
                Expanded(
                  child: Slider(
                    value: view.zoom.toDouble(),
                    max: kPantryZoomMax.toDouble(),
                    divisions: kPantryZoomMax,
                    onChanged: (double v) =>
                        unawaited(savePantryView(ref, zoom: v.round())),
                  ),
                ),
                Icon(
                  Icons.zoom_in_rounded,
                  size: AppSizes.iconMd,
                  color: colors.textSecondary,
                ),
              ],
            ),
            Text(
              listLike
                  ? 'Makes the text in each row smaller or larger.'
                  : 'Changes how many items fit in one row.',
              style: context.akText.bodySmall!.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AkshayaColors colors = context.akColors;
    final Color tint = selected ? colors.primary : colors.textSecondary;
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.cardBorder,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: AppSizes.iconMd + 4, color: tint),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: context.akText.labelMedium!.copyWith(color: tint),
              ),
            ),
            const SizedBox(height: 4),
            AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: selected ? 28 : 0,
              height: 3,
              decoration: BoxDecoration(
                color: colors.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
