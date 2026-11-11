import 'package:akshaya/core/design/design.dart';
import 'package:flutter/material.dart';

import 'usage_history_screen.dart';

/// The history button in the Home header, placed just before the "?" button.
/// Opens the usage history of every item and every takeaway.
class HistoryButton extends StatelessWidget {
  const HistoryButton({super.key});

  @override
  Widget build(BuildContext context) {
    return HeaderAction(
      tooltip: 'Usage history',
      icon: Icons.history_rounded,
      onPressed: () => openUsageHistory(context),
    );
  }
}
