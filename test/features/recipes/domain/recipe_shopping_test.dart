import 'package:akshaya/features/pantry/domain/entities.dart';
import 'package:akshaya/features/pantry/domain/unit.dart';
import 'package:akshaya/features/recipes/domain/recipe_matcher.dart';
import 'package:akshaya/features/recipes/domain/recipe_models.dart';
import 'package:akshaya/features/recipes/domain/recipe_shopping.dart';
import 'package:akshaya/features/shopping/domain/shopping_entities.dart';
import 'package:akshaya/features/shopping/domain/shopping_enums.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../pantry/domain/test_data.dart';
import 'recipe_test_support.dart';

void main() {
  test('adds only what is missing or short, marked as for a recipe', () {
    final RecipeMatcher matcher = RecipeMatcher(
      linesFor(<ItemWithBatches>[
        stocked('rice', 'Rice', qty: 5),
        stocked('tom', 'Tomato', qty: 3, unit: Unit.pcs),
        ItemWithBatches(
          item: makeItem(id: 'milk', name: 'Milk', unit: Unit.L),
          batches: <StockBatch>[
            makeBatch(id: 'bm', itemId: 'milk', unit: Unit.L, remaining: 0),
          ],
        ),
      ]),
    );
    final Recipe recipe =
        recipeOf('Test Dish', const <RecipeIngredient>[
      RecipeIngredient(name: 'Rice', quantity: 1, unit: Unit.kg),
      RecipeIngredient(name: 'Tomato', quantity: 5, unit: Unit.pcs),
      RecipeIngredient(name: 'Milk', quantity: 500, unit: Unit.ml),
      RecipeIngredient(name: 'Ginger', quantity: 2, unit: Unit.pcs),
      RecipeIngredient(name: 'Curry Leaves'),
      RecipeIngredient(name: 'Salt'),
    ]);
    final List<ShoppingEntryDraft> drafts = RecipeShoppingPlanner.drafts(
      recipe: recipe,
      matches: matcher.matchAll(recipe),
      listId: 'list-1',
    );
    expect(
      drafts.map((ShoppingEntryDraft d) => d.name).toList(),
      <String>['Tomato', 'Milk', 'Ginger', 'Curry Leaves'],
    );
    final ShoppingEntryDraft tomato = drafts[0];
    expect(tomato.quantity, 2);
    expect(tomato.itemId, 'tom');
    final ShoppingEntryDraft milk = drafts[1];
    expect(milk.itemId, 'milk');
    expect(milk.unit, Unit.ml);
    expect(milk.quantity, 500);
    final ShoppingEntryDraft ginger = drafts[2];
    expect(ginger.itemId, isNull);
    final ShoppingEntryDraft leaves = drafts[3];
    expect(leaves.quantity, 1);
    expect(leaves.unit, Unit.pcs);
    for (final ShoppingEntryDraft d in drafts) {
      expect(d.listId, 'list-1');
      expect(d.addedReason, AddedReason.recipe);
      expect(d.notes, 'For Test Dish');
    }
  });

  test('a recipe that is fully covered adds nothing', () {
    final RecipeMatcher matcher = RecipeMatcher(
      linesFor(<ItemWithBatches>[stocked('rice', 'Rice', qty: 5)]),
    );
    final Recipe recipe = recipeOf('Plain', const <RecipeIngredient>[
      RecipeIngredient(name: 'Rice', quantity: 1, unit: Unit.kg),
    ]);
    expect(
      RecipeShoppingPlanner.drafts(
        recipe: recipe,
        matches: matcher.matchAll(recipe),
        listId: 'l',
      ),
      isEmpty,
    );
  });
}
