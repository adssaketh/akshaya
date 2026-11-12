import '../../pantry/domain/entities.dart';
import '../../pantry/domain/stock_logic.dart';
import '../../takeaway/domain/food_estimate.dart';
import '../../takeaway/domain/takeaway_models.dart';
import 'meal_ideas.dart';
import 'report_builder.dart';
import 'report_models.dart';

/// Everything the Food report page shows, worked out offline in one go.
final class ReportBundle {
  const ReportBundle({
    required this.report,
    required this.previous,
    required this.comparison,
    required this.streak,
    required this.ideas,
  });

  final ConsumptionReport report;

  /// The window just before [report], the same length.
  final ConsumptionReport previous;
  final ReportComparison comparison;

  /// Days in a row with something marked as used.
  final int streak;
  final List<MealIdea> ideas;

  /// Names of in-stock foods that would fill a gap, for the AI review.
  List<String> get pantryHints => <String>[
    for (final PantrySuggestion s in report.suggestions) ...s.items,
  ];
}

ReportBundle buildReportBundle({
  required ReportPeriod period,
  required DateTime today,
  required List<ConsumptionEntry> history,
  required Map<String, Item> itemsById,
  required int people,
  required bool vegetarian,
  required List<ItemStock> stocks,
  List<TakeawayMeal> takeaways = const <TakeawayMeal>[],
  Map<String, FoodEstimate> estimates = const <String, FoodEstimate>{},
}) {
  final ConsumptionReport report = buildConsumptionReport(
    period: period,
    today: today,
    history: history,
    itemsById: itemsById,
    people: people,
    vegetarian: vegetarian,
    stocks: stocks,
    takeaways: takeaways,
    estimates: estimates,
  );
  final ConsumptionReport previous = buildConsumptionReport(
    period: period,
    today: DateTime(today.year, today.month, today.day - period.days),
    history: history,
    itemsById: itemsById,
    people: people,
    vegetarian: vegetarian,
    takeaways: takeaways,
    estimates: estimates,
  );
  return ReportBundle(
    report: report,
    previous: previous,
    comparison: previous.isEmpty
        ? const ReportComparison()
        : compareReports(report, previous),
    // Only food that is still in the app counts, the same as in the report
    // itself, so removing a wrongly added item also removes its day.
    streak: loggingStreak(<ConsumptionEntry>[
      for (final ConsumptionEntry e in history)
        if (itemsById.containsKey(e.itemId)) e,
    ], today),
    ideas: suggestMealIdeas(
      stocks: stocks,
      missing: report.missing,
      vegetarian: vegetarian,
    ),
  );
}
