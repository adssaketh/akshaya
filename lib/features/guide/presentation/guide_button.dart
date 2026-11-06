import 'package:akshaya/core/design/design.dart';
import 'package:flutter/material.dart';

import 'guide_screen.dart';

/// The "?" button in the Home header, placed just before the microphone.
/// Opens the user guide.
class GuideButton extends StatelessWidget {
  const GuideButton({super.key});

  @override
  Widget build(BuildContext context) {
    return HeaderAction(
      tooltip: 'User guide',
      icon: Icons.help_outline_rounded,
      onPressed: () => openGuide(context),
    );
  }
}
