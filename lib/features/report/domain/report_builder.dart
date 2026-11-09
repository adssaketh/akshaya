import '../../../core/design/tokens/status_kind.dart';
import '../../pantry/domain/consumption_type.dart';
import '../../pantry/domain/entities.dart';
import '../../pantry/domain/stock_logic.dart';
import '../../pantry/domain/unit.dart';
import 'nutrition_table.dart';
import 'report_models.dart';

/// Vegetables and fruit a day, per person (WHO: at least 400 g).
const double kVegFruitGoalGrams = 400;

/// Above this share of calories from oil, ghee and butter the report says so
/// (WHO: under 30% of energy from all fat).
const double kFatShareLimit = 0.30;

/// The food group of an item: from its name when the table knows it, else
/// from its category.
FoodGroup groupOfItem(Item item) {
  return findFoodEnergy(item.name, item.aliases)?.group ??
      groupForCategory(item.categoryId);
}

final class _Line {
  _Line(this.name, this.unit);

  final String name;
  final Unit unit;
  double base = 0;
  double kcal = 0;
  bool hasKcal = false;
  bool fromGroup = false;
}

String _dayKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

String _label(Unit unit, double base) {
  if (unit == Unit.g && base >= 1000) {
    return Unit.kg.format(base / 1000);
  }
  if (unit == Unit.ml && base >= 1000) {
    return Unit.l.format(base / 1000);
  }
  return unit.format(base);
}

/// Adds up what left the pantry as food (used, or cooked in a recipe) in the
/// window, estimates its energy, checks the plate balance and suggests small
/// changes. Waste, expiry, giveaways and count corrections are not food that
/// was eaten, so they are left out.
///
/// This is a rough guide built from what was marked as used. It cannot see
/// what each person ate, meals eaten out, or food that was never logged.
ConsumptionReport buildConsumptionReport({
  required ReportPeriod period,
  required DateTime today,
  required List<ConsumptionEntry> history,
  required Map<String, Item> itemsById,
  required int people,
  bool vegetarian = false,
  List<ItemStock> stocks = const <ItemStock>[],
}) {
  final DateTime start =
      DateTime(today.year, today.month, today.day - (period.days - 1));
  final DateTime end = DateTime(today.year, today.month, today.day + 1);
  final int headcount = people < 1 ? 1 : people;

  final Map<String, _Line> byLine = <String, _Line>{};
  final Map<String, Set<PlateGroup>> plateByDay = <String, Set<PlateGroup>>{};
  double totalKcal = 0;
  double fatKcal = 0;
  double vegFruitGrams = 0;

  for (final ConsumptionEntry entry in history) {
    if (entry.type != ConsumptionType.used &&
        entry.type != ConsumptionType.cookedInRecipe) {
      continue;
    }
    if (entry.quantityUsed <= 0 ||
        entry.date.isBefore(start) ||
        !entry.date.isBefore(end)) {
      continue;
    }
    final Item? item = itemsById[entry.itemId];
    if (item == null) {
      continue;
    }
    final String day = _dayKey(entry.date);
    final Set<PlateGroup> plate =
        plateByDay.putIfAbsent(day, () => <PlateGroup>{});

    final FoodEnergy? food = findFoodEnergy(item.name, item.aliases);
    final FoodGroup group = food?.group ?? groupForCategory(item.categoryId);
    final PlateGroup? plateGroup = plateGroupOf(group);
    if (plateGroup != null) {
      plate.add(plateGroup);
    }

    EnergyEstimate? estimate;
    bool fromGroup = false;
    if (food != null) {
      estimate = estimateEnergy(food, entry.quantityUsed, entry.unit);
    } else {
      final FoodEnergy? fallback = kCategoryEnergyFallback[item.categoryId];
      if (fallback != null) {
        estimate = estimateEnergy(fallback, entry.quantityUsed, entry.unit);
        fromGroup = estimate != null;
      }
    }

    final Unit displayUnit;
    final double base;
    switch (entry.unit.family) {
      case UnitFamily.mass:
        displayUnit = Unit.g;
        base = entry.quantityUsed * entry.unit.baseFactor;
      case UnitFamily.volume:
        displayUnit = Unit.ml;
        base = entry.quantityUsed * entry.unit.baseFactor;
      case UnitFamily.dozen:
        displayUnit = Unit.pcs;
        base = entry.quantityUsed * 12;
      case UnitFamily.pieces:
      case UnitFamily.packet:
      case UnitFamily.bunch:
      case UnitFamily.portion:
        displayUnit = entry.unit;
        base = entry.quantityUsed;
    }
    final _Line line = byLine.putIfAbsent(
      '${entry.itemId}|${displayUnit.name}',
      () => _Line(item.name, displayUnit),
    );
    line.base += base;
    if (estimate != null) {
      line.kcal += estimate.kcal;
      line.hasKcal = true;
      line.fromGroup = line.fromGroup || fromGroup;
      totalKcal += estimate.kcal;
      if (group == FoodGroup.fats) {
        fatKcal += estimate.kcal;
      }
      if ((group == FoodGroup.vegetables || group == FoodGroup.fruits) &&
          estimate.grams != null) {
        vegFruitGrams += estimate.grams!;
      }
    }
  }

  final List<ConsumedLine> lines = <ConsumedLine>[
    for (final _Line l in byLine.values)
      ConsumedLine(
        name: l.name,
        quantityLabel: _label(l.unit, l.base),
        kcal: l.hasKcal ? l.kcal : null,
        estimatedFromGroup: l.fromGroup,
      ),
  ]..sort((ConsumedLine a, ConsumedLine b) {
      final int byKnown = (a.kcal == null ? 1 : 0) - (b.kcal == null ? 1 : 0);
      if (byKnown != 0) {
        return byKnown;
      }
      final int byKcal = (b.kcal ?? 0).compareTo(a.kcal ?? 0);
      return byKcal != 0 ? byKcal : a.name.compareTo(b.name);
    });
  final int counted = lines.where((ConsumedLine l) => l.kcal != null).length;

  final int loggedDays = plateByDay.length;
  final Map<PlateGroup, double> coverage = <PlateGroup, double>{
    for (final PlateGroup g in PlateGroup.values)
      g: loggedDays == 0
          ? 0
          : plateByDay.values.where((Set<PlateGroup> d) => d.contains(g)).length /
              loggedDays,
  };

  final bool enough;
  switch (period) {
    case ReportPeriod.today:
      enough = lines.length >= 3;
    case ReportPeriod.week:
      enough = loggedDays >= 3;
    case ReportPeriod.month:
      enough = loggedDays >= 5;
  }

  int balancedDays = 0;
  int partialDays = 0;
  for (final Set<PlateGroup> day in plateByDay.values) {
    if (day.length >= 4 && day.contains(PlateGroup.vegetables)) {
      balancedDays++;
    } else if (day.length >= 3) {
      partialDays++;
    }
  }
  final BalanceVerdict verdict;
  if (!enough) {
    verdict = BalanceVerdict.notEnoughData;
  } else if (period == ReportPeriod.today) {
    verdict = balancedDays > 0
        ? BalanceVerdict.balanced
        : (partialDays > 0 ? BalanceVerdict.partly : BalanceVerdict.notBalanced);
  } else if (balancedDays / loggedDays >= 0.6) {
    verdict = BalanceVerdict.balanced;
  } else if ((balancedDays + partialDays) / loggedDays >= 0.5) {
    verdict = BalanceVerdict.partly;
  } else {
    verdict = BalanceVerdict.notBalanced;
  }

  // Most important gaps first.
  const List<PlateGroup> order = <PlateGroup>[
    PlateGroup.vegetables,
    PlateGroup.protein,
    PlateGroup.fruits,
    PlateGroup.dairy,
    PlateGroup.cereals,
  ];
  final List<PlateGroup> missing = enough
      ? <PlateGroup>[
          for (final PlateGroup g in order)
            if ((coverage[g] ?? 0) < 0.5) g,
        ]
      : <PlateGroup>[];

  final double? perPerson = (loggedDays == 0 || counted == 0)
      ? null
      : totalKcal / loggedDays / headcount;
  final double? fatShare =
      totalKcal >= 500 ? fatKcal / totalKcal : null;
  final double? vegFruitPerPerson = (loggedDays == 0 || vegFruitGrams <= 0)
      ? null
      : vegFruitGrams / loggedDays / headcount;

  final List<String> tips = <String>[];
  final String when = period == ReportPeriod.today ? '' : ' on most days';
  for (final PlateGroup g in missing) {
    switch (g) {
      case PlateGroup.vegetables:
        tips.add('Few vegetables$when. Add a sabzi, sambar or salad to lunch '
            'or dinner.');
      case PlateGroup.protein:
        tips.add(vegetarian
            ? 'Little dal or pulses$when. Add dal, rajma, chana or sprouts '
                'to a meal.'
            : 'Little dal, pulses, eggs or meat$when. Add one to a meal.');
      case PlateGroup.fruits:
        tips.add('No fruit$when. Add a fruit with breakfast or as an evening '
            'snack.');
      case PlateGroup.dairy:
        tips.add('No milk, curd or paneer$when. Add curd, buttermilk or a '
            'glass of milk.');
      case PlateGroup.cereals:
        tips.add('No rice, roti or millets$when. A grain with your main '
            'meals gives steady energy.');
    }
  }
  if (enough && fatShare != null && fatShare > kFatShareLimit) {
    tips.add('Oil, ghee and butter are about ${(fatShare * 100).round()}% of '
        'the calories counted. Try a little less oil, or steam, roast or '
        'pressure-cook more dishes.');
  }
  if (enough &&
      vegFruitPerPerson != null &&
      vegFruitPerPerson < kVegFruitGoalGrams &&
      !missing.contains(PlateGroup.vegetables)) {
    tips.add('About ${vegFruitPerPerson.round()} g of vegetables and fruit '
        'per person was counted. A common goal is ${kVegFruitGoalGrams.round()} '
        'g or more a day.');
  }

  final List<String> notes = <String>[];
  if (perPerson != null && perPerson < 1000) {
    notes.add('This looks low. Food you did not mark as used is not counted.');
  } else if (perPerson != null && perPerson > 3000) {
    notes.add('This looks high. Check the number of people in Recipes.');
  }

  final List<ItemStock> candidates = stocks
      .where((ItemStock s) =>
          s.totalRemaining > 0 &&
          s.status != StatusKind.expired &&
          s.status != StatusKind.outOfStock &&
          !(vegetarian && groupOfItem(s.item) == FoodGroup.meatEggs))
      .toList();
  final List<PantrySuggestion> suggestions = <PantrySuggestion>[];
  for (final PlateGroup g in missing.take(2)) {
    final List<ItemStock> matches = candidates
        .where((ItemStock s) => plateGroupOf(groupOfItem(s.item)) == g)
        .toList()
      ..sort((ItemStock a, ItemStock b) {
        final int byUrgency = (a.status == StatusKind.expiring ? 0 : 1) -
            (b.status == StatusKind.expiring ? 0 : 1);
        return byUrgency != 0
            ? byUrgency
            : a.item.name.compareTo(b.item.name);
      });
    if (matches.isNotEmpty) {
      suggestions.add(
        PantrySuggestion(
          group: g,
          items: <String>[for (final ItemStock s in matches.take(3)) s.item.name],
        ),
      );
    }
  }

  return ConsumptionReport(
    period: period,
    people: headcount,
    lines: lines,
    loggedDays: loggedDays,
    totalKcal: totalKcal,
    countedLines: counted,
    kcalPerPersonPerDay: perPerson,
    coverage: coverage,
    verdict: verdict,
    missing: missing,
    tips: tips.take(4).toList(),
    suggestions: suggestions,
    notes: notes,
    vegFruitGramsPerPersonPerDay: vegFruitPerPerson,
    fatShare: fatShare,
  );
}
