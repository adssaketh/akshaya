import 'package:flutter/material.dart';

import 'guide_screen.dart';

/// The "?" button in the Home header, placed just before the microphone.
/// Opens the user guide.
class GuideButton extends StatelessWidget {
  const GuideButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'User guide',
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      icon: const Icon(Icons.help_outline_rounded),
      onPressed: () => openGuide(context),
    );
  }
}
