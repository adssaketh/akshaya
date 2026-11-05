import 'package:akshaya/features/pantry/domain/unit.dart';
import 'package:akshaya/features/recipes/domain/recipe_models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'recipe_test_support.dart';

void main() {
  group('RecipeDiet', () {
    test('a diet allows its own kind and the stricter ones', () {
      expect(RecipeDiet.veg.allows(RecipeDiet.veg), isTrue);
      expect(RecipeDiet.veg.allows(RecipeDiet.egg), isFalse);
      expect(RecipeDiet.egg.allows(RecipeDiet.veg), isTrue);
      expect(RecipeDiet.egg.allows(RecipeDiet.nonVeg), isFalse);
      expect(RecipeDiet.nonVeg.allows(RecipeDiet.egg), isTrue);
    });

    test('fromKey ignores case and unknown values', () {
      expect(RecipeDiet.fromKey(' NON_VEG '), RecipeDiet.nonVeg);
      expect(RecipeDiet.fromKey('vegan'), isNull);
      expect(RecipeDiet.fromKey(null), isNull);
    });
  });

  group('RecipePreferences', () {
    test('defaults when nothing is stored', () {
      final RecipePreferences p =
          RecipePreferences.fromMap(const <String, String>{});
      expect(p.diet, RecipeDiet.veg);
      expect(p.cuisine, RecipeCuisine.any);
      expect(p.maxMinutes, kDefaultRecipeMinutes);
      expect(p.people, kDefaultRecipePeople);
      expect(p.avoid, isEmpty);
    });

    test('roundtrips through its settings map', () {
      const RecipePreferences p = RecipePreferences(
        diet: RecipeDiet.egg,
        cuisine: RecipeCuisine.andhra,
        maxMinutes: 30,
        people: 4,
        avoid: <String>['peanuts', 'mushroom'],
      );
      expect(RecipePreferences.fromMap(p.toMap()), p);
    });

    test('clamps silly stored numbers', () {
      final RecipePreferences p = RecipePreferences.fromMap(
        const <String, String>{
          RecipeSettingKeys.maxMinutes: '5000',
          RecipeSettingKeys.people: '-3',
        },
      );
      expect(p.maxMinutes, 240);
      expect(p.people, 1);
    });

    test('parseAvoid cleans, dedupes and limits the list', () {
      expect(
        RecipePreferences.parseAvoid(' Peanuts, peanuts;  {Shell fish}\n,, '),
        <String>['Peanuts', 'Shell fish'],
      );
      final String many = List<String>.generate(20, (int i) => 'a$i').join(',');
      expect(RecipePreferences.parseAvoid(many).length, kMaxAvoidEntries);
      expect(
        RecipePreferences.parseAvoid('x' * 100).single.length,
        kMaxAvoidLength,
      );
    });

    test('summary reads as one line', () {
      const RecipePreferences p = RecipePreferences(
        cuisine: RecipeCuisine.southIndian,
        people: 1,
      );
      expect(p.summary, 'Vegetarian · South Indian · up to 45 min · for 1 person');
    });
  });

  group('Recipe JSON', () {
    test('roundtrips, including units and item hints', () {
      final Recipe r = recipeOf('Tomato Rice', const <RecipeIngredient>[
        RecipeIngredient(
          name: 'Rice',
          quantity: 0.5,
          unit: Unit.kg,
          itemId: 'i1',
        ),
        RecipeIngredient(name: 'Curry leaves'),
      ]);
      final Recipe? back = Recipe.fromJson(r.toJson());
      expect(back, isNotNull);
      expect(back!.title, 'Tomato Rice');
      expect(back.ingredients.first.unit, Unit.kg);
      expect(back.ingredients.first.itemId, 'i1');
      expect(back.ingredients.last.quantity, isNull);
    });

    test('damaged recipes are skipped, never thrown', () {
      expect(Recipe.fromJson('nope'), isNull);
      expect(Recipe.fromJson(<String, Object?>{'title': 'x'}), isNull);
      expect(
        RecipeCacheEntry.decodeRecipes('not json'),
        isEmpty,
      );
      expect(Recipe.decodeIngredients('{'), isEmpty);
      expect(Recipe.decodeSteps('{'), isEmpty);
    });

    test('contentKey ignores case and ingredient order', () {
      final Recipe a = recipeOf('Tomato  Rice', const <RecipeIngredient>[
        RecipeIngredient(name: 'Rice'),
        RecipeIngredient(name: 'Tomato'),
      ]);
      final Recipe b = recipeOf('tomato rice', const <RecipeIngredient>[
        RecipeIngredient(name: 'tomato'),
        RecipeIngredient(name: 'RICE'),
      ]);
      expect(a.contentKey, b.contentKey);
    });
  });
}
