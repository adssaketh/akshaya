import 'package:akshaya/features/ai/domain/ai_failures.dart';
import 'package:akshaya/features/pantry/domain/unit.dart';
import 'package:akshaya/features/recipes/domain/recipe_models.dart';
import 'package:akshaya/features/recipes/domain/recipe_validator.dart';
import 'package:flutter_test/flutter_test.dart';

import 'recipe_test_support.dart';

void main() {
  group('RecipeResponseValidator', () {
    test('reads a good answer', () {
      final List<Recipe> recipes =
          RecipeResponseValidator.parse(kGoodRecipesJson);
      expect(recipes.length, 2);
      expect(recipes.first.title, 'Tomato Rice');
      expect(recipes.first.ingredients.first.unit, Unit.kg);
      expect(recipes.first.usesExpiring, <String>['Tomato']);
      expect(recipes.last.diet, RecipeDiet.egg);
    });

    test('accepts code fences', () {
      expect(
        RecipeResponseValidator.parse('```json\n$kGoodRecipesJson\n```').length,
        2,
      );
    });

    test('rejects text that is not the agreed format', () {
      for (final String bad in <String>[
        'sorry',
        '[]',
        '{"recipes":[]}',
        '{"recipes":"x"}',
        '{"recipes":[{"title":"x"}]}',
      ]) {
        expect(
          () => RecipeResponseValidator.parse(bad),
          throwsA(isA<AiInvalidResponseFailure>()),
          reason: bad,
        );
      }
    });

    test('leaves out an invalid recipe but keeps the good ones', () {
      const String text = '''
{"recipes":[
 {"title":"Bad","time_minutes":0,"servings":2,"diet":"veg",
  "ingredients":[{"name":"Rice"}],"steps":["x"]},
 {"title":"Good","time_minutes":10,"servings":2,"diet":"veg",
  "ingredients":[{"name":"Rice","quantity":1,"unit":"cups"}],"steps":["x"]},
 {"title":"Good 2","time_minutes":10,"servings":2,"diet":"veg",
  "ingredients":[{"name":"Rice","quantity":-1,"unit":"kg"}],"steps":["x"]},
 {"title":"Good 3","time_minutes":10,"servings":2,"diet":"vegan",
  "ingredients":[{"name":"Rice"}],"steps":["x"]}
]}''';
      expect(
        () => RecipeResponseValidator.parse(text),
        throwsA(isA<AiInvalidResponseFailure>()),
      );
      final List<Recipe> ok = RecipeResponseValidator.parse(
        text.replaceAll('"cups"', '"kg"'),
      );
      expect(ok.single.title, 'Good');
    });

    test('keeps at most five recipes', () {
      final String one =
          '{"title":"R","time_minutes":10,"servings":2,"diet":"veg",'
          '"ingredients":[{"name":"Rice"}],"steps":["x"]}';
      final String text =
          '{"recipes":[${List<String>.filled(8, one).join(',')}]}';
      expect(
        RecipeResponseValidator.parse(text).length,
        RecipeResponseValidator.maxRecipes,
      );
    });
  });

  group('RecipeSafety', () {
    final List<Recipe> recipes = RecipeResponseValidator.parse(kGoodRecipesJson);

    test('a vegetarian diet drops egg recipes', () {
      expect(
        RecipeSafety.filter(recipes, const RecipePreferences())
            .map((Recipe r) => r.title)
            .toList(),
        <String>['Tomato Rice'],
      );
      expect(
        RecipeSafety.filter(
          recipes,
          const RecipePreferences(diet: RecipeDiet.egg),
        ).length,
        2,
      );
    });

    test('the avoid list is matched widely, singular or plural', () {
      expect(
        RecipeSafety.containsAvoided(recipes.first, <String>['Tomato']),
        isTrue,
      );
      expect(
        RecipeSafety.containsAvoided(recipes.first, <String>['peanuts']),
        isFalse,
      );
      expect(
        RecipeSafety.filter(
          recipes,
          const RecipePreferences(
            diet: RecipeDiet.nonVeg,
            avoid: <String>['egg'],
          ),
        ).map((Recipe r) => r.title).toList(),
        <String>['Tomato Rice'],
      );
    });
  });
}
