import 'dart:convert';

import '../../ai/domain/ai_response_validator.dart';
import '../../pantry/domain/unit.dart';
import '../../../core/util/quantity.dart';

/// How a recipe (or a person's diet) is classified. [key] is stored and used in
/// the JSON the AI returns, so never rename it.
///
/// The order matters: a preference allows its own kind and every kind before
/// it (non-veg allows everything, vegetarian only vegetarian).
enum RecipeDiet {
  veg('veg', 'Vegetarian'),
  egg('egg', 'Eggetarian'),
  nonVeg('non_veg', 'Non-veg');

  const RecipeDiet(this.key, this.label);

  final String key;
  final String label;

  /// True when someone with this diet preference can eat a [recipe] diet.
  bool allows(RecipeDiet recipe) => recipe.index <= index;

  static RecipeDiet? fromKey(String? text) {
    final String wanted = (text ?? '').trim().toLowerCase();
    for (final RecipeDiet diet in RecipeDiet.values) {
      if (diet.key == wanted) {
        return diet;
      }
    }
    return null;
  }
}

/// The cuisine the person prefers. [key] is stored in settings.
enum RecipeCuisine {
  any('any', 'Any'),
  southIndian('south_indian', 'South Indian'),
  northIndian('north_indian', 'North Indian'),
  andhra('andhra', 'Andhra');

  const RecipeCuisine(this.key, this.label);

  final String key;
  final String label;

  static RecipeCuisine? fromKey(String? text) {
    final String wanted = (text ?? '').trim().toLowerCase();
    for (final RecipeCuisine cuisine in RecipeCuisine.values) {
      if (cuisine.key == wanted) {
        return cuisine;
      }
    }
    return null;
  }
}

/// Keys under which the recipe preferences are stored (Settings table).
abstract final class RecipeSettingKeys {
  static const String diet = 'recipes.diet';
  static const String cuisine = 'recipes.cuisine';
  static const String maxMinutes = 'recipes.max_minutes';
  static const String people = 'recipes.people';
  static const String avoid = 'recipes.avoid';
}

/// One-tap choices for the longest cooking time.
const List<int> kRecipeTimeChoices = <int>[15, 30, 45, 60, 90];
const int kDefaultRecipeMinutes = 45;
const int kDefaultRecipePeople = 2;
const int kMaxRecipePeople = 12;
const int kMaxAvoidEntries = 10;
const int kMaxAvoidLength = 40;

int _clampInt(int value, int low, int high) {
  if (value < low) {
    return low;
  }
  return value > high ? high : value;
}

/// What the person wants to cook. Stored per phone.
final class RecipePreferences {
  const RecipePreferences({
    this.diet = RecipeDiet.veg,
    this.cuisine = RecipeCuisine.any,
    this.maxMinutes = kDefaultRecipeMinutes,
    this.people = kDefaultRecipePeople,
    this.avoid = const <String>[],
  });

  factory RecipePreferences.fromMap(Map<String, String> values) {
    final int minutes =
        int.tryParse(values[RecipeSettingKeys.maxMinutes] ?? '') ??
            kDefaultRecipeMinutes;
    final int people = int.tryParse(values[RecipeSettingKeys.people] ?? '') ??
        kDefaultRecipePeople;
    return RecipePreferences(
      diet: RecipeDiet.fromKey(values[RecipeSettingKeys.diet]) ??
          RecipeDiet.veg,
      cuisine: RecipeCuisine.fromKey(values[RecipeSettingKeys.cuisine]) ??
          RecipeCuisine.any,
      maxMinutes: _clampInt(minutes, 10, 240),
      people: _clampInt(people, 1, kMaxRecipePeople),
      avoid: parseAvoid(values[RecipeSettingKeys.avoid] ?? ''),
    );
  }

  final RecipeDiet diet;
  final RecipeCuisine cuisine;

  /// Longest cooking time wanted, in minutes.
  final int maxMinutes;

  /// How many people are eating.
  final int people;

  /// Ingredients to avoid (allergies, dislikes), one word or phrase each.
  final List<String> avoid;

  /// Splits what the person typed ("peanuts, shellfish") into a clean list:
  /// no empty entries or duplicates, no control characters or brackets, short
  /// entries and at most [kMaxAvoidEntries] of them.
  static List<String> parseAvoid(String text) {
    final List<String> out = <String>[];
    final Set<String> seen = <String>{};
    for (final String part in text.split(RegExp(r'[,;\n]'))) {
      final String cleaned = part
          .replaceAll(RegExp(r'[\u0000-\u001F\u007F{}<>]'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (cleaned.isEmpty) {
        continue;
      }
      final String limited = cleaned.length > kMaxAvoidLength
          ? cleaned.substring(0, kMaxAvoidLength)
          : cleaned;
      if (seen.add(limited.toLowerCase())) {
        out.add(limited);
      }
      if (out.length >= kMaxAvoidEntries) {
        break;
      }
    }
    return out;
  }

  Map<String, String> toMap() {
    return <String, String>{
      RecipeSettingKeys.diet: diet.key,
      RecipeSettingKeys.cuisine: cuisine.key,
      RecipeSettingKeys.maxMinutes: maxMinutes.toString(),
      RecipeSettingKeys.people: people.toString(),
      RecipeSettingKeys.avoid: avoid.join(', '),
    };
  }

  RecipePreferences copyWith({
    RecipeDiet? diet,
    RecipeCuisine? cuisine,
    int? maxMinutes,
    int? people,
    List<String>? avoid,
  }) {
    return RecipePreferences(
      diet: diet ?? this.diet,
      cuisine: cuisine ?? this.cuisine,
      maxMinutes: maxMinutes ?? this.maxMinutes,
      people: people ?? this.people,
      avoid: avoid ?? this.avoid,
    );
  }

  /// One line for the Recipes screen: "Vegetarian · South Indian · 45 min".
  String get summary {
    final List<String> parts = <String>[
      diet.label,
      if (cuisine != RecipeCuisine.any) cuisine.label,
      'up to $maxMinutes min',
      people == 1 ? 'for 1 person' : 'for $people people',
    ];
    return parts.join(' · ');
  }

  @override
  bool operator ==(Object other) {
    if (other is! RecipePreferences) {
      return false;
    }
    if (other.diet != diet ||
        other.cuisine != cuisine ||
        other.maxMinutes != maxMinutes ||
        other.people != people ||
        other.avoid.length != avoid.length) {
      return false;
    }
    for (int i = 0; i < avoid.length; i++) {
      if (other.avoid[i] != avoid[i]) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode =>
      Object.hash(diet, cuisine, maxMinutes, people, Object.hashAll(avoid));
}

/// One ingredient of a recipe, in English.
final class RecipeIngredient {
  const RecipeIngredient({
    required this.name,
    this.quantity,
    this.unit,
    this.itemId,
  });

  final String name;

  /// Null when the recipe gives no amount ("curry leaves").
  final double? quantity;

  /// Null for countable things ("2 tomatoes") and when there is no amount.
  final Unit? unit;

  /// The pantry item this was matched to when the recipe was saved, as a hint.
  /// The match is always worked out again from the live pantry.
  final String? itemId;

  /// "2 kg", "3", or "" when there is no amount.
  String get quantityLabel {
    final double? q = quantity;
    if (q == null) {
      return '';
    }
    final Unit? u = unit;
    return u == null ? formatNumber(q) : u.format(q);
  }

  RecipeIngredient withItemId(String? id) {
    return RecipeIngredient(
      name: name,
      quantity: quantity,
      unit: unit,
      itemId: id,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'name': name,
      if (quantity != null) 'quantity': quantity,
      if (quantity != null && unit != null) 'unit': unit!.symbol,
      if (itemId != null) 'itemId': itemId,
    };
  }

  /// The ingredient in [json], or null when it is not usable.
  static RecipeIngredient? fromJson(Object? json) {
    if (json is! Map<String, Object?>) {
      return null;
    }
    final Object? name = json['name'];
    if (name is! String || name.trim().isEmpty) {
      return null;
    }
    final Object? q = json['quantity'];
    final double? quantity =
        (q is num && q.isFinite && q > 0) ? q.toDouble() : null;
    final Object? u = json['unit'];
    final Unit? unit = (quantity != null && u is String)
        ? AiResponseValidator.parseUnit(u)
        : null;
    final Object? id = json['itemId'];
    return RecipeIngredient(
      name: name.trim(),
      quantity: quantity,
      unit: unit,
      itemId: (id is String && id.isNotEmpty) ? id : null,
    );
  }
}

/// A recipe, as the AI suggested it or as it was saved. Always English.
final class Recipe {
  const Recipe({
    required this.title,
    required this.timeMinutes,
    required this.servings,
    required this.diet,
    required this.ingredients,
    required this.steps,
    this.cuisine,
    this.usesExpiring = const <String>[],
  });

  final String title;
  final int timeMinutes;
  final int servings;
  final RecipeDiet diet;
  final String? cuisine;
  final List<RecipeIngredient> ingredients;
  final List<String> steps;

  /// Names of the expiring items the AI says this recipe uses. Only a hint:
  /// the app counts them again itself from the real pantry.
  final List<String> usesExpiring;

  bool get isVeg => diet == RecipeDiet.veg;

  /// Two suggestions with the same key are the same recipe, so saving one
  /// twice keeps one copy.
  String get contentKey {
    final String name = title.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    final List<String> parts = <String>[
      for (final RecipeIngredient i in ingredients) i.name.toLowerCase().trim(),
    ];
    parts.sort();
    return '${name.trim()}|${parts.join(',')}';
  }

  Recipe copyWith({List<RecipeIngredient>? ingredients}) {
    return Recipe(
      title: title,
      timeMinutes: timeMinutes,
      servings: servings,
      diet: diet,
      cuisine: cuisine,
      ingredients: ingredients ?? this.ingredients,
      steps: steps,
      usesExpiring: usesExpiring,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'title': title,
      'timeMinutes': timeMinutes,
      'servings': servings,
      'diet': diet.key,
      if (cuisine != null) 'cuisine': cuisine,
      'ingredients': <Object?>[
        for (final RecipeIngredient i in ingredients) i.toJson(),
      ],
      'steps': steps,
      'usesExpiring': usesExpiring,
    };
  }

  /// The recipe in [json], or null when it is not usable (older or damaged
  /// data is skipped, never a crash).
  static Recipe? fromJson(Object? json) {
    if (json is! Map<String, Object?>) {
      return null;
    }
    final Object? title = json['title'];
    final Object? time = json['timeMinutes'];
    final Object? servings = json['servings'];
    final Object? dietRaw = json['diet'];
    final RecipeDiet? diet =
        dietRaw is String ? RecipeDiet.fromKey(dietRaw) : null;
    final Object? rawIngredients = json['ingredients'];
    final Object? rawSteps = json['steps'];
    if (title is! String ||
        title.trim().isEmpty ||
        time is! num ||
        servings is! num ||
        diet == null ||
        rawIngredients is! List<Object?> ||
        rawSteps is! List<Object?>) {
      return null;
    }
    final List<RecipeIngredient> ingredients = <RecipeIngredient>[];
    for (final Object? raw in rawIngredients) {
      final RecipeIngredient? ingredient = RecipeIngredient.fromJson(raw);
      if (ingredient != null) {
        ingredients.add(ingredient);
      }
    }
    final List<String> steps = <String>[
      for (final Object? raw in rawSteps)
        if (raw is String && raw.trim().isNotEmpty) raw.trim(),
    ];
    if (ingredients.isEmpty || steps.isEmpty) {
      return null;
    }
    final Object? cuisine = json['cuisine'];
    final Object? uses = json['usesExpiring'];
    return Recipe(
      title: title.trim(),
      timeMinutes: time.round(),
      servings: servings.round(),
      diet: diet,
      cuisine:
          (cuisine is String && cuisine.trim().isNotEmpty) ? cuisine.trim() : null,
      ingredients: ingredients,
      steps: steps,
      usesExpiring: <String>[
        if (uses is List<Object?>)
          for (final Object? u in uses)
            if (u is String && u.trim().isNotEmpty) u.trim(),
      ],
    );
  }

  static String encodeIngredients(List<RecipeIngredient> ingredients) {
    return jsonEncode(<Object?>[
      for (final RecipeIngredient i in ingredients) i.toJson(),
    ]);
  }

  static List<RecipeIngredient> decodeIngredients(String text) {
    final Object? decoded = _tryDecode(text);
    if (decoded is! List<Object?>) {
      return const <RecipeIngredient>[];
    }
    return <RecipeIngredient>[
      for (final Object? raw in decoded)
        if (RecipeIngredient.fromJson(raw) case final RecipeIngredient i) i,
    ];
  }

  static String encodeSteps(List<String> steps) => jsonEncode(steps);

  static List<String> decodeSteps(String text) {
    final Object? decoded = _tryDecode(text);
    if (decoded is! List<Object?>) {
      return const <String>[];
    }
    return <String>[
      for (final Object? raw in decoded)
        if (raw is String && raw.trim().isNotEmpty) raw.trim(),
    ];
  }

  static Object? _tryDecode(String text) {
    try {
      return jsonDecode(text);
    } on FormatException {
      return null;
    }
  }
}

/// A recipe the person kept.
final class SavedRecipe {
  const SavedRecipe({
    required this.id,
    required this.recipe,
    required this.savedAt,
  });

  final String id;
  final Recipe recipe;
  final DateTime savedAt;
}

/// The last set of ideas the AI gave, kept so they can be read offline and so
/// the same pantry does not ask again.
final class RecipeCacheEntry {
  const RecipeCacheEntry({
    required this.fingerprint,
    required this.recipes,
    required this.generatedAt,
  });

  /// Identifies the pantry and preferences the ideas were made for (see
  /// `RecipeFingerprint`).
  final String fingerprint;
  final List<Recipe> recipes;
  final DateTime generatedAt;

  static String encodeRecipes(List<Recipe> recipes) {
    return jsonEncode(<Object?>[for (final Recipe r in recipes) r.toJson()]);
  }

  /// The recipes in [text]; damaged entries are left out.
  static List<Recipe> decodeRecipes(String text) {
    final Object? decoded = Recipe._tryDecode(text);
    if (decoded is! List<Object?>) {
      return const <Recipe>[];
    }
    return <Recipe>[
      for (final Object? raw in decoded)
        if (Recipe.fromJson(raw) case final Recipe r) r,
    ];
  }
}
