import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/feedback.dart';
import '../../pantry/domain/consumption_type.dart';
import '../../pantry/domain/entities.dart';
import '../../pantry/domain/pantry_repository.dart';
import '../../pantry/presentation/providers.dart';
import '../domain/travel_plan.dart';

/// Writes off the whole batch of [risk] as "given away" (food passed on to a
/// neighbour or friend). It is logged but not counted as waste. Shows Undo.
Future<void> travelGiveAway(
  BuildContext context,
  WidgetRef ref,
  TravelRisk risk,
) async {
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  final PantryRepository repo = ref.read(pantryRepositoryProvider);
  try {
    final UseResult result = await repo.discardBatch(
      batchId: risk.batch.id,
      type: ConsumptionType.givenAway,
    );
    showUndoSnackBar(
      messenger,
      message: 'Gave away ${risk.batch.unit.format(result.quantity)} of '
          '${risk.item.name}',
      onUndo: () => repo.undoUse(result),
    );
  } on Object catch (error) {
    showMessage(messenger, failureMessage(error));
  }
}
