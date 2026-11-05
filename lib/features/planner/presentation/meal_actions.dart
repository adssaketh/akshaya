import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/clock.dart';
import '../../../core/ui/feedback.dart';
import '../../../core/util/date_only.dart';
import '../../pantry/domain/consumption_type.dart';
import '../../pantry/domain/entities.dart';
import '../../pantry/domain/failures.dart';
import '../../pantry/domain/pantry_repository.dart';
import '../../pantry/domain/unit.dart';
import '../../pantry/presentation/providers.dart';
import '../../recipes/domain/cook_plan.dart';
import '../../recipes/domain/recipe_matcher.dart';
import '../../recipes/domain/recipe_models.dart';
import '../../recipes/domain/recipe_pantry.dart';
import '../../recipes/presentation/cook_sheet.dart';
import '../../recipes/presentation/providers.dart';
import '../../shopping/domain/shopping_entities.dart';
import '../../shopping/presentation/providers.dart';
import '../domain/meal_plan_models.dart';
import '../domain/meal_plan_repository.dart';
import '../domain/meal_shopping.dart';
import 'providers.dart';

/// Puts [draft] on the plan. [previous] is the meal it replaces, if any, so
/// Undo can bring it back.
Future<void> putMeal(
  BuildContext context,
  WidgetRef ref,
  MealPlanDraft draft, {
  MealPlanEntry? previous,
}) async {
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  final MealPlanRepository repository = ref.read(mealPlanRepositoryProvider);
  try {
    final MealPlanEntry saved = await repository.put(draft);
    showUndoSnackBar(
      messenger,
      message: previous == null ? 'Added to your plan.' : 'Meal replaced.',
      onUndo: () async {
        if (previous == null) {
          await repository.delete(saved.id);
        } else {
          await repository.update(previous);
        }
      },
    );
  } on Object catch (error) {
    showMessage(messenger, failureMessage(error));
  }
}

/// Takes a meal off the plan, with Undo.
Future<void> removeMeal(
  BuildContext context,
  WidgetRef ref,
  MealPlanEntry entry,
) async {
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  final MealPlanRepository repository = ref.read(mealPlanRepositoryProvider);
  try {
    await repository.delete(entry.id);
    showUndoSnackBar(
      messenger,
      message: 'Removed from your plan.',
      onUndo: () => repository.undoDelete(entry.id),
    );
  } on Object catch (error) {
    showMessage(messenger, failureMessage(error));
  }
}

/// Saves new prep reminders on a meal.
Future<void> setPrep(
  BuildContext context,
  WidgetRef ref,
  MealPlanEntry entry,
  List<PrepReminder> prep,
) async {
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  try {
    await ref
        .read(mealPlanRepositoryProvider)
        .update(entry.copyWith(prep: prep));
    showMessage(
      messenger,
      prep.isEmpty ? 'Prep reminders removed.' : 'Prep reminders saved.',
    );
  } on Object catch (error) {
    showMessage(messenger, failureMessage(error));
  }
}

/// Marks a meal as cooked and takes its ingredients out of the pantry, the
/// same way "I cooked this" does. Cooked again clears the mark.
Future<void> cookMeal(
  BuildContext context,
  WidgetRef ref,
  MealPlanEntry entry,
) async {
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  final MealPlanRepository plan = ref.read(mealPlanRepositoryProvider);
  try {
    if (entry.isCooked) {
      await plan.update(entry.copyWith(isCooked: false));
      return;
    }
    switch (entry.kind) {
      case MealKind.text:
        await plan.update(entry.copyWith(isCooked: true));
        showMessage(messenger, 'Marked as done.');
      case MealKind.leftover:
        await _eatLeftover(ref, messenger, entry);
      case MealKind.recipe:
        await _cookRecipe(context, ref, messenger, entry);
    }
  } on Object catch (error) {
    showMessage(messenger, failureMessage(error));
  }
}

Future<void> _eatLeftover(
  WidgetRef ref,
  ScaffoldMessengerState messenger,
  MealPlanEntry entry,
) async {
  final MealPlanRepository plan = ref.read(mealPlanRepositoryProvider);
  final PantryRepository pantry = ref.read(pantryRepositoryProvider);
  PantryLine? line;
  for (final PantryLine l in ref.read(pantryLinesProvider)) {
    if (l.itemId == entry.leftoverItemId) {
      line = l;
    }
  }
  if (line == null || !line.hasStock || line.unit != Unit.portion) {
    // Nothing to take out (eaten already, or not counted in portions).
    await plan.update(entry.copyWith(isCooked: true));
    showMessage(messenger, 'Marked as eaten. Nothing was taken from stock.');
    return;
  }
  try {
    final UseResult used = await pantry.useStock(
      itemId: line.itemId,
      quantity: 1,
      unit: Unit.portion,
      type: ConsumptionType.used,
    );
    await plan.update(entry.copyWith(isCooked: true));
    showUndoSnackBar(
      messenger,
      message: 'Took 1 portion of ${line.name}.',
      onUndo: () async {
        await pantry.undoUse(used);
        await plan.update(entry.copyWith(isCooked: false));
      },
    );
  } on PantryFailure catch (failure) {
    showMessage(messenger, failure.message);
  }
}

Future<void> _cookRecipe(
  BuildContext context,
  WidgetRef ref,
  ScaffoldMessengerState messenger,
  MealPlanEntry entry,
) async {
  final Recipe? recipe = entry.recipe;
  if (recipe == null) {
    return;
  }
  final RankedRecipe ranked = RecipeRanker.rank(
    <Recipe>[recipe],
    ref.read(recipeMatcherProvider),
    expiringDays: ref.read(expiringDaysProvider),
  ).first;
  final CookSheetResult? result =
      await showCookSheet(context, CookPlanner.plan(ranked.matches));
  if (result == null) {
    return;
  }
  final MealPlanRepository plan = ref.read(mealPlanRepositoryProvider);
  final PantryRepository pantry = ref.read(pantryRepositoryProvider);
  CookOutcome? outcome;
  if (result.requests.isNotEmpty) {
    outcome = await CookExecutor.run(
      pantry,
      result.requests,
      leftover: result.leftover,
      recipeTitle: recipe.title,
      today: ref.read(todayProvider),
    );
  }
  await plan.update(entry.copyWith(isCooked: true));
  if (outcome == null) {
    showMessage(messenger, 'Marked as cooked.');
    return;
  }
  if (outcome.failures.isNotEmpty) {
    showMessage(
      messenger,
      'Cooked, but some items could not be used: '
      '${outcome.failures.join(' ')}',
    );
    return;
  }
  final CookOutcome done = outcome;
  showUndoSnackBar(
    messenger,
    message: (done.usedCount == 1
            ? 'Took 1 item out of your pantry.'
            : 'Took ${done.usedCount} items out of your pantry.') +
        (done.leftover != null ? ' Leftovers saved.' : ''),
    onUndo: () async {
      await CookExecutor.undo(pantry, done);
      await plan.update(entry.copyWith(isCooked: false));
    },
  );
}

/// Adds what the week's recipes need beyond the pantry to the shopping list.
Future<void> shopForWeek(
  BuildContext context,
  WidgetRef ref,
  List<MealPlanEntry> meals,
) async {
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  final DateTime today = ref.read(todayProvider);
  final String listId =
      ref.read(selectedListProvider)?.id ?? kDefaultListId;
  final MealShoppingResult result = MealShoppingPlanner.plan(
    entries: meals,
    matcher: ref.read(recipeMatcherProvider),
    listId: listId,
    existing: ref.read(shoppingEntriesProvider).value ??
        const <ShoppingEntry>[],
    from: dateOnly(today),
  );
  if (result.mealsCounted == 0) {
    showMessage(messenger, 'No recipe meals left this week to shop for.');
    return;
  }
  if (result.drafts.isEmpty) {
    showMessage(
      messenger,
      result.alreadyOnList > 0
          ? 'Everything missing is already on your list.'
          : 'You have everything for these meals.',
    );
    return;
  }
  try {
    await ref.read(shoppingRepositoryProvider).addEntries(result.drafts);
    final int n = result.drafts.length;
    showMessage(
      messenger,
      n == 1
          ? 'Added 1 item to your shopping list.'
          : 'Added $n items to your shopping list.',
    );
  } on Object catch (error) {
    showMessage(messenger, failureMessage(error));
  }
}
