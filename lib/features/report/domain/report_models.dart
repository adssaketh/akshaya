import 'nutrition_table.dart';

/// How far back a report looks. The windows are rolling, so they always end
/// today.
enum ReportPeriod {
  today('Today', 1),
  week('7 days', 7),
  month('30 days', 30);

  const ReportPeriod(this.label, this.days);

  final String label;
  final int days;
}

/// The five groups of a simple balanced plate.
enum PlateGroup {
  cereals('Grains'),
  protein('Protein'),
  vegetables('Vegetables'),
  fruits('Fruit'),
  dairy('Dairy');

  const PlateGroup(this.label);

  final String label;
}

/// The plate group a food group counts towards, or null when it does not
/// count towards the balance (roots and tubers such as potato, which
/// ICMR-NIN and WHO both keep apart from vegetables, oils, sugar, spices,
/// snacks).
PlateGroup? plateGroupOf(FoodGroup group) {
  switch (group) {
    case FoodGroup.cereals:
      return PlateGroup.cereals;
    case FoodGroup.pulses:
    case FoodGroup.meatEggs:
      return PlateGroup.protein;
    case FoodGroup.vegetables:
      return PlateGroup.vegetables;
    case FoodGroup.fruits:
      return PlateGroup.fruits;
    case FoodGroup.dairy:
      return PlateGroup.dairy;
    case FoodGroup.tubers:
    case FoodGroup.fats:
    case FoodGroup.sugars:
    case FoodGroup.nutsSeeds:
    case FoodGroup.other:
      return null;
  }
}

enum BalanceVerdict { notEnoughData, balanced, partly, notBalanced }

/// One food in the report, with everything used of it in the window.
final class ConsumedLine {
  const ConsumedLine({
    required this.name,
    required this.quantityLabel,
    required this.kcal,
    required this.estimatedFromGroup,
    this.group = FoodGroup.other,
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
    this.fibre = 0,
  });

  final String name;

  /// The food group, for colouring charts.
  final FoodGroup group;

  /// Grams of protein, carbohydrate, fat and fibre in the amount that was
  /// used (0 when it could not be counted). These come from the quantity
  /// marked as used, not from a per-100-g figure.
  final double protein;
  final double carbs;
  final double fat;
  final double fibre;

  /// "500 g", "6 pcs", "1.5 L".
  final String quantityLabel;

  /// Null when the amount cannot be turned into calories (a packet, say).
  final double? kcal;

  /// True when the number comes from the food group, not from the food.
  final bool estimatedFromGroup;
}

/// Foods from the pantry that would fill a gap.
final class PantrySuggestion {
  const PantrySuggestion({required this.group, required this.items});

  final PlateGroup group;
  final List<String> items;
}

/// One day of a report.
final class DailyPoint {
  const DailyPoint({
    required this.day,
    required this.kcalPerPerson,
    required this.logged,
  });

  final DateTime day;

  /// Estimated energy per person that day (0 when nothing was counted).
  final double kcalPerPerson;

  /// True when anything was marked as used that day.
  final bool logged;
}

/// Average nutrients per person per day on the days something was logged.
final class NutrientAverages {
  const NutrientAverages({
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.fibre,
  });

  final double protein;
  final double carbs;
  final double fat;
  final double fibre;

  /// Share of the energy that comes from carbohydrate, protein and fat
  /// (protein 4 kcal/g, fat 9, carbohydrate 4 with fibre at 2). They add up to
  /// 1. Null when there is nothing to share.
  Map<String, double>? get energyShares {
    final double p = protein * 4;
    final double c = (carbs - fibre).clamp(0, double.infinity) * 4 + fibre * 2;
    final double f = fat * 9;
    final double total = p + c + f;
    if (total <= 0) {
      return null;
    }
    return <String, double>{
      'Carbs': c / total,
      'Protein': p / total,
      'Fat': f / total,
    };
  }
}

/// What was used in a window, what it adds up to, and what could change.
final class ConsumptionReport {
  const ConsumptionReport({
    required this.period,
    required this.people,
    required this.lines,
    required this.loggedDays,
    required this.totalKcal,
    required this.countedLines,
    required this.kcalPerPersonPerDay,
    required this.coverage,
    required this.verdict,
    required this.missing,
    required this.tips,
    required this.suggestions,
    required this.notes,
    required this.vegFruitGramsPerPersonPerDay,
    required this.fatShare,
    this.energyByGroup = const <FoodGroup, double>{},
    this.daily = const <DailyPoint>[],
    this.nutrients,
    this.amountPerPersonPerDay = const <FoodGroup, double>{},
    this.sugarGramsPerPersonPerDay,
    this.totalFatShare,
  });

  final ReportPeriod period;
  final int people;
  final List<ConsumedLine> lines;

  /// Days in the window with at least one use or cooking logged.
  final int loggedDays;

  /// Estimated energy of the foods that could be counted.
  final double totalKcal;

  /// How many lines have a calorie number.
  final int countedLines;

  /// Average per person on the days something was logged. Null when nothing
  /// could be counted.
  final double? kcalPerPersonPerDay;

  /// Share of logged days each plate group appeared on (0 to 1).
  final Map<PlateGroup, double> coverage;
  final BalanceVerdict verdict;
  final List<PlateGroup> missing;
  final List<String> tips;
  final List<PantrySuggestion> suggestions;
  final List<String> notes;

  /// Vegetables and fruit that could be weighed, per person per logged day.
  final double? vegFruitGramsPerPersonPerDay;

  /// Share of the counted calories that came from oil, ghee and butter.
  final double? fatShare;

  /// Estimated energy (kcal) from each food group, counted foods only.
  final Map<FoodGroup, double> energyByGroup;

  /// Every day of the window, oldest first, including days with nothing.
  final List<DailyPoint> daily;

  /// Average protein, carbohydrate, fat and fibre per person per logged day.
  /// Null when nothing could be counted.
  final NutrientAverages? nutrients;

  /// How much of each food group was used, per person per logged day, in
  /// grams (millilitres for milk and curd). Only foods whose amount could be
  /// weighed are counted.
  final Map<FoodGroup, double> amountPerPersonPerDay;

  /// Sugar, jaggery, honey and jam, as grams of sugar per person per day.
  final double? sugarGramsPerPersonPerDay;

  /// Share of the counted calories that comes from fat of every kind.
  final double? totalFatShare;

  bool get isEmpty => lines.isEmpty;

  int get uncountedLines => lines.length - countedLines;
}

/// How a report compares with the window just before it (null where there is
/// nothing to compare).
final class ReportComparison {
  const ReportComparison({
    this.kcalChange,
    this.proteinChange,
    this.fibreChange,
    this.vegFruitChange,
  });

  final double? kcalChange;
  final double? proteinChange;
  final double? fibreChange;
  final double? vegFruitChange;

  bool get isEmpty =>
      kcalChange == null &&
      proteinChange == null &&
      fibreChange == null &&
      vegFruitChange == null;
}

/// [current] minus [previous], per person per day.
ReportComparison compareReports(
  ConsumptionReport current,
  ConsumptionReport previous,
) {
  double? diff(double? a, double? b) => (a == null || b == null) ? null : a - b;
  return ReportComparison(
    kcalChange: diff(current.kcalPerPersonPerDay, previous.kcalPerPersonPerDay),
    proteinChange: diff(
      current.nutrients?.protein,
      previous.nutrients?.protein,
    ),
    fibreChange: diff(current.nutrients?.fibre, previous.nutrients?.fibre),
    vegFruitChange: diff(
      current.vegFruitGramsPerPersonPerDay,
      previous.vegFruitGramsPerPersonPerDay,
    ),
  );
}
