import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/feedback.dart';
import '../../settings/presentation/providers.dart';
import '../../shopping/domain/shopping_entities.dart';
import '../../shopping/domain/shopping_enums.dart';
import '../../shopping/domain/shopping_repository.dart';
import '../../shopping/presentation/providers.dart';
import '../domain/repeat_learning.dart';
import '../domain/what_to_buy.dart';

/// Adds the chosen [recommendations] to the list [listId]. Returns true when
/// they were added.
Future<bool> addRecommendations(
  BuildContext context,
  WidgetRef ref, {
  required String listId,
  required List<BuyRecommendation> recommendations,
}) async {
  if (recommendations.isEmpty) {
    return false;
  }
  final ShoppingRepository repo = ref.read(shoppingRepositoryProvider);
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  try {
    await repo.addEntries(<ShoppingEntryDraft>[
      for (final BuyRecommendation r in recommendations) r.toDraft(listId),
    ]);
    showMessage(
      messenger,
      recommendations.length == 1
          ? 'Added ${recommendations.first.item.name}'
          : 'Added ${recommendations.length} items',
    );
    return true;
  } on Object catch (error) {
    showMessage(messenger, failureMessage(error));
    return false;
  }
}

/// Switches the suggested entry to the interval learned from purchases. The
/// entry keeps the closest built-in repeat too, so older app versions in the
/// household still read a sensible schedule. Undo restores the old one.
Future<void> applyScheduleSuggestion(
  BuildContext context,
  WidgetRef ref,
  ScheduleSuggestion suggestion,
) async {
  final ShoppingRepository repo = ref.read(shoppingRepositoryProvider);
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  final ShoppingEntry before = suggestion.entry;
  final int days = suggestion.learnedDays;
  final Recurrence nearest = Recurrence.nearestTo(days);
  final bool exact = nearest.approxDays == days;
  try {
    await repo.updateEntry(
      before.copyWith(
        recurrence: nearest,
        repeatEveryDays: exact ? null : days,
        clearRepeatEveryDays: exact,
      ),
    );
    showUndoSnackBar(
      messenger,
      message: '${before.name} now repeats ${suggestion.learnedLabel}',
      onUndo: () async {
        await repo.updateEntry(before);
      },
    );
  } on Object catch (error) {
    showMessage(messenger, failureMessage(error));
  }
}

/// Remembers that the person does not want [suggestion]; it stays hidden until
/// the learned interval changes noticeably.
Future<void> dismissScheduleSuggestion(
  BuildContext context,
  WidgetRef ref,
  ScheduleSuggestion suggestion,
) async {
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  final Map<String, String> stored =
      ref.read(settingsMapProvider).value ?? const <String, String>{};
  final Map<String, int> current =
      ScheduleDismissals.parse(stored[ScheduleDismissals.settingKey]);
  try {
    await ref.read(settingsRepositoryProvider).writeAll(<String, String>{
      ScheduleDismissals.settingKey: ScheduleDismissals.encodeWith(
        current,
        suggestion.entry.id,
        suggestion.learnedDays,
      ),
    });
  } on Object catch (error) {
    showMessage(messenger, failureMessage(error));
  }
}
