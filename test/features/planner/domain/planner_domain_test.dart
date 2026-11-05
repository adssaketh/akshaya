import 'package:akshaya/features/alerts/domain/alert_plan.dart';
import 'package:akshaya/features/alerts/domain/notification_gateway.dart';
import 'package:akshaya/features/pantry/domain/entities.dart';
import 'package:akshaya/features/pantry/domain/unit.dart';
import 'package:akshaya/features/planner/domain/meal_plan_models.dart';
import 'package:akshaya/features/planner/domain/meal_shopping.dart';
import 'package:akshaya/features/planner/domain/meal_slot.dart';
import 'package:akshaya/features/planner/domain/prep_rules.dart';
import 'package:akshaya/features/planner/domain/prep_schedule.dart';
import 'package:akshaya/features/recipes/domain/recipe_matcher.dart';
import 'package:akshaya/features/recipes/domain/recipe_models.dart';
import 'package:akshaya/features/shopping/domain/shopping_entities.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../pantry/domain/test_data.dart';
import '../../recipes/domain/recipe_test_support.dart';

MealPlanEntry mealOf(
  String id,
  DateTime date,
  MealSlot slot,
  Recipe? recipe, {
  String title = 'Meal',
  List<PrepReminder> prep = const <PrepReminder>[],
  bool cooked = false,
}) {
  return MealPlanEntry(
    id: id,
    date: date,
    slot: slot,
    title: recipe?.title ?? title,
    recipe: recipe,
    isCooked: cooked,
    prep: prep,
  );
}

void main() {
  group('models', () {
    test('prep reminders survive JSON', () {
      const List<PrepReminder> list = <PrepReminder>[
        PrepReminder(text: 'Soak Rajma'),
        PrepReminder(text: 'Thaw chicken', daysBefore: 0, minutesOfDay: 480),
      ];
      final String? text = PrepReminder.encodeList(list);
      expect(PrepReminder.decodeList(text), list);
      expect(PrepReminder.decodeList(null), isEmpty);
      expect(PrepReminder.decodeList('not json'), isEmpty);
    });

    test('kind follows the content', () {
      final Recipe r = recipeOf('Dal', const <RecipeIngredient>[]);
      expect(mealOf('a', kToday, MealSlot.lunch, r).kind, MealKind.recipe);
      expect(mealOf('b', kToday, MealSlot.lunch, null).kind, MealKind.text);
      expect(
        MealPlanEntry(
          id: 'c',
          date: kToday,
          slot: MealSlot.lunch,
          title: 'Curry',
          leftoverItemId: 'x',
        ).kind,
        MealKind.leftover,
      );
    });

    test('free text is cleaned to one line', () {
      expect(MealPlanDraft.cleanText('  Pesarattu \n  with  chutney '),
          'Pesarattu with chutney');
      expect(MealPlanDraft.cleanText('   '), isNull);
    });
  });

  group('prep rules', () {
    test('soaking beans gives a reminder the evening before', () {
      final Recipe rajma = recipeOf('Rajma Masala', const <RecipeIngredient>[
        RecipeIngredient(name: 'Rajma', quantity: 1, unit: Unit.pcs),
      ]);
      final List<PrepReminder> found =
          PrepRules.suggest(rajma, MealSlot.dinner);
      expect(found, isNotEmpty);
      final PrepReminder first = found.first;
      expect(first.text.toLowerCase(), contains('soak'));
      expect(first.text.toLowerCase(), contains('rajma'));
      expect(first.daysBefore, 1);
    });

    test('a plain recipe needs no prep', () {
      final Recipe r = recipeOf('Tomato Rice', const <RecipeIngredient>[
        RecipeIngredient(name: 'Rice'),
        RecipeIngredient(name: 'Tomato'),
      ]);
      expect(PrepRules.suggest(r, MealSlot.lunch), isEmpty);
    });
  });

  group('prep schedule', () {
    final Recipe r = recipeOf('Idli', const <RecipeIngredient>[]);
    final DateTime now = DateTime(2026, 11, 4, 18, 30);

    test('schedules a reminder before the meal at its time', () {
      final List<ScheduledAlert> out = PrepReminderPlanner.plan(
        <MealPlanEntry>[
          mealOf(
            'a',
            DateTime(2026, 11, 6),
            MealSlot.breakfast,
            r,
            prep: const <PrepReminder>[
              PrepReminder(text: 'Soak rice and urad dal'),
            ],
          ),
        ],
        now: now,
      );
      expect(out.length, 1);
      expect(out.single.fireAt, DateTime.utc(2026, 11, 5, 20));
      final AlertNotification n = out.single.notifications.single;
      expect(n.title, 'Soak rice and urad dal');
      expect(n.channel, AlertChannelKind.prep);
      expect(n.target, AlertTarget.mealPlan);
      expect(n.body, contains('tomorrow'));
    });

    test('skips cooked meals and reminders already past', () {
      final List<ScheduledAlert> out = PrepReminderPlanner.plan(
        <MealPlanEntry>[
          mealOf(
            'a',
            DateTime(2026, 11, 6),
            MealSlot.dinner,
            r,
            cooked: true,
            prep: const <PrepReminder>[PrepReminder(text: 'Soak')],
          ),
          mealOf(
            'b',
            DateTime(2026, 11, 4),
            MealSlot.dinner,
            r,
            prep: const <PrepReminder>[PrepReminder(text: 'Late')],
          ),
        ],
        now: now,
      );
      expect(out, isEmpty);
    });

    test('ids are unique', () {
      final List<ScheduledAlert> out = PrepReminderPlanner.plan(
        <MealPlanEntry>[
          for (int i = 0; i < 3; i++)
            mealOf(
              'm$i',
              DateTime(2026, 11, 6 + i),
              MealSlot.lunch,
              r,
              prep: const <PrepReminder>[PrepReminder(text: 'Soak')],
            ),
        ],
        now: now,
      );
      final Set<int> ids = <int>{
        for (final ScheduledAlert a in out)
          for (final AlertNotification n in a.notifications) n.id,
      };
      expect(ids.length, 3);
    });
  });

  group('shopping for the week', () {
    test('totals ingredients, subtracts stock, adds only what is missing', () {
      final RecipeMatcher matcher = RecipeMatcher(
        linesFor(<ItemWithBatches>[stocked('rice', 'Rice', qty: 1)]),
      );
      final Recipe a = recipeOf('Dish A', const <RecipeIngredient>[
        RecipeIngredient(name: 'Rice', quantity: 0.75, unit: Unit.kg),
        RecipeIngredient(name: 'Tomato', quantity: 2, unit: Unit.pcs),
      ]);
      final Recipe b = recipeOf('Dish B', const <RecipeIngredient>[
        RecipeIngredient(name: 'Rice', quantity: 0.75, unit: Unit.kg),
        RecipeIngredient(name: 'Tomato', quantity: 3, unit: Unit.pcs),
      ]);
      final MealShoppingResult result = MealShoppingPlanner.plan(
        entries: <MealPlanEntry>[
          mealOf('1', DateTime(2026, 11, 5), MealSlot.lunch, a),
          mealOf('2', DateTime(2026, 11, 6), MealSlot.dinner, b),
          mealOf('3', DateTime(2026, 11, 7), MealSlot.dinner, null,
              title: 'Outside'),
        ],
        matcher: matcher,
        listId: 'list',
        existing: const <ShoppingEntry>[],
        from: kToday,
      );
      expect(result.mealsCounted, 2);
      expect(result.mealsWithoutIngredients, 1);
      final Map<String, double> byName = <String, double>{
        for (final ShoppingEntryDraft d in result.drafts) d.name.toLowerCase(): d.quantity,
      };
      expect(byName['tomato'], 5);
      expect(byName['rice'], 0.5);
    });

    test('cooked and past meals are not counted', () {
      final RecipeMatcher matcher = RecipeMatcher(linesFor(const <ItemWithBatches>[]));
      final Recipe a = recipeOf('Dish A', const <RecipeIngredient>[
        RecipeIngredient(name: 'Tomato', quantity: 2, unit: Unit.pcs),
      ]);
      final MealShoppingResult result = MealShoppingPlanner.plan(
        entries: <MealPlanEntry>[
          mealOf('1', DateTime(2026, 11, 5), MealSlot.lunch, a, cooked: true),
          mealOf('2', DateTime(2026, 11, 3), MealSlot.lunch, a),
        ],
        matcher: matcher,
        listId: 'list',
        existing: const <ShoppingEntry>[],
        from: kToday,
      );
      expect(result.mealsCounted, 0);
      expect(result.drafts, isEmpty);
    });
  });
}
