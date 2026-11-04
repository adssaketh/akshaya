import 'package:flutter/material.dart';

import '../tokens/layout_tokens.dart';
import '../theme/design_context.dart';
import 'akshaya_logo.dart';
import 'kolam_motif.dart';

/// Top-of-screen brand header: vessel mark, wordmark, a faint kolam motif and
/// optional trailing [actions] (for example a notifications button).
class AkshayaHeader extends StatelessWidget {
  const AkshayaHeader({super.key, this.actions = const <Widget>[]});

  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Stack(
        alignment: Alignment.centerLeft,
        children: <Widget>[
          Positioned(
            right: AppSizes.touchTarget + AppSpacing.lg,
            child: const KolamMotif(),
          ),
          Row(
            children: <Widget>[
              const AkshayaLogo(),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text('Akshaya', style: context.akText.titleLarge),
                ),
              ),
              ...actions,
            ],
          ),
          const SizedBox(height: AppSizes.touchTarget),
        ],
      ),
    );
  }
}
