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
/// count towards the balance (oils, sugar, spices, snacks).
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
  });

  final String name;

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

  bool get isEmpty => lines.isEmpty;

  int get uncountedLines => lines.length - countedLines;
}
