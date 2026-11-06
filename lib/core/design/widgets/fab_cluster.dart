import 'package:flutter/material.dart';

import '../motion/pop_in.dart';
import '../theme/design_context.dart';
import '../tokens/layout_tokens.dart';

/// A small secondary action stacked above the main FAB.
@immutable
class MiniFab {
  const MiniFab({
    required this.heroTag,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String heroTag;
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
}

/// The floating action area of a tab: ONE extended primary action, with any
/// secondary actions as small tonal buttons above it. Every tab uses this, so
/// the buttons look and sit the same everywhere.
///
/// Every tab stays alive in the shell, so each FAB needs its own [heroTag].
class AkshayaFabCluster extends StatelessWidget {
  const AkshayaFabCluster({
    super.key,
    required this.heroTag,
    required this.label,
    required this.onPressed,
    this.icon = Icons.add_rounded,
    this.minis = const <MiniFab>[],
  });

  final String heroTag;
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final List<MiniFab> minis;

  @override
  Widget build(BuildContext context) {
    final colors = context.akColors;
    return PopIn(
      child: Padding(
        padding: EdgeInsets.only(bottom: context.navBarInset),
        child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          for (final MiniFab m in minis) ...<Widget>[
            FloatingActionButton.small(
              heroTag: m.heroTag,
              tooltip: m.tooltip,
              backgroundColor: colors.surfaceAlt,
              foregroundColor: colors.primary,
              onPressed: m.onPressed,
              child: Icon(m.icon),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          FloatingActionButton.extended(
            heroTag: heroTag,
            onPressed: onPressed,
            icon: Icon(icon),
            label: Text(label),
          ),
        ],
        ),
      ),
    );
  }
}
