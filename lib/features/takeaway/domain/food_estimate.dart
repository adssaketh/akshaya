import 'dart:convert';

import '../../ai/domain/ai_failures.dart';
import '../../pantry/domain/unit.dart';
import '../../report/domain/nutrition_table.dart';

/// One ingredient Gemini found in a dish, with a rough weight in grams for one
/// serving (null when it gave none).
final class EstimateIngredient {
  const EstimateIngredient({required this.name, this.grams});

  final String name;
  final double? grams;
}

/// Gemini's estimate for ONE serving of a food or dish: the main ingredients
/// first, then the nutrition worked out from them.
///
/// It is a rough guess, never a measurement, so every screen calls it an
/// estimate. The same estimate is reused for the same dish name, so each dish
/// is asked about once.
final class FoodEstimate {
  const FoodEstimate({
    required this.group,
    required this.servingGrams,
    required this.kcal,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.fibre,
    required this.ingredients,
    this.gramsPerPiece,
    this.isFood = true,
  });

  /// What Gemini said is not food (soap, a battery). Nothing is counted, and
  /// the answer is remembered so the question is not asked again.
  const FoodEstimate.notFood()
    : group = FoodGroup.other,
      servingGrams = 0,
      kcal = 0,
      protein = 0,
      carbs = 0,
      fat = 0,
      fibre = 0,
      ingredients = const <EstimateIngredient>[],
      gramsPerPiece = null,
      isFood = false;

  final bool isFood;
  final FoodGroup group;

  /// Weight of one serving, in grams.
  final double servingGrams;

  /// Energy and nutrients of one serving (grams for the nutrients).
  final double kcal;
  final double protein;
  final double carbs;
  final double fat;
  final double fibre;

  /// Weight of one piece (one dosa, one apple), when the food comes in pieces.
  final double? gramsPerPiece;
  final List<EstimateIngredient> ingredients;

  /// The ingredients as one line: "Rice 80 g, urad dal 20 g, oil 5 g".
  String get ingredientsLabel {
    return <String>[
      for (final EstimateIngredient i in ingredients)
        i.grams == null || i.grams! <= 0
            ? i.name
            : '${i.name} ${i.grams!.round()} g',
    ].join(', ');
  }

  /// The same food as a table entry (per 100 g), so the report's existing
  /// maths can use it.
  FoodEnergy toFoodEnergy() {
    final double per = servingGrams <= 0 ? 0 : 100 / servingGrams;
    return FoodEnergy(
      const <String>[],
      group,
      kcalPer100g: kcal * per,
      protein: protein * per,
      carbs: carbs * per,
      fat: fat * per,
      fibre: fibre * per,
      gramsPerPiece: gramsPerPiece,
    );
  }

  /// The energy and nutrients of [portions] servings.
  EnergyEstimate forPortions(double portions) {
    final double weight = servingGrams * portions;
    return EnergyEstimate(
      kcal: kcal * portions,
      grams: weight,
      amount: weight,
      protein: protein * portions,
      carbs: carbs * portions,
      fat: fat * portions,
      fibre: fibre * portions,
    );
  }

  /// The energy and nutrients of [quantity] [unit] of this food, or null when
  /// the amount cannot be turned into a weight (a packet, say).
  EnergyEstimate? forAmount(double quantity, Unit unit) {
    if (!isFood || quantity <= 0 || servingGrams <= 0) {
      return null;
    }
    if (unit.family == UnitFamily.portion) {
      return forPortions(quantity);
    }
    return estimateEnergy(toFoodEnergy(), quantity, unit);
  }

  Map<String, Object?> toJson() {
    if (!isFood) {
      return <String, Object?>{'v': 1, 'food': false};
    }
    return <String, Object?>{
      'v': 1,
      'food': true,
      'group': group.name,
      'serving_g': servingGrams,
      'kcal': kcal,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'fibre': fibre,
      if (gramsPerPiece != null) 'piece_g': gramsPerPiece,
      'ingredients': <Map<String, Object?>>[
        for (final EstimateIngredient i in ingredients)
          <String, Object?>{'n': i.name, if (i.grams != null) 'g': i.grams},
      ],
    };
  }

  String encode() => jsonEncode(toJson());

  /// Reads what [encode] wrote. Null for anything damaged, so a bad saved
  /// value is ignored and never shown half-broken.
  static FoodEstimate? decode(String? text) {
    if (text == null || text.isEmpty) {
      return null;
    }
    try {
      final Object? data = jsonDecode(text);
      if (data is! Map<String, dynamic>) {
        return null;
      }
      if (data['food'] == false) {
        return const FoodEstimate.notFood();
      }
      return _fromMap(data, internal: true);
    } on Object {
      return null;
    }
  }

  /// Reads Gemini's answer (snake_case keys, see the backend schema). Throws
  /// an [AiInvalidResponseFailure] when it is not usable.
  static FoodEstimate parseGemini(String raw) {
    final Object? data;
    try {
      data = jsonDecode(_stripFences(raw));
    } on Object {
      throw const AiInvalidResponseFailure('estimate is not JSON');
    }
    if (data is! Map<String, dynamic>) {
      throw const AiInvalidResponseFailure('estimate is not an object');
    }
    if (data['is_food'] == false) {
      return const FoodEstimate.notFood();
    }
    final FoodEstimate? parsed = _fromMap(data, internal: false);
    if (parsed == null) {
      throw const AiInvalidResponseFailure('estimate failed the checks');
    }
    return parsed;
  }

  static String _stripFences(String raw) {
    return raw.replaceAll(RegExp(r'```(?:json)?'), '').trim();
  }

  static double? _num(Object? value) {
    if (value is num && value.isFinite) {
      return value.toDouble();
    }
    return null;
  }

  static FoodGroup _group(Object? value) {
    for (final FoodGroup g in FoodGroup.values) {
      if (g.name == value) {
        return g;
      }
    }
    return FoodGroup.other;
  }

  /// Largest sensible serving and energy, so a slip of the decimal point is
  /// refused instead of counted.
  static const double maxServingGrams = 1500;
  static const double maxServingKcal = 2500;

  static FoodEstimate? _fromMap(
    Map<String, dynamic> data, {
    required bool internal,
  }) {
    final double? serving = _num(
      internal ? data['serving_g'] : data['serving_grams'],
    );
    final double? kcal = _num(data['kcal']);
    final double? protein = _num(
      internal ? data['protein'] : data['protein_g'],
    );
    final double? carbs = _num(internal ? data['carbs'] : data['carbs_g']);
    final double? fat = _num(internal ? data['fat'] : data['fat_g']);
    final double? fibre = _num(internal ? data['fibre'] : data['fibre_g']);
    if (serving == null ||
        kcal == null ||
        protein == null ||
        carbs == null ||
        fat == null ||
        fibre == null) {
      return null;
    }
    if (serving < 10 || serving > maxServingGrams) {
      return null;
    }
    if (kcal < 0 || kcal > maxServingKcal) {
      return null;
    }
    if (protein < 0 || carbs < 0 || fat < 0 || fibre < 0) {
      return null;
    }
    if (protein + carbs + fat > serving * 1.05) {
      // More nutrient than food.
      return null;
    }
    // The calories should roughly agree with protein, carbohydrate and fat
    // (4, 4 and 9 kcal per gram): the same kind of check the built-in table
    // gets in its tests.
    final double fromMacros = protein * 4 + carbs * 4 + fat * 9;
    if (kcal >= 30 || fromMacros >= 30) {
      final double ratio = fromMacros <= 0 ? 0 : kcal / fromMacros;
      if (ratio < 0.6 || ratio > 1.6) {
        return null;
      }
    }
    final List<EstimateIngredient> ingredients = <EstimateIngredient>[];
    final Object? list = data['ingredients'];
    if (list is List<dynamic>) {
      for (final Object? entry in list.take(15)) {
        if (entry is! Map<String, dynamic>) {
          continue;
        }
        final Object? name = internal ? entry['n'] : entry['name'];
        if (name is! String) {
          continue;
        }
        final String clean = cleanText(name);
        if (clean.isEmpty) {
          continue;
        }
        final double? grams = _num(internal ? entry['g'] : entry['grams']);
        ingredients.add(
          EstimateIngredient(
            name: clean,
            grams: grams != null && grams > 0 && grams <= maxServingGrams
                ? grams
                : null,
          ),
        );
      }
    }
    final double? piece = _num(
      internal ? data['piece_g'] : data['grams_per_piece'],
    );
    return FoodEstimate(
      group: _group(data['group']),
      servingGrams: serving,
      kcal: kcal,
      protein: protein,
      carbs: carbs,
      fat: fat,
      fibre: fibre,
      ingredients: ingredients,
      gramsPerPiece: piece != null && piece >= 5 && piece <= 1000
          ? piece
          : null,
    );
  }

  /// One line of plain text from Gemini or from a person: no control
  /// characters, no markup, limited length.
  static String cleanText(String text) {
    final String oneLine = text
        .replaceAll(RegExp(r'[\u0000-\u001F\u007F]+'), ' ')
        .replaceAll(RegExp(r'[<>{}`*#]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return oneLine.length > 60 ? oneLine.substring(0, 60).trimRight() : oneLine;
  }
}

/// The key a dish is remembered under: lower case letters and digits only, so
/// "Masala  Dosa" and "masala dosa" share one estimate.
String estimateKey(String name) {
  final String key = name
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim();
  return key.length > 60 ? key.substring(0, 60).trimRight() : key;
}

/// Settings key under which the estimate for [name] is saved on this phone.
const String kEstimateKeyPrefix = 'food_estimate.';

String estimateSettingKey(String name) =>
    '$kEstimateKeyPrefix${estimateKey(name)}';
