import 'package:akshaya/features/pantry/domain/entities.dart';
import 'package:akshaya/features/pantry/domain/unit.dart';
import 'package:akshaya/features/recipes/domain/recipe_matcher.dart';
import 'package:akshaya/features/recipes/domain/recipe_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../pantry/domain/test_data.dart';
import 'recipe_test_support.dart';

void main() {
  RecipeMatcher matcher() {
    return RecipeMatcher(
      linesFor(<ItemWithBatches>[
        stocked('rice', 'Rice', qty: 5),
        stocked('tom', 'Tomato', qty: 3, unit: Unit.pcs),
        stocked('chilli', 'Green Chilli', qty: 6, unit: Unit.pcs),
        stocked('dal', 'Toor Dal', aliases: <String>['kandi pappu']),
        stocked(
          'rava',
          'Semolina (Rava)',
          qty: 1,
        ),
        stocked('curd', 'Curd', expiry: DateTime(2026, 11, 1)),
        ItemWithBatches(
          item: makeItem(id: 'milk', name: 'Milk', unit: Unit.L),
          batches: <StockBatch>[
            makeBatch(id: 'bm', itemId: 'milk', unit: Unit.L, remaining: 0),
          ],
        ),
      ]),
    );
  }

  IngredientMatch of(
    String name, {
    double? quantity,
    Unit? unit,
    String? itemId,
  }) {
    return matcher().match(
      RecipeIngredient(
        name: name,
        quantity: quantity,
        unit: unit,
        itemId: itemId,
      ),
    );
  }

  test('same words, plurals and descriptions match', () {
    expect(of('rice').availability, IngredientAvailability.inPantry);
    expect(of('Basmati Rice').itemId, 'rice');
    expect(of('Tomatoes').itemId, 'tom');
    expect(of('green chillies').itemId, 'chilli');
  });

  test('words that change the product stop a loose match', () {
    final IngredientMatch m = of('Chilli Powder');
    expect(m.availability, IngredientAvailability.missing);
    expect(m.line, isNull);
    expect(of('Rice Flour').line, isNull);
  });

  test('aliases and bracket names match', () {
    expect(of('Kandi Pappu').itemId, 'dal');
    expect(of('Rava').itemId, 'rava');
    expect(of('Semolina').itemId, 'rava');
  });

  test('water and salt are assumed on hand', () {
    expect(of('Salt').availability, IngredientAvailability.assumed);
    expect(of('water').availability, IngredientAvailability.assumed);
  });

  test('units convert; less than needed is short with a shortfall', () {
    final IngredientMatch enough =
        of('Rice', quantity: 500, unit: Unit.g);
    expect(enough.availability, IngredientAvailability.inPantry);
    expect(enough.needed, 0.5);

    final IngredientMatch short =
        of('Tomato', quantity: 5, unit: Unit.pcs);
    expect(short.availability, IngredientAvailability.short);
    expect(short.shortfall, 2);
  });

  test('a unit that cannot convert is not compared', () {
    final IngredientMatch m = of('Rice', quantity: 2, unit: Unit.pcs);
    expect(m.availability, IngredientAvailability.inPantry);
    expect(m.needed, isNull);
  });

  test('out of stock and expired items are missing but still point at the item',
      () {
    final IngredientMatch milk = of('Milk');
    expect(milk.availability, IngredientAvailability.missing);
    expect(milk.itemId, 'milk');
    final IngredientMatch curd = of('Curd');
    expect(curd.availability, IngredientAvailability.missing);
    expect(curd.itemId, 'curd');
  });

  test('a saved item hint wins over the name', () {
    expect(of('Mystery', itemId: 'dal').itemId, 'dal');
    expect(of('Mystery', itemId: 'gone').availability,
        IngredientAvailability.missing);
  });

  group('RecipeRanker', () {
    final RecipeMatcher m = matcher();
    final Recipe none = recipeOf('Plain Rice', const <RecipeIngredient>[
      RecipeIngredient(name: 'Rice'),
    ]);
    final Recipe one = recipeOf('Tomato Rice', const <RecipeIngredient>[
      RecipeIngredient(name: 'Rice'),
      RecipeIngredient(name: 'Tomato'),
    ]);
    final Recipe two = recipeOf('Tomato Dal', const <RecipeIngredient>[
      RecipeIngredient(name: 'Tomato'),
      RecipeIngredient(name: 'Toor Dal'),
      RecipeIngredient(name: 'Ginger'),
    ]);

    test('recipes using more expiring items come first', () {
      final List<RankedRecipe> ranked = RecipeRanker.rank(
        <Recipe>[none, one, two],
        m,
        expiringDays: <String, int>{'tom': 1, 'dal': 2},
      );
      expect(
        ranked.map((RankedRecipe r) => r.recipe.title).toList(),
        <String>['Tomato Dal', 'Tomato Rice', 'Plain Rice'],
      );
      expect(ranked.first.expiringUsed, <String>['Tomato', 'Toor Dal']);
      expect(ranked.first.soonestDays, 1);
      expect(ranked.first.missingCount, 1);
      expect(ranked.last.canCookNow, isTrue);
      expect(ranked.last.expiringUsed, isEmpty);
    });

    test('with nothing expiring, fewer missing ingredients come first', () {
      final List<RankedRecipe> ranked = RecipeRanker.rank(
        <Recipe>[two, one],
        m,
        expiringDays: const <String, int>{},
      );
      expect(ranked.first.recipe.title, 'Tomato Rice');
    });
  });
}
