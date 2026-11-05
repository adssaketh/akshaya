import 'package:flutter/material.dart';

import '../motion/reveal.dart';
import '../theme/design_context.dart';
import '../tokens/layout_tokens.dart';
import 'sarukulu_motif.dart';

/// Empty state: an invitation, not an apology. Headline names the space, one
/// line of body copy explains it, and the optional button is a verb.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.akColors;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Reveal(
              scaleFrom: 0.8,
              distance: 12,
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  const SarukuluMotif(size: AppSizes.sarukuluEmpty),
                  Icon(icon, size: AppSizes.iconXl, color: colors.primary),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Reveal(
              index: 1,
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: context.akText.titleLarge,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Reveal(
              index: 2,
              child: Text(
                body,
                textAlign: TextAlign.center,
                style: context.akText.bodyMedium!.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ),
            if (actionLabel != null) ...<Widget>[
              const SizedBox(height: AppSpacing.xl),
              Reveal(
                index: 3,
                child: FilledButton(
                  onPressed: onAction,
                  child: Text(actionLabel!),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
