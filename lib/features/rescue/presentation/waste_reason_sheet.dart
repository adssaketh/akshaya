import 'package:akshaya/core/design/design.dart';
import 'package:flutter/material.dart';

import '../../pantry/domain/waste_reason.dart';

/// Asks why [itemName] is being thrown away and returns the answer, or null
/// when the sheet was dismissed.
///
/// Food that has passed its date ([expired]) starts with "Expired" picked;
/// food that has not cannot have expired, so that choice is not offered.
Future<WasteReason?> showWasteReasonSheet(
  BuildContext context, {
  required String itemName,
  required bool expired,
}) {
  return showModalBottomSheet<WasteReason>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (BuildContext sheetContext) {
      return WasteReasonSheet(itemName: itemName, expired: expired);
    },
  );
}

class WasteReasonSheet extends StatefulWidget {
  const WasteReasonSheet({
    super.key,
    required this.itemName,
    required this.expired,
  });

  final String itemName;
  final bool expired;

  @override
  State<WasteReasonSheet> createState() => _WasteReasonSheetState();
}

class _WasteReasonSheetState extends State<WasteReasonSheet> {
  late WasteReason? _picked = widget.expired ? WasteReason.expired : null;

  @override
  Widget build(BuildContext context) {
    final List<WasteReason> choices = widget.expired
        ? WasteReason.choices
        : WasteReason.choicesBeforeExpiry;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text('Mark ${widget.itemName} wasted', style: context.akText.titleLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'What happened? This feeds the waste report in Insights.',
            style: context.akText.bodyMedium!.copyWith(
              color: context.akColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              for (final WasteReason reason in choices)
                ChoiceChip(
                  label: Text(reason.label),
                  selected: _picked == reason,
                  onSelected: (bool selected) {
                    setState(() => _picked = selected ? reason : null);
                  },
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              const Spacer(),
              FilledButton(
                onPressed: _picked == null
                    ? null
                    : () => Navigator.of(context).pop(_picked),
                child: const Text('Mark wasted'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
