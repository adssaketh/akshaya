import 'food_estimate.dart';

/// Which meal a takeaway was eaten as. The enum [name] is what is stored and
/// synced.
enum MealSlot {
  breakfast('Breakfast'),
  lunch('Lunch'),
  dinner('Dinner'),
  snack('Snack');

  const MealSlot(this.label);

  final String label;

  /// The slot stored as text, [snack] for null or anything unknown.
  static MealSlot fromName(String? text) {
    for (final MealSlot slot in MealSlot.values) {
      if (slot.name == text) {
        return slot;
      }
    }
    return MealSlot.snack;
  }

  /// A sensible first choice for the time of day.
  static MealSlot forTime(DateTime now) {
    final int h = now.hour;
    if (h < 11) {
      return MealSlot.breakfast;
    }
    if (h < 16) {
      return MealSlot.lunch;
    }
    if (h < 18) {
      return MealSlot.snack;
    }
    return MealSlot.dinner;
  }
}

/// Food that was eaten from outside (ordered in, bought from a stall or a
/// restaurant) rather than cooked from pantry stock. It counts in the eating
/// report like anything used from the pantry.
final class TakeawayMeal {
  const TakeawayMeal({
    required this.id,
    required this.name,
    required this.meal,
    required this.portions,
    required this.eatenOn,
    this.price,
    this.estimate,
  });

  final String id;

  /// What it was ("Masala dosa").
  final String name;
  final MealSlot meal;

  /// How many servings, such as 1, 2 or 0.5.
  final double portions;

  /// The calendar day it was eaten.
  final DateTime eatenOn;

  /// Total paid, in rupees; null when not recorded.
  final double? price;

  /// Gemini's estimate for one serving; null until it has been worked out.
  final FoodEstimate? estimate;

  /// "1 portion", "2 portions", "1.5 portions".
  String get portionsLabel => formatPortions(portions);

  TakeawayMeal copyWith({
    String? name,
    MealSlot? meal,
    double? portions,
    DateTime? eatenOn,
    double? price,
    bool clearPrice = false,
    FoodEstimate? estimate,
    bool clearEstimate = false,
  }) {
    return TakeawayMeal(
      id: id,
      name: name ?? this.name,
      meal: meal ?? this.meal,
      portions: portions ?? this.portions,
      eatenOn: eatenOn ?? this.eatenOn,
      price: clearPrice ? null : (price ?? this.price),
      estimate: estimate ?? (clearEstimate ? null : this.estimate),
    );
  }
}

/// What the person types when adding a takeaway.
final class TakeawayDraft {
  const TakeawayDraft({
    required this.name,
    required this.meal,
    required this.portions,
    required this.eatenOn,
    this.price,
    this.estimate,
  });

  final String name;
  final MealSlot meal;
  final double portions;
  final DateTime eatenOn;
  final double? price;

  /// An estimate already known for this dish (reused, so it is not asked
  /// again).
  final FoodEstimate? estimate;
}

/// "1 portion", "2 portions", "0.5 portion", "1.5 portions".
String formatPortions(double portions) {
  final bool whole = portions == portions.roundToDouble();
  final String number = whole
      ? portions.round().toString()
      : portions.toStringAsFixed(1);
  return '$number ${portions == 1 ? 'portion' : 'portions'}';
}

/// Longest dish name kept.
const int kTakeawayNameMax = 80;

/// Most portions one entry can hold.
const double kTakeawayMaxPortions = 20;

/// Why a draft cannot be saved, in plain words, or null when it is fine.
String? validateTakeaway({
  required String name,
  required double portions,
  required double? price,
}) {
  final String trimmed = name.trim();
  if (trimmed.isEmpty) {
    return 'Enter what you ate.';
  }
  if (trimmed.length > kTakeawayNameMax) {
    return 'Keep the name under $kTakeawayNameMax letters.';
  }
  if (!portions.isFinite || portions <= 0 || portions > kTakeawayMaxPortions) {
    return 'Portions must be between 0.5 and '
        '${kTakeawayMaxPortions.round()}.';
  }
  if (price != null && (!price.isFinite || price < 0 || price > 1000000)) {
    return 'Enter a price that makes sense, or leave it empty.';
  }
  return null;
}
