import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/clock.dart';
import '../../../core/ui/feedback.dart';
import '../../../core/util/date_only.dart';
import '../../pantry/domain/consumption_type.dart';
import '../../pantry/domain/entities.dart';
import '../../pantry/domain/pantry_repository.dart';
import '../../pantry/domain/waste_reason.dart';
import '../../pantry/presentation/providers.dart';
import '../../pantry/presentation/use_stock_sheet.dart';
import '../domain/food_rescue.dart';
import '../domain/freeze_rules.dart';
import 'providers.dart';
import 'waste_reason_sheet.dart';

/// Opens the Use sheet for the item of [entry].
Future<void> rescueUse(BuildContext context, RescueEntry entry) {
  return showUseStockSheet(context, entry.stock);
}

/// Moves the batch of [entry] to the freezer and extends its date by the
/// category rule. Shows Undo, which puts the batch back exactly as it was.
Future<void> rescueFreeze(
  BuildContext context,
  WidgetRef ref,
  RescueEntry entry,
) async {
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  final PantryRepository repo = ref.read(pantryRepositoryProvider);
  final FreezePlan? plan = Freezer.plan(
    item: entry.item,
    batch: entry.batch,
    settings: ref.read(freezeSettingsProvider),
    today: ref.read(todayProvider),
  );
  if (plan == null) {
    showMessage(messenger, 'This cannot be frozen.');
    return;
  }
  final StockBatch original = entry.batch;
  try {
    await repo.updateBatch(plan.frozen);
    showUndoSnackBar(
      messenger,
      message: 'Froze ${entry.item.name}. Use by ${formatDate(plan.newExpiry)}.',
      onUndo: () async {
        await repo.updateBatch(original);
      },
    );
  } on Object catch (error) {
    showMessage(messenger, failureMessage(error));
  }
}

/// Asks why, then writes off the whole batch of [entry] (as expired when it is
/// past its date, otherwise as wasted). Shows Undo.
Future<void> rescueWaste(
  BuildContext context,
  WidgetRef ref,
  RescueEntry entry,
) async {
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  final PantryRepository repo = ref.read(pantryRepositoryProvider);
  final WasteReason? reason = await showWasteReasonSheet(
    context,
    itemName: entry.item.name,
    expired: entry.isExpired,
  );
  if (reason == null) {
    return;
  }
  try {
    final UseResult result = await repo.discardBatch(
      batchId: entry.batch.id,
      type: entry.isExpired ? ConsumptionType.expired : ConsumptionType.wasted,
      wasteReason: reason,
    );
    showUndoSnackBar(
      messenger,
      message: 'Wrote off ${entry.batch.unit.format(result.quantity)} of '
          '${entry.item.name}',
      onUndo: () => repo.undoUse(result),
    );
  } on Object catch (error) {
    showMessage(messenger, failureMessage(error));
  }
}
