import 'package:flutter/material.dart';

import '../tokens/layout_tokens.dart';

/// A round icon button for the trailing side of [AkshayaHeader]. Every header
/// action (voice, guide, count mode, meal plan...) uses this, so they share
/// one size, one colour and one touch target.
class HeaderAction extends StatelessWidget {
  const HeaderAction({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      iconSize: AppSizes.iconLg,
      constraints: const BoxConstraints(
        minWidth: AppSizes.touchTarget,
        minHeight: AppSizes.touchTarget,
      ),
      icon: Icon(icon),
    );
  }
}
