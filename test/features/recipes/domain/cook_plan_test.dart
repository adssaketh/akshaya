import 'package:akshaya/features/pantry/domain/consumption_type.dart';
import 'package:akshaya/features/pantry/domain/entities.dart';
import 'package:akshaya/features/pantry/domain/unit.dart';
import 'package:akshaya/features/recipes/domain/cook_plan.dart';
import 'package:akshaya/features/recipes/domain/recipe_matcher.dart';
import 'package:akshaya/features/recipes/domain/recipe_models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'recipe_test_support.dart';

void main() {
  RecipeMatcher matcher() {
    return RecipeMatcher(
      linesFor(<ItemWithBatches>[
        stocked('rice', 'Rice', qty: 5),
        stocked('tom', 'Tomato', qty: 3, unit: Unit.pcs),
        stocked('oil', 'Oil', qty: 1, unit: Unit.L),
      ]),
    );
  }

  CookPlan plan(List<RecipeIngredient> ingredients) {
    final Recipe r = recipeOf('Test', ingredients);
    return CookPlanner.plan(matcher().matchAll(r));
  }

  group('CookPlanner', () {
    test('an amount in stock is ready, converted to the recipe unit', () {
      final CookPlan p = plan(const <RecipeIngredient>[
        RecipeIngredient(name: 'Rice', quantity: 500, unit: Unit.g),
      ]);
      final CookLine line = p.lines.single;
      expect(line.state, CookLineState.ready);
      expect(line.quantity, 500);
      expect(line.unit, Unit.g);
      expect(line.startsChecked, isTrue);
    });

    test('less in stock proposes what is there', () {
      final CookLine line = plan(const <RecipeIngredient>[
        RecipeIngredient(name: 'Tomato', quantity: 5, unit: Unit.pcs),
      ]).lines.single;
      expect(line.state, CookLineState.short);
      expect(line.quantity, 3);
    });

    test('no amount, or an amount that cannot convert, needs the person', () {
      final CookPlan p = plan(const <RecipeIngredient>[
        RecipeIngredient(name: 'Tomato'),
        RecipeIngredient(name: 'Oil', quantity: 2, unit: Unit.pcs),
      ]);
      expect(p.lines.length, 2);
      for (final CookLine l in p.lines) {
        expect(l.state, CookLineState.needsAmount);
        expect(l.quantity, isNull);
        expect(l.startsChecked, isFalse);
      }
      expect(p.lines.last.unit, Unit.L);
    });

    test('missing items are listed apart; salt and water are left out', () {
      final CookPlan p = plan(const <RecipeIngredient>[
        RecipeIngredient(name: 'Ginger', quantity: 1, unit: Unit.pcs),
        RecipeIngredient(name: 'Salt'),
        RecipeIngredient(name: 'Rice', quantity: 1, unit: Unit.kg),
      ]);
      expect(p.lines.length, 1);
      expect(p.notInPantry.map((RecipeIngredient i) => i.name), <String>['Ginger']);
    });
  });

  group('CookExecutor', () {
    test('uses each confirmed amount as "cooked in recipe"', () async {
      final RecordingPantry pantry = RecordingPantry();
      final CookOutcome outcome = await CookExecutor.run(
        pantry,
        const <CookRequest>[
          CookRequest(itemId: 'rice', itemName: 'Rice', quantity: 500, unit: Unit.g),
          CookRequest(itemId: 'tom', itemName: 'Tomato', quantity: 2, unit: Unit.pcs),
        ],
      );
      expect(outcome.usedCount, 2);
      expect(outcome.failures, isEmpty);
      expect(
        pantry.used.map((r) => r.type).toSet(),
        <ConsumptionType>{ConsumptionType.cookedInRecipe},
      );
      expect(pantry.used.first.quantity, 500);
      expect(pantry.used.first.unit, Unit.g);
    });

    test('one failure does not stop the others', () async {
      final RecordingPantry pantry = RecordingPantry()..failing.add('tom');
      final CookOutcome outcome = await CookExecutor.run(
        pantry,
        const <CookRequest>[
          CookRequest(itemId: 'tom', itemName: 'Tomato', quantity: 9, unit: Unit.pcs),
          CookRequest(itemId: 'rice', itemName: 'Rice', quantity: 1, unit: Unit.kg),
        ],
      );
      expect(outcome.usedCount, 1);
      expect(outcome.failures, <String>['Tomato: Only 100 g left.']);
    });

    test('undo puts back everything, last first', () async {
      final RecordingPantry pantry = RecordingPantry();
      final CookOutcome outcome = await CookExecutor.run(
        pantry,
        const <CookRequest>[
          CookRequest(itemId: 'rice', itemName: 'Rice', quantity: 1, unit: Unit.kg),
          CookRequest(itemId: 'tom', itemName: 'Tomato', quantity: 2, unit: Unit.pcs),
        ],
      );
      await CookExecutor.undo(pantry, outcome);
      expect(pantry.undone.map((UseResult r) => r.itemId), <String>['tom', 'rice']);
    });
  });
}
