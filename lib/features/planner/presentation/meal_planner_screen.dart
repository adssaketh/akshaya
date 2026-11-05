import 'package:akshaya/core/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/clock.dart';
import '../../../core/ui/feedback.dart';
import '../../../core/util/date_only.dart';
import '../../ai/presentation/ai_notice_dialog.dart';
import '../../recipes/domain/recipe_models.dart';
import '../../recipes/presentation/recipe_detail_screen.dart';
import '../domain/meal_plan_models.dart';
import '../domain/meal_plan_repository.dart';
import '../domain/meal_slot.dart';
import '../domain/plan_prompt.dart';
import '../domain/plan_validator.dart';
import 'meal_actions.dart';
import 'plan_week_sheet.dart';
import 'prep_reminders_sheet.dart';
import 'providers.dart';
import 'slot_picker_sheet.dart';

/// Opens the weekly meal planner.
Future<void> openMealPlanner(BuildContext context) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(builder: (BuildContext _) => const MealPlannerScreen()),
  );
}

const List<String> _weekdayNames = <String>[
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

IconData _slotIcon(MealSlot slot) {
  switch (slot) {
    case MealSlot.breakfast:
      return Icons.free_breakfast_rounded;
    case MealSlot.lunch:
      return Icons.lunch_dining_rounded;
    case MealSlot.dinner:
      return Icons.dinner_dining_rounded;
    case MealSlot.snack:
      return Icons.bakery_dining_rounded;
  }
}

/// Week view: seven days of Breakfast / Lunch / Dinner / Snack slots.
class MealPlannerScreen extends ConsumerWidget {
  const MealPlannerScreen({super.key});

  Future<void> _planWeek(
    BuildContext context,
    WidgetRef ref,
    List<MealPlanEntry> meals,
  ) async {
    final DateTime start = ref.read(weekStartProvider);
    final DateTime today = ref.read(todayProvider);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final List<PlanSlot>? slots = await showPlanWeekSheet(
      context,
      weekStart: start,
      today: today,
      taken: <String>{
        for (final MealPlanEntry e in meals)
          PlanResponseValidator.slotKey(e.date, e.slot),
      },
    );
    if (slots == null || slots.isEmpty || !context.mounted) {
      return;
    }
    final bool accepted = await ensureAiNotice(context, ref);
    final PlannerController controller =
        ref.read(plannerControllerProvider.notifier);
    final PlanWeekResult? result = await controller.planWeek(
      noticeAccepted: accepted,
      slots: slots,
      alreadyPlanned: <String>[for (final MealPlanEntry e in meals) e.title],
    );
    final String? problem = ref.read(plannerControllerProvider).message;
    if (result == null) {
      if (problem != null) {
        showMessage(messenger, problem);
        controller.clearMessage();
      }
      return;
    }
    final MealPlanRepository repository = ref.read(mealPlanRepositoryProvider);
    showUndoSnackBar(
      messenger,
      message: result.ids.isEmpty
          ? 'No new meals were added.'
          : 'Planned ${result.ids.length} of ${result.asked} meals.',
      onUndo: () => repository.deleteMany(result.ids),
    );
  }

  Future<void> _clearWeek(
    BuildContext context,
    WidgetRef ref,
    List<MealPlanEntry> meals,
  ) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    if (meals.isEmpty) {
      showMessage(messenger, 'This week is already empty.');
      return;
    }
    final MealPlanRepository repository = ref.read(mealPlanRepositoryProvider);
    final List<String> ids = <String>[for (final MealPlanEntry e in meals) e.id];
    await repository.deleteMany(ids);
    showUndoSnackBar(
      messenger,
      message: 'Cleared ${ids.length} meals.',
      onUndo: () => repository.undoDeleteMany(ids),
    );
  }

  Future<void> _tapSlot(
    BuildContext context,
    WidgetRef ref,
    DateTime date,
    MealSlot slot,
    MealPlanEntry? entry,
  ) async {
    if (entry != null) {
      await _showActions(context, ref, entry);
      return;
    }
    final MealPlanDraft? draft =
        await showSlotPicker(context, date: date, slot: slot);
    if (draft == null || !context.mounted) {
      return;
    }
    await putMeal(context, ref, draft);
  }

  Future<void> _showActions(
    BuildContext context,
    WidgetRef ref,
    MealPlanEntry entry,
  ) async {
    final _MealAction? action = await showModalBottomSheet<_MealAction>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (BuildContext _) => _MealActionsSheet(entry: entry),
    );
    if (action == null || !context.mounted) {
      return;
    }
    switch (action) {
      case _MealAction.open:
        final Recipe? recipe = entry.recipe;
        if (recipe != null) {
          await Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (BuildContext _) => RecipeDetailScreen(recipe: recipe),
            ),
          );
        }
      case _MealAction.cooked:
        await cookMeal(context, ref, entry);
      case _MealAction.prep:
        final List<PrepReminder>? prep = await showPrepReminders(context, entry);
        if (prep != null && context.mounted) {
          await setPrep(context, ref, entry, prep);
        }
      case _MealAction.replace:
        final MealPlanDraft? draft = await showSlotPicker(
          context,
          date: entry.date,
          slot: entry.slot,
        );
        if (draft != null && context.mounted) {
          await putMeal(context, ref, draft, previous: entry);
        }
      case _MealAction.remove:
        await removeMeal(context, ref, entry);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TextTheme text = context.akText;
    final AkshayaColors colors = context.akColors;
    final DateTime start = ref.watch(weekStartProvider);
    final DateTime today = ref.watch(todayProvider);
    final AsyncValue<List<MealPlanEntry>> async = ref.watch(weekMealsProvider);
    final PlannerUiState ui = ref.watch(plannerControllerProvider);
    final List<MealPlanEntry> meals =
        async.value ?? const <MealPlanEntry>[];
    final DateTime end = addDays(start, 6);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meal plan'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Plan my week',
            onPressed: ui.busy ? null : () => _planWeek(context, ref, meals),
            icon: const Icon(Icons.auto_awesome_rounded),
          ),
          PopupMenuButton<String>(
            tooltip: 'More',
            onSelected: (String v) {
              if (v == 'clear') {
                _clearWeek(context, ref, meals);
              }
            },
            itemBuilder: (BuildContext _) => const <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'clear',
                child: Text('Clear this week'),
              ),
            ],
          ),
        ],
        bottom: ui.busy
            ? const PreferredSize(
                preferredSize: Size.fromHeight(4),
                child: LinearProgressIndicator(),
              )
            : null,
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: FilledButton.icon(
            onPressed: () => shopForWeek(context, ref, meals),
            icon: const Icon(Icons.add_shopping_cart_rounded),
            label: const Text('Generate shopping list'),
          ),
        ),
      ),
      body: async.hasError && !async.hasValue
          ? const EmptyState(
              icon: Icons.error_outline_rounded,
              title: 'Could not load the plan',
              body: 'Close this screen and open it again.',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              children: <Widget>[
                Row(
                  children: <Widget>[
                    IconButton(
                      tooltip: 'Previous week',
                      onPressed: () =>
                          ref.read(weekStartProvider.notifier).shift(-1),
                      icon: const Icon(Icons.chevron_left_rounded),
                    ),
                    Expanded(
                      child: TextButton(
                        onPressed: () =>
                            ref.read(weekStartProvider.notifier).thisWeek(),
                        child: Text(
                          '${formatDateShort(start)} – ${formatDateShort(end)}',
                          style: text.titleMedium,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Next week',
                      onPressed: () =>
                          ref.read(weekStartProvider.notifier).shift(1),
                      icon: const Icon(Icons.chevron_right_rounded),
                    ),
                  ],
                ),
                if (meals.isEmpty && !async.isLoading)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: Text(
                      'Tap a slot to add a meal, or use the sparkle button to '
                      'let AI plan the week.',
                      style: text.bodyMedium
                          ?.copyWith(color: colors.textSecondary),
                    ),
                  ),
                for (int i = 0; i < 7; i++)
                  _DayCard(
                    date: addDays(start, i),
                    isToday: addDays(start, i) == dateOnly(today),
                    meals: <MealPlanEntry>[
                      for (final MealPlanEntry e in meals)
                        if (e.date == addDays(start, i)) e,
                    ],
                    onTap: (MealSlot slot, MealPlanEntry? entry) => _tapSlot(
                      context,
                      ref,
                      addDays(start, i),
                      slot,
                      entry,
                    ),
                  ),
              ],
            ),
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({
    required this.date,
    required this.isToday,
    required this.meals,
    required this.onTap,
  });

  final DateTime date;
  final bool isToday;
  final List<MealPlanEntry> meals;
  final void Function(MealSlot slot, MealPlanEntry? entry) onTap;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = context.akText;
    final AkshayaColors colors = context.akColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  AppSpacing.xs,
                ),
                child: Text(
                  '${_weekdayNames[date.weekday - 1]}, ${formatDateShort(date)}'
                  '${isToday ? ' · Today' : ''}',
                  style: text.titleSmall?.copyWith(
                    color: isToday ? colors.primary : colors.textPrimary,
                  ),
                ),
              ),
              for (final MealSlot slot in MealSlot.values)
                _slotRow(context, slot),
            ],
          ),
        ),
      ),
    );
  }

  Widget _slotRow(BuildContext context, MealSlot slot) {
    final TextTheme text = context.akText;
    final AkshayaColors colors = context.akColors;
    MealPlanEntry? entry;
    for (final MealPlanEntry e in meals) {
      if (e.slot == slot) {
        entry = e;
      }
    }
    final MealPlanEntry? meal = entry;
    return InkWell(
      onTap: () => onTap(slot, meal),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSizes.touchTarget),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            children: <Widget>[
              Icon(
                _slotIcon(slot),
                size: AppSizes.iconMd,
                color: colors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: meal == null
                    ? Text(
                        'Add ${slot.label.toLowerCase()}',
                        style: text.bodyMedium
                            ?.copyWith(color: colors.textSecondary),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            meal.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: text.bodyLarge?.copyWith(
                              decoration: meal.isCooked
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                          Text(
                            slot.label,
                            style: text.bodySmall
                                ?.copyWith(color: colors.textSecondary),
                          ),
                        ],
                      ),
              ),
              if (meal != null && meal.prep.isNotEmpty)
                Icon(
                  Icons.notifications_active_outlined,
                  size: AppSizes.iconSm,
                  color: colors.textSecondary,
                ),
              if (meal != null && meal.isCooked)
                Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.sm),
                  child: Icon(
                    Icons.check_circle_rounded,
                    size: AppSizes.iconMd,
                    color: colors.primary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _MealAction { open, cooked, prep, replace, remove }

class _MealActionsSheet extends StatelessWidget {
  const _MealActionsSheet({required this.entry});

  final MealPlanEntry entry;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = context.akText;
    void pick(_MealAction a) => Navigator.of(context).pop(a);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: Text(entry.title, style: text.titleLarge),
          ),
          if (entry.recipe != null)
            ListTile(
              leading: const Icon(Icons.menu_book_rounded),
              title: const Text('Open recipe'),
              onTap: () => pick(_MealAction.open),
            ),
          ListTile(
            leading: Icon(
              entry.isCooked
                  ? Icons.undo_rounded
                  : Icons.check_circle_outline_rounded,
            ),
            title: Text(
              entry.isCooked
                  ? 'Not cooked yet'
                  : (entry.kind == MealKind.text
                      ? 'Mark as done'
                      : 'I cooked this'),
            ),
            onTap: () => pick(_MealAction.cooked),
          ),
          if (entry.kind != MealKind.text || entry.prep.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.notifications_active_outlined),
              title: const Text('Prep reminders'),
              subtitle: Text(
                entry.prep.isEmpty
                    ? 'None'
                    : entry.prep.length == 1
                        ? '1 reminder'
                        : '${entry.prep.length} reminders',
              ),
              onTap: () => pick(_MealAction.prep),
            ),
          ListTile(
            leading: const Icon(Icons.swap_horiz_rounded),
            title: const Text('Replace'),
            onTap: () => pick(_MealAction.replace),
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline_rounded),
            title: const Text('Remove'),
            onTap: () => pick(_MealAction.remove),
          ),
        ],
      ),
    );
  }
}
