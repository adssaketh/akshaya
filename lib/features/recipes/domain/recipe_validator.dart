import 'dart:convert';

import '../../ai/domain/ai_failures.dart';
import '../../ai/domain/ai_response_validator.dart';
import '../../pantry/domain/unit.dart';
import 'recipe_models.dart';

/// Checks the JSON the AI returns for recipe ideas:
///
/// `{"recipes":[{"title","time_minutes","servings","diet","cuisine",
/// "ingredients":[{"name","quantity","unit","status"}],"steps",
/// "uses_expiring"}]}`
///
/// The answer must be a JSON object with a list of recipes. A recipe that does
/// not fit the format is left out; when none fits, the whole answer is
/// rejected. The ingredient `status` is ignored: the app works out for itself
/// what the pantry has.
abstract final class RecipeResponseValidator {
  static const int maxRecipes = 5;
  static const int maxIngredients = 40;
  static const int maxSteps = 30;
  static const int maxTitleLength = 120;
  static const int maxNameLength = 80;
  static const int maxStepLength = 800;
  static const int maxMinutes = 600;
  static const int maxServings = 50;
  static const int maxCuisineLength = 40;
  static const int maxUsesExpiring = 10;
  static const double maxQuantity = 100000;

  static final RegExp _controlChars = RegExp(r'[\u0000-\u001F\u007F]');

  /// The recipes in [text], at most [maxRecipes], or throws
  /// [AiInvalidResponseFailure].
  static List<Recipe> parse(String text) {
    final Object? decoded;
    try {
      decoded = jsonDecode(_stripFences(text));
    } on FormatException {
      throw const AiInvalidResponseFailure('not JSON');
    }
    if (decoded is! Map<String, Object?>) {
      throw const AiInvalidResponseFailure('not an object');
    }
    final Object? raw = decoded['recipes'];
    if (raw is! List<Object?> || raw.isEmpty) {
      throw const AiInvalidResponseFailure('no recipes list');
    }
    final List<Recipe> out = <Recipe>[];
    for (final Object? item in raw) {
      final Recipe? recipe = _recipe(item);
      if (recipe != null) {
        out.add(recipe);
      }
      if (out.length >= maxRecipes) {
        break;
      }
    }
    if (out.isEmpty) {
      throw const AiInvalidResponseFailure('no valid recipe');
    }
    return out;
  }

  /// One recipe object in the AI's recipe format, or null when it does not fit
  /// (the meal planner reads recipes from its own answer with this).
  static Recipe? parseRecipe(Object? raw) => _recipe(raw);

  static Recipe? _recipe(Object? raw) {
    if (raw is! Map<String, Object?>) {
      return null;
    }
    final String? title = _text(raw['title'], maxTitleLength);
    final int? time = _wholeNumber(raw['time_minutes'], maxMinutes);
    final int? servings = _wholeNumber(raw['servings'], maxServings);
    final Object? dietRaw = raw['diet'];
    final RecipeDiet? diet =
        dietRaw is String ? RecipeDiet.fromKey(dietRaw) : null;
    final Object? rawIngredients = raw['ingredients'];
    final Object? rawSteps = raw['steps'];
    if (title == null ||
        time == null ||
        servings == null ||
        diet == null ||
        rawIngredients is! List<Object?> ||
        rawIngredients.isEmpty ||
        rawIngredients.length > maxIngredients ||
        rawSteps is! List<Object?> ||
        rawSteps.isEmpty ||
        rawSteps.length > maxSteps) {
      return null;
    }

    final List<RecipeIngredient> ingredients = <RecipeIngredient>[];
    for (final Object? item in rawIngredients) {
      final RecipeIngredient? ingredient = _ingredient(item);
      if (ingredient == null) {
        return null;
      }
      ingredients.add(ingredient);
    }

    final List<String> steps = <String>[];
    for (final Object? item in rawSteps) {
      final String? step = _text(item, maxStepLength);
      if (step == null) {
        return null;
      }
      steps.add(step);
    }

    final Object? cuisineRaw = raw['cuisine'];
    final String? cuisine =
        cuisineRaw == null ? null : _text(cuisineRaw, maxCuisineLength);

    final List<String> uses = <String>[];
    final Object? usesRaw = raw['uses_expiring'];
    if (usesRaw is List<Object?>) {
      for (final Object? item in usesRaw) {
        final String? name = _text(item, maxNameLength);
        if (name != null && uses.length < maxUsesExpiring) {
          uses.add(name);
        }
      }
    }

    return Recipe(
      title: title,
      timeMinutes: time,
      servings: servings,
      diet: diet,
      cuisine: cuisine,
      ingredients: ingredients,
      steps: steps,
      usesExpiring: uses,
    );
  }

  static RecipeIngredient? _ingredient(Object? raw) {
    if (raw is! Map<String, Object?>) {
      return null;
    }
    final String? name = _text(raw['name'], maxNameLength);
    if (name == null) {
      return null;
    }
    double? quantity;
    final Object? quantityRaw = raw['quantity'];
    if (quantityRaw != null) {
      if (quantityRaw is! num ||
          !quantityRaw.isFinite ||
          quantityRaw <= 0 ||
          quantityRaw > maxQuantity) {
        return null;
      }
      quantity = quantityRaw.toDouble();
    }
    Unit? unit;
    final Object? unitRaw = raw['unit'];
    if (unitRaw != null) {
      if (unitRaw is! String) {
        return null;
      }
      if (unitRaw.trim().isNotEmpty) {
        unit = AiResponseValidator.parseUnit(unitRaw);
        if (unit == null) {
          return null;
        }
      }
    }
    return RecipeIngredient(
      name: name,
      quantity: quantity,
      unit: quantity == null ? null : unit,
    );
  }

  /// Plain text of 1 to [maxLength] characters, or null.
  static String? _text(Object? raw, int maxLength) {
    if (raw is! String) {
      return null;
    }
    final String text = raw
        .replaceAll(_controlChars, ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (text.isEmpty || text.length > maxLength) {
      return null;
    }
    return text;
  }

  static int? _wholeNumber(Object? raw, int max) {
    if (raw is! num || !raw.isFinite) {
      return null;
    }
    final int value = raw.round();
    if (value < 1 || value > max) {
      return null;
    }
    return value;
  }

  static String _stripFences(String text) {
    String t = text.trim();
    if (t.startsWith('```')) {
      final int firstNewline = t.indexOf('\n');
      if (firstNewline != -1) {
        t = t.substring(firstNewline + 1);
      }
      if (t.endsWith('```')) {
        t = t.substring(0, t.length - 3);
      }
    }
    return t.trim();
  }
}

/// Checks recipes against what the person asked for. The AI is told the diet
/// and the avoid list, but it can slip; these checks are the ones that count.
abstract final class RecipeSafety {
  /// The recipes that suit [prefs].
  static List<Recipe> filter(List<Recipe> recipes, RecipePreferences prefs) {
    return <Recipe>[
      for (final Recipe r in recipes)
        if (isAllowed(r, prefs)) r,
    ];
  }

  static bool isAllowed(Recipe recipe, RecipePreferences prefs) {
    return prefs.diet.allows(recipe.diet) &&
        !containsAvoided(recipe, prefs.avoid);
  }

  /// True when the title or any ingredient contains one of the [avoid] words.
  /// The match is deliberately wide ("nut" also catches "coconut"): for an
  /// allergy it is better to leave a recipe out than to include it.
  static bool containsAvoided(Recipe recipe, List<String> avoid) {
    final List<String> terms = <String>[];
    for (final String word in avoid) {
      final String term = word.trim().toLowerCase();
      if (term.isEmpty) {
        continue;
      }
      terms.add(
        term.length > 3 && term.endsWith('s')
            ? term.substring(0, term.length - 1)
            : term,
      );
    }
    if (terms.isEmpty) {
      return false;
    }
    final List<String> haystacks = <String>[
      recipe.title.toLowerCase(),
      for (final RecipeIngredient i in recipe.ingredients) i.name.toLowerCase(),
    ];
    for (final String term in terms) {
      for (final String text in haystacks) {
        if (text.contains(term)) {
          return true;
        }
      }
    }
    return false;
  }
}
