import '../../../core/util/date_only.dart';
import '../../../core/util/quantity.dart';
import '../../pantry/domain/consumption_type.dart';
import '../../pantry/domain/entities.dart';
import '../../pantry/domain/unit.dart';

/// First day of the month containing [day].
DateTime monthOf(DateTime day) => DateTime(day.year, day.month);

/// The month [delta] months after [month] (negative for earlier).
DateTime addMonths(DateTime month, int delta) {
  return DateTime(month.year, month.month + delta);
}

bool _sameMonth(DateTime a, DateTime month) {
  return a.year == month.year && a.month == month.month;
}

/// Money spent on one category in one month.
final class CategorySpend {
  const CategorySpend({
    required this.categoryId,
    required this.name,
    required this.amount,
  });

  final String categoryId;
  final String name;
  final double amount;
}

/// Money spent in one month.
final class MonthTotal {
  const MonthTotal({required this.month, required this.amount});

  final DateTime month;
  final double amount;
}

/// One item in the waste report.
final class WastedItem {
  const WastedItem({
    required this.itemId,
    required this.name,
    required this.count,
    required this.value,
  });

  final String itemId;
  final String name;

  /// How many times it was thrown away or expired.
  final int count;

  /// Estimated money lost, from the batch prices.
  final double value;
}

/// What was thrown away or expired in one month.
final class WasteReport {
  const WasteReport({
    required this.month,
    required this.entries,
    required this.itemCount,
    required this.value,
    required this.wastedCount,
    required this.expiredCount,
    required this.topItems,
  });

  final DateTime month;

  /// Number of waste or expiry events.
  final int entries;

  /// Different items involved.
  final int itemCount;

  /// Estimated money lost.
  final double value;
  final int wastedCount;
  final int expiredCount;
  final List<WastedItem> topItems;

  bool get isEmpty => entries == 0;
}

/// How fast one item is used, and when it will run out.
final class RunOutEstimate {
  const RunOutEstimate({
    required this.item,
    required this.perDay,
    required this.remaining,
    required this.daysLeft,
  });

  final Item item;

  /// Average use per day, in the item's default unit.
  final double perDay;

  /// What is left now, in the item's default unit.
  final double remaining;

  /// Whole days until it runs out at this rate.
  final int daysLeft;

  String get label => daysLeft <= 0 ? 'runs out today' : 'runs out in ~$daysLeft days';
}

/// One price paid for an item.
final class PricePoint {
  const PricePoint({
    required this.date,
    required this.unitPrice,
    required this.store,
  });

  final DateTime date;

  /// Price per one default unit of the item.
  final double unitPrice;
  final String? store;
}

/// Spending, waste, usage and price figures. Pure Dart.
abstract final class Insights {
  /// Use entries older than this many days are ignored for the usage rate.
  static const int rateWindowDays = 60;

  /// An item needs at least this many use entries before a rate is shown;
  /// before that it is still "learning".
  static const int minUseEntries = 3;

  /// Spread of the use entries must cover at least this many days.
  static const int minRateDays = 7;

  static double spendInMonth(List<ItemWithBatches> records, DateTime month) {
    double total = 0;
    for (final ItemWithBatches r in records) {
      for (final StockBatch b in r.batches) {
        final double? price = b.price;
        if (price != null && _sameMonth(b.purchaseDate, month)) {
          total += price;
        }
      }
    }
    return total;
  }

  /// Spending per category, biggest first. Categories without spending are
  /// left out.
  static List<CategorySpend> spendByCategory(
    List<ItemWithBatches> records,
    List<Category> categories,
    DateTime month,
  ) {
    final Map<String, double> sums = <String, double>{};
    for (final ItemWithBatches r in records) {
      for (final StockBatch b in r.batches) {
        final double? price = b.price;
        if (price != null && _sameMonth(b.purchaseDate, month)) {
          sums[r.item.categoryId] = (sums[r.item.categoryId] ?? 0) + price;
        }
      }
    }
    final Map<String, String> names = <String, String>{
      for (final Category c in categories) c.id: c.name,
    };
    final List<CategorySpend> out = <CategorySpend>[
      for (final MapEntry<String, double> e in sums.entries)
        if (e.value > 0)
          CategorySpend(
            categoryId: e.key,
            name: names[e.key] ?? 'Other',
            amount: e.value,
          ),
    ];
    out.sort((CategorySpend a, CategorySpend b) => b.amount.compareTo(a.amount));
    return out;
  }

  /// Totals for the [months] months ending with [lastMonth], oldest first.
  static List<MonthTotal> monthlySpend(
    List<ItemWithBatches> records,
    DateTime lastMonth, {
    int months = 6,
  }) {
    return <MonthTotal>[
      for (int i = months - 1; i >= 0; i--)
        MonthTotal(
          month: addMonths(monthOf(lastMonth), -i),
          amount: spendInMonth(records, addMonths(monthOf(lastMonth), -i)),
        ),
    ];
  }

  /// Waste and expiry in [month]. The money value is the price of the batch,
  /// scaled by the share of it that was lost; entries whose batch is gone or
  /// has no price count with zero value.
  static WasteReport wasteReport(
    List<ItemWithBatches> records,
    List<ConsumptionEntry> logs,
    DateTime month,
  ) {
    final Map<String, StockBatch> batches = <String, StockBatch>{};
    final Map<String, Item> items = <String, Item>{};
    for (final ItemWithBatches r in records) {
      items[r.item.id] = r.item;
      for (final StockBatch b in r.batches) {
        batches[b.id] = b;
      }
    }
    int entries = 0;
    int wasted = 0;
    int expired = 0;
    double value = 0;
    final Map<String, int> counts = <String, int>{};
    final Map<String, double> values = <String, double>{};
    for (final ConsumptionEntry e in logs) {
      final bool isWaste = e.type == ConsumptionType.wasted ||
          e.type == ConsumptionType.expired;
      if (!isWaste || !_sameMonth(e.date, month)) {
        continue;
      }
      entries++;
      if (e.type == ConsumptionType.wasted) {
        wasted++;
      } else {
        expired++;
      }
      double lost = 0;
      final StockBatch? batch = batches[e.batchId];
      final double? price = batch?.price;
      if (batch != null && price != null && batch.quantityBought > 0) {
        final double share = e.quantityUsed / batch.quantityBought;
        lost = price * (share > 1 ? 1 : share);
      }
      value += lost;
      counts[e.itemId] = (counts[e.itemId] ?? 0) + 1;
      values[e.itemId] = (values[e.itemId] ?? 0) + lost;
    }
    final List<WastedItem> top = <WastedItem>[
      for (final MapEntry<String, int> c in counts.entries)
        WastedItem(
          itemId: c.key,
          name: items[c.key]?.name ?? 'Removed item',
          count: c.value,
          value: values[c.key] ?? 0,
        ),
    ];
    top.sort((WastedItem a, WastedItem b) {
      final int byValue = b.value.compareTo(a.value);
      return byValue != 0 ? byValue : b.count.compareTo(a.count);
    });
    return WasteReport(
      month: month,
      entries: entries,
      itemCount: counts.length,
      value: value,
      wastedCount: wasted,
      expiredCount: expired,
      topItems: top.take(5).toList(),
    );
  }

  /// Items whose use is steady enough to predict, soonest to run out first.
  /// Only real use counts (used, cooked in recipe); waste does not.
  static List<RunOutEstimate> runOutEstimates(
    List<ItemWithBatches> records,
    List<ConsumptionEntry> logs,
    DateTime today,
  ) {
    final Map<String, List<ConsumptionEntry>> byItem =
        <String, List<ConsumptionEntry>>{};
    final DateTime since = today.subtract(const Duration(days: rateWindowDays));
    for (final ConsumptionEntry e in logs) {
      final bool isUse = e.type == ConsumptionType.used ||
          e.type == ConsumptionType.cookedInRecipe;
      if (isUse && !dateOnly(e.date).isBefore(since)) {
        byItem.putIfAbsent(e.itemId, () => <ConsumptionEntry>[]).add(e);
      }
    }
    final List<RunOutEstimate> out = <RunOutEstimate>[];
    for (final ItemWithBatches r in records) {
      final List<ConsumptionEntry>? uses = byItem[r.item.id];
      if (uses == null || uses.length < minUseEntries) {
        continue;
      }
      final Unit base = r.item.defaultUnit;
      double used = 0;
      DateTime first = dateOnly(uses.first.date);
      for (final ConsumptionEntry e in uses) {
        if (!e.unit.isCompatibleWith(base)) {
          continue;
        }
        used += e.unit.convertTo(e.quantityUsed, base);
        final DateTime day = dateOnly(e.date);
        if (day.isBefore(first)) {
          first = day;
        }
      }
      final int span = daysBetween(first, today);
      if (span < minRateDays || isZeroQty(used)) {
        continue;
      }
      double remaining = 0;
      for (final StockBatch b in r.batches) {
        if (b.unit.isCompatibleWith(base)) {
          remaining += b.unit.convertTo(b.quantityRemaining, base);
        }
      }
      if (isZeroQty(remaining)) {
        continue;
      }
      final double perDay = used / span;
      out.add(
        RunOutEstimate(
          item: r.item,
          perDay: perDay,
          remaining: remaining,
          daysLeft: (remaining / perDay).floor(),
        ),
      );
    }
    out.sort(
      (RunOutEstimate a, RunOutEstimate b) => a.daysLeft.compareTo(b.daysLeft),
    );
    return out;
  }

  /// Every price paid for [record]'s item that can be compared (per default
  /// unit), oldest first.
  static List<PricePoint> priceHistory(ItemWithBatches record) {
    final List<PricePoint> out = <PricePoint>[];
    for (final StockBatch b in record.batches) {
      final double? unitPrice = b.unitPrice(record.item.defaultUnit);
      if (unitPrice != null) {
        out.add(
          PricePoint(date: b.purchaseDate, unitPrice: unitPrice, store: b.store),
        );
      }
    }
    out.sort((PricePoint a, PricePoint b) => a.date.compareTo(b.date));
    return out;
  }

  /// Items that have at least two prices to compare, most prices first.
  static List<ItemWithBatches> itemsWithPrices(List<ItemWithBatches> records) {
    final List<ItemWithBatches> out = <ItemWithBatches>[
      for (final ItemWithBatches r in records)
        if (priceHistory(r).length >= 2) r,
    ];
    out.sort(
      (ItemWithBatches a, ItemWithBatches b) =>
          priceHistory(b).length.compareTo(priceHistory(a).length),
    );
    return out;
  }

  /// Average price per default unit by store, cheapest first. Purchases
  /// without a store are grouped under "No store".
  static List<({String store, double average, int purchases})> priceByStore(
    List<PricePoint> points,
  ) {
    final Map<String, List<double>> groups = <String, List<double>>{};
    for (final PricePoint p in points) {
      final String key = (p.store ?? '').trim().isEmpty ? 'No store' : p.store!.trim();
      groups.putIfAbsent(key, () => <double>[]).add(p.unitPrice);
    }
    final List<({String store, double average, int purchases})> out =
        <({String store, double average, int purchases})>[
      for (final MapEntry<String, List<double>> g in groups.entries)
        (
          store: g.key,
          average: g.value.reduce((double a, double b) => a + b) / g.value.length,
          purchases: g.value.length,
        ),
    ];
    out.sort(
      (a, b) => a.average.compareTo(b.average),
    );
    return out;
  }
}
