import 'dart:math' as math;

import '../../../core/util/date_only.dart';
import '../../../core/util/quantity.dart';
import '../../pantry/domain/consumption_type.dart';
import '../../pantry/domain/entities.dart';
import '../../pantry/domain/unit.dart';

/// How far the learning for one item has got.
enum ForecastState {
  /// Not enough use has been logged yet to predict anything.
  learning,

  /// A usage rate has been worked out.
  ready,
}

/// How fast one item is used and when it will run out. Pure value; build it
/// with [ConsumptionForecast].
final class ItemForecast {
  const ItemForecast({
    required this.item,
    required this.state,
    required this.dataPoints,
    required this.remaining,
    this.perDay = 0,
    this.daysLeft,
  });

  final Item item;
  final ForecastState state;

  /// Days on which use was logged inside the learning window.
  final int dataPoints;

  /// Stock that is still good, in the item's default unit.
  final double remaining;

  /// Use per day in the item's default unit (0 while learning).
  final double perDay;

  /// Whole days until the stock runs out at [perDay]; null while learning.
  final int? daysLeft;

  bool get isReady => state == ForecastState.ready;

  /// True when no usable stock is left.
  bool get isOut => isZeroQty(remaining);

  /// True when there is stock and it is predicted to run out within
  /// [ConsumptionForecast.soonDays] days: close enough to mention on a list
  /// row.
  bool get isSoon {
    final int? days = daysLeft;
    return isReady &&
        !isOut &&
        days != null &&
        days <= ConsumptionForecast.soonDays;
  }

  /// The calendar day the stock runs out on [today], or null while learning.
  DateTime? runsOutOn(DateTime today) {
    final int? days = daysLeft;
    return days == null ? null : addDays(today, days);
  }

  /// "Runs out in ~6 days", "Out of stock" or "Learning your usage".
  String get label {
    final int? days = daysLeft;
    if (!isReady || days == null) {
      return 'Learning your usage';
    }
    if (isOut) {
      return 'Out of stock';
    }
    if (days <= 0) {
      return 'Runs out today';
    }
    if (days == 1) {
      return 'Runs out in ~1 day';
    }
    if (days > ConsumptionForecast.longLastingDays) {
      return 'Lasts 4+ months';
    }
    return 'Runs out in ~$days days';
  }

  /// "About 0.7 kg a week" (or a month for slow items); null while learning.
  String? get usageLabel {
    if (!isReady) {
      return null;
    }
    final Unit unit = item.defaultUnit;
    final double perWeek = perDay * 7;
    if (perWeek >= 0.1) {
      return 'About ${unit.format(perWeek)} a week';
    }
    return 'About ${unit.format(perDay * 30)} a month';
  }

  /// Why nothing is predicted yet: "Learning: 2 of 3 uses logged".
  String get learningDetail {
    final int have = dataPoints < ConsumptionForecast.minDataPoints
        ? dataPoints
        : ConsumptionForecast.minDataPoints;
    return 'Learning: $have of ${ConsumptionForecast.minDataPoints} days of '
        'use logged';
  }

  @override
  bool operator ==(Object other) {
    return other is ItemForecast &&
        other.item.id == item.id &&
        other.item.defaultUnit == item.defaultUnit &&
        other.state == state &&
        other.dataPoints == dataPoints &&
        other.remaining == remaining &&
        other.perDay == perDay &&
        other.daysLeft == daysLeft;
  }

  @override
  int get hashCode => Object.hash(
        item.id,
        item.defaultUnit,
        state,
        dataPoints,
        remaining,
        perDay,
        daysLeft,
      );
}

/// Works out a consumption rate per item from the use log. Pure Dart: no
/// Flutter, no database, no AI.
///
/// What counts: "used" and "cooked in recipe" entries of stocked items.
/// Waste, expiry, given away and count-mode adjustments never count as use.
///
/// How the rate is worked out:
///  - Only completed days count (up to yesterday), over the last
///    [windowDays] days, starting on the day of the first logged use.
///  - It is a weighted average of use per day, including days with no use.
///    A day's weight halves every [halfLifeDays] days, so recent weeks matter
///    most and an item you stopped using slows down in the forecast.
///  - With [outlierMinDataPoints] or more use days, a day with more than
///    [outlierFactor] times the typical (median) day is left out, so one big
///    cook-up does not skew the rate.
///  - Fewer than [minDataPoints] use days, or less than [minSpanDays] days of
///    history, means the item is still "learning".
abstract final class ConsumptionForecast {
  /// Use older than this many days is ignored.
  static const int windowDays = 56;

  /// A day's weight halves every this many days.
  static const double halfLifeDays = 21;

  /// Days of logged use needed before a rate is shown.
  static const int minDataPoints = 3;

  /// Days between the first logged use and yesterday needed for a rate.
  static const int minSpanDays = 7;

  /// Outliers are only looked for with at least this many use days.
  static const int outlierMinDataPoints = 5;

  /// A use day this many times above the median day is an outlier.
  static const double outlierFactor = 3;

  /// Beyond this many days of stock the label just says it lasts months.
  static const int longLastingDays = 120;

  /// A forecast within this many days is shown on pantry rows.
  static const int soonDays = 14;

  /// Forecasts for every stocked item (cooked and homemade food is made, not
  /// bought, so it gets none), keyed by item id.
  static Map<String, ItemForecast> forAll(
    List<ItemWithBatches> records,
    List<ConsumptionEntry> logs,
    DateTime today,
  ) {
    final DateTime day = dateOnly(today);
    final Map<String, List<ConsumptionEntry>> byItem =
        <String, List<ConsumptionEntry>>{};
    for (final ConsumptionEntry e in logs) {
      byItem.putIfAbsent(e.itemId, () => <ConsumptionEntry>[]).add(e);
    }
    return <String, ItemForecast>{
      for (final ItemWithBatches r in records)
        if (r.item.kind.isStocked)
          r.item.id: forItem(
            r,
            byItem[r.item.id] ?? const <ConsumptionEntry>[],
            day,
          ),
    };
  }

  /// The forecast for one item. [logs] may hold other items' entries too;
  /// only this item's are used.
  static ItemForecast forItem(
    ItemWithBatches record,
    List<ConsumptionEntry> logs,
    DateTime today,
  ) {
    final Item item = record.item;
    final DateTime now = dateOnly(today);
    final DateTime lastDay = addDays(now, -1);
    final DateTime windowStart = addDays(now, -windowDays);
    final Unit base = item.defaultUnit;

    final double remaining = _usableStock(record, now);

    final Map<DateTime, double> useByDay = <DateTime, double>{};
    for (final ConsumptionEntry e in logs) {
      if (e.itemId != item.id) {
        continue;
      }
      final bool isUse = e.type == ConsumptionType.used ||
          e.type == ConsumptionType.cookedInRecipe;
      if (!isUse || !e.unit.isCompatibleWith(base)) {
        continue;
      }
      final DateTime day = dateOnly(e.date);
      if (day.isBefore(windowStart) || day.isAfter(lastDay)) {
        continue;
      }
      final double amount = e.unit.convertTo(e.quantityUsed, base);
      if (!amount.isFinite || amount <= 0) {
        continue;
      }
      useByDay[day] = (useByDay[day] ?? 0) + amount;
    }

    ItemForecast learning() {
      return ItemForecast(
        item: item,
        state: ForecastState.learning,
        dataPoints: useByDay.length,
        remaining: remaining,
      );
    }

    if (useByDay.length < minDataPoints) {
      return learning();
    }
    final List<DateTime> days = useByDay.keys.toList()..sort();
    final DateTime start = days.first;
    final int span = daysBetween(start, lastDay) + 1;
    if (span < minSpanDays) {
      return learning();
    }

    final Set<DateTime> excluded = _outlierDays(useByDay);

    double weightedUse = 0;
    double weightTotal = 0;
    for (int i = 0; i < span; i++) {
      final DateTime day = addDays(start, i);
      if (excluded.contains(day)) {
        continue;
      }
      final int age = daysBetween(day, now);
      final double weight = math.pow(0.5, age / halfLifeDays).toDouble();
      weightTotal += weight;
      weightedUse += weight * (useByDay[day] ?? 0);
    }
    if (weightTotal <= 0 || weightedUse <= 0) {
      return learning();
    }

    final double perDay = weightedUse / weightTotal;
    final int daysLeft = isZeroQty(remaining)
        ? 0
        : math.min((remaining / perDay).floor(), 3650);
    return ItemForecast(
      item: item,
      state: ForecastState.ready,
      dataPoints: useByDay.length,
      remaining: remaining,
      perDay: perDay,
      daysLeft: daysLeft,
    );
  }

  /// Items with a rate and some stock left, soonest to run out first.
  static List<ItemForecast> runningOut(Map<String, ItemForecast> forecasts) {
    final List<ItemForecast> out = <ItemForecast>[
      for (final ItemForecast f in forecasts.values)
        if (f.isReady && !f.isOut) f,
    ];
    out.sort((ItemForecast a, ItemForecast b) {
      final int byDays = a.daysLeft!.compareTo(b.daysLeft!);
      if (byDays != 0) {
        return byDays;
      }
      return a.item.name.toLowerCase().compareTo(b.item.name.toLowerCase());
    });
    return out;
  }

  /// Stock that is still good, in the item's default unit. Batches past their
  /// date do not count, like everywhere else in the app.
  static double _usableStock(ItemWithBatches record, DateTime today) {
    final Unit base = record.item.defaultUnit;
    double total = 0;
    for (final StockBatch b in record.batches) {
      if (!b.unit.isCompatibleWith(base)) {
        continue;
      }
      final DateTime? expiry = b.effectiveExpiry;
      if (expiry != null && expiry.isBefore(today)) {
        continue;
      }
      total += b.unit.convertTo(b.quantityRemaining, base);
    }
    return roundQty(total);
  }

  /// Days far above the typical day. Empty with too few days to judge.
  static Set<DateTime> _outlierDays(Map<DateTime, double> useByDay) {
    if (useByDay.length < outlierMinDataPoints) {
      return const <DateTime>{};
    }
    final List<double> amounts = useByDay.values.toList()..sort();
    final int mid = amounts.length ~/ 2;
    final double median = amounts.length.isOdd
        ? amounts[mid]
        : (amounts[mid - 1] + amounts[mid]) / 2;
    return <DateTime>{
      for (final MapEntry<DateTime, double> e in useByDay.entries)
        if (e.value > median * outlierFactor) e.key,
    };
  }
}
