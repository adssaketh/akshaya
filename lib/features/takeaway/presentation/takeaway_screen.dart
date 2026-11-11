import 'package:akshaya/core/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/clock.dart';
import '../../../core/ui/feedback.dart';
import '../../../core/util/date_only.dart';
import '../../../core/util/money.dart';
import '../../report/domain/nutrition_table.dart';
import '../domain/food_estimate.dart';
import '../domain/takeaway_models.dart';
import '../domain/takeaway_repository.dart';
import 'providers.dart';
import 'takeaway_actions.dart';
import 'takeaway_form_screen.dart';

/// Opens the Takeaway food list.
Future<void> openTakeaway(BuildContext context) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(builder: (BuildContext _) => const TakeawayScreen()),
  );
}

/// Food eaten from outside the home, newest first. Each entry counts in the
/// eating report once Gemini has worked out its ingredients and nutrition.
class TakeawayScreen extends ConsumerWidget {
  const TakeawayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<TakeawayMeal>> meals = ref.watch(takeawaysProvider);
    final DateTime today = dateOnly(ref.watch(todayProvider));

    return Scaffold(
      appBar: AppBar(title: const Text('Takeaway food')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => openTakeawayForm(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add takeaway'),
      ),
      body: meals.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object _, StackTrace __) => const EmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Could not load takeaway food',
          body: 'Please try again in a moment.',
        ),
        data: (List<TakeawayMeal> list) {
          if (list.isEmpty) {
            return EmptyState(
              icon: Icons.takeout_dining_rounded,
              title: 'No takeaway food yet',
              body:
                  'Add food you ate from outside. It counts in your eating '
                  'report, worked out from its ingredients.',
              actionLabel: 'Add takeaway',
              onAction: () => openTakeawayForm(context),
            );
          }
          return _TakeawayList(meals: list, today: today);
        },
      ),
    );
  }
}

class _TakeawayList extends StatelessWidget {
  const _TakeawayList({required this.meals, required this.today});

  final List<TakeawayMeal> meals;
  final DateTime today;

  static String dayLabel(DateTime day, DateTime today) {
    final int ago = daysBetween(day, today);
    if (ago == 0) {
      return 'Today';
    }
    if (ago == 1) {
      return 'Yesterday';
    }
    return formatDate(day);
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> children = <Widget>[];
    DateTime? current;
    for (final TakeawayMeal meal in meals) {
      if (current == null || current != meal.eatenOn) {
        current = meal.eatenOn;
        children.add(SectionHeader(title: dayLabel(meal.eatenOn, today)));
      }
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: _TakeawayTile(meal: meal),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        96,
      ),
      children: children,
    );
  }
}

String _subtitle(TakeawayMeal meal) {
  return <String>[
    meal.meal.label,
    meal.portionsLabel,
    if (meal.price != null) formatMoney(meal.price!),
  ].join(' · ');
}

class _TakeawayTile extends ConsumerWidget {
  const _TakeawayTile({required this.meal});

  final TakeawayMeal meal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AkshayaColors colors = context.akColors;
    final bool busy = ref.watch(takeawayBusyProvider).contains(meal.id);
    final FoodEstimate? estimate = meal.estimate;
    final String trailing;
    if (estimate != null) {
      trailing = estimate.isFood
          ? '≈ ${estimate.forPortions(meal.portions).kcal.round()} kcal'
          : 'Not food';
    } else if (busy) {
      trailing = 'Working it out…';
    } else {
      trailing = 'No estimate yet';
    }

    return Material(
      color: colors.surface,
      borderRadius: AppRadius.cardBorder,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showTakeawayDetail(context, meal.id),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: <Widget>[
              Icon(Icons.takeout_dining_rounded, color: colors.primary),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      meal.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.akText.titleSmall,
                    ),
                    Text(
                      _subtitle(meal),
                      style: context.akText.bodySmall!.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              if (busy)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Text(
                  trailing,
                  style: context.akText.labelMedium!.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The details of one takeaway: what Gemini found in it, the estimate and the
/// actions.
Future<void> showTakeawayDetail(BuildContext context, String id) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext _) => _TakeawayDetail(id: id),
  );
}

class _TakeawayDetail extends ConsumerWidget {
  const _TakeawayDetail({required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AkshayaColors colors = context.akColors;
    final List<TakeawayMeal> all =
        ref.watch(takeawaysProvider).value ?? const <TakeawayMeal>[];
    TakeawayMeal? meal;
    for (final TakeawayMeal m in all) {
      if (m.id == id) {
        meal = m;
      }
    }
    if (meal == null) {
      return const SizedBox(
        height: 120,
        child: Center(child: Text('This takeaway was removed.')),
      );
    }
    final TakeawayMeal shown = meal;
    final bool busy = ref.watch(takeawayBusyProvider).contains(id);
    final FoodEstimate? estimate = shown.estimate;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(shown.name, style: context.akText.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${_subtitle(shown)} · ${formatDate(shown.eatenOn)}',
              style: context.akText.bodyMedium!.copyWith(
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (busy)
              Row(
                children: <Widget>[
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Checking the ingredients…',
                      style: context.akText.bodyMedium,
                    ),
                  ),
                ],
              )
            else if (estimate == null)
              _NoEstimate(meal: shown)
            else if (!estimate.isFood)
              Text(
                'Gemini says this is not food, so it is not counted.',
                style: context.akText.bodyMedium,
              )
            else
              _EstimateBody(meal: shown, estimate: estimate),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      openTakeawayForm(context, meal: shown);
                    },
                    icon: const Icon(Icons.edit_rounded),
                    label: const Text('Edit'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _delete(context, ref, shown),
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('Delete'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    TakeawayMeal meal,
  ) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final NavigatorState navigator = Navigator.of(context);
    final TakeawayRepository repo = ref.read(takeawayRepositoryProvider);
    try {
      await repo.delete(meal.id);
      navigator.pop();
      showUndoSnackBar(
        messenger,
        message: 'Deleted ${meal.name}',
        onUndo: () => repo.undoDelete(meal.id),
      );
    } on Object catch (error) {
      showMessage(messenger, failureMessage(error));
    }
  }
}

class _NoEstimate extends ConsumerWidget {
  const _NoEstimate({required this.meal});

  final TakeawayMeal meal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AkshayaColors colors = context.akColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Not counted in the eating report yet. Gemini needs to check the '
          'ingredients first.',
          style: context.akText.bodyMedium!.copyWith(
            color: colors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        FilledButton.icon(
          onPressed: () => workOutEstimate(
            estimator: ref.read(foodEstimatorProvider),
            messenger: ScaffoldMessenger.of(context),
            meal: meal,
          ),
          icon: const Icon(Icons.auto_awesome_rounded),
          label: const Text('Check ingredients'),
        ),
      ],
    );
  }
}

class _EstimateBody extends StatelessWidget {
  const _EstimateBody({required this.meal, required this.estimate});

  final TakeawayMeal meal;
  final FoodEstimate estimate;

  @override
  Widget build(BuildContext context) {
    final AkshayaColors colors = context.akColors;
    final EnergyEstimate total = estimate.forPortions(meal.portions);
    final String ingredients = estimate.ingredientsLabel;
    Widget stat(String label, String value) => Expanded(
      child: Column(
        children: <Widget>[
          Text(value, style: context.akText.titleMedium),
          Text(
            label,
            style: context.akText.bodySmall!.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Ingredients (one serving)', style: context.akText.titleSmall),
        const SizedBox(height: AppSpacing.xs),
        Text(
          ingredients.isEmpty ? 'No ingredients listed.' : ingredients,
          style: context.akText.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Estimate for ${meal.portionsLabel} '
          '(about ${total.amount.round()} g)',
          style: context.akText.titleSmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: <Widget>[
            stat('kcal', total.kcal.round().toString()),
            stat('protein g', total.protein.round().toString()),
            stat('carbs g', total.carbs.round().toString()),
            stat('fat g', total.fat.round().toString()),
            stat('fibre g', total.fibre.round().toString()),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'A rough estimate from the ingredients, not a measurement. Real '
          'amounts depend on the cook and the portion size.',
          style: context.akText.bodySmall!.copyWith(
            color: colors.textSecondary,
          ),
        ),
      ],
    );
  }
}
