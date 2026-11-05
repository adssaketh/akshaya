import 'package:flutter/material.dart';

import '../tokens/layout_tokens.dart';
import '../theme/design_context.dart';
import 'akshaya_logo.dart';

/// Top-of-screen brand header: basket mark, "Akshaya Patra" wordmark and
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
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSizes.touchTarget),
        child: Row(
          children: <Widget>[
            const AkshayaLogo(),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  'Akshaya Patra',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.akText.titleLarge,
                ),
              ),
            ),
            ...actions,
          ],
        ),
      ),
    );
  }
}
