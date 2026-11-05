import '../../../core/util/date_only.dart' show dateOnly, daysBetween;
import '../../pantry/domain/consumption_type.dart';
import '../../pantry/domain/entities.dart';
import '../../pantry/domain/waste_reason.dart';

/// Waste in one month for one reason.
final class ReasonWaste {
  const ReasonWaste({
    required this.reason,
    required this.count,
    required this.value,
  });

  final WasteReason reason;

  /// Number of waste or expiry events.
  final int count;

  /// Estimated money lost, from the batch prices.
  final double value;
}

/// One item in the money-saved report.
final class SavedItem {
  const SavedItem({
    required this.itemId,
    required this.name,
    required this.uses,
    required this.value,
  });

  final String itemId;
  final String name;

  /// How many times it was used in time.
  final int uses;

  /// Estimated money kept, from the batch prices.
  final double value;
}

/// Food that was used before it went off, after it had been flagged as
/// expiring.
final class MoneySaved {
  const MoneySaved({
    required this.month,
    required this.value,
    required this.uses,
    required this.itemCount,
    required this.topItems,
  });

  final DateTime month;

  /// Estimated money kept: the price of the part of each batch that was used
  /// in time.
  final double value;

  /// Number of uses that counted (with or without a price).
  final int uses;

  /// Different items involved.
  final int itemCount;

  /// The items that saved the most, biggest first (at most five).
  final List<SavedItem> topItems;

  bool get isEmpty => uses == 0;
}

/// Waste cost and money saved. Pure Dart: no Flutter, no database.
abstract final class WasteCost {
  /// Whether [entry] is food thrown away or expired.
  static bool isWaste(ConsumptionEntry entry) {
    return entry.type == ConsumptionType.wasted ||
        entry.type == ConsumptionType.expired;
  }

  /// The reason to report for a waste [entry]: the stored one, "expired" for
  /// food logged as expired before reasons existed, otherwise "not recorded".
  static WasteReason reasonOf(ConsumptionEntry entry) {
    final WasteReason? stored = entry.wasteReason;
    if (stored != null && stored != WasteReason.unspecified) {
      return stored;
    }
    return entry.type == ConsumptionType.expired
        ? WasteReason.expired
        : WasteReason.unspecified;
  }

  /// The price of [quantityUsed] out of [batch]: the batch price scaled by the
  /// share used (never more than the whole price). Zero when the batch is
  /// gone or has no price.
  static double valueOf(StockBatch? batch, double quantityUsed) {
    final double? price = batch?.price;
    if (batch == null || price == null || batch.quantityBought <= 0) {
      return 0;
    }
    final double share = quantityUsed / batch.quantityBought;
    return price * (share > 1 ? 1 : (share < 0 ? 0 : share));
  }

  static bool _sameMonth(DateTime a, DateTime month) {
    return a.year == month.year && a.month == month.month;
  }

  static Map<String, StockBatch> _batchesById(List<ItemWithBatches> records) {
    return <String, StockBatch>{
      for (final ItemWithBatches r in records)
        for (final StockBatch b in r.batches) b.id: b,
    };
  }

  /// Waste and expiry in [month] split by reason, biggest loss first (then
  /// most events). Reasons with no events are left out.
  static List<ReasonWaste> byReason(
    List<ItemWithBatches> records,
    List<ConsumptionEntry> logs,
    DateTime month,
  ) {
    final Map<String, StockBatch> batches = _batchesById(records);
    final Map<WasteReason, int> counts = <WasteReason, int>{};
    final Map<WasteReason, double> values = <WasteReason, double>{};
    for (final ConsumptionEntry e in logs) {
      if (!isWaste(e) || !_sameMonth(e.date, month)) {
        continue;
      }
      final WasteReason reason = reasonOf(e);
      counts[reason] = (counts[reason] ?? 0) + 1;
      values[reason] =
          (values[reason] ?? 0) + valueOf(batches[e.batchId], e.quantityUsed);
    }
    final List<ReasonWaste> out = <ReasonWaste>[
      for (final MapEntry<WasteReason, int> c in counts.entries)
        ReasonWaste(
          reason: c.key,
          count: c.value,
          value: values[c.key] ?? 0,
        ),
    ];
    out.sort((ReasonWaste a, ReasonWaste b) {
      final int byValue = b.value.compareTo(a.value);
      if (byValue != 0) {
        return byValue;
      }
      final int byCount = b.count.compareTo(a.count);
      return byCount != 0 ? byCount : a.reason.index.compareTo(b.reason.index);
    });
    return out;
  }

  /// Food used in time in [month].
  ///
  /// A use (or a recipe cooked) counts as "saved" when it happened on a day
  /// that was within [warningDays] days before the batch's effective expiry,
  /// or on the expiry day itself: that is when the food was flagged as
  /// expiring. The value is the batch price scaled by the share used. Waste,
  /// expiry, given-away food and count adjustments never count.
  static MoneySaved moneySaved({
    required List<ItemWithBatches> records,
    required List<ConsumptionEntry> logs,
    required DateTime month,
    required int warningDays,
  }) {
    final Map<String, StockBatch> batches = _batchesById(records);
    final Map<String, Item> items = <String, Item>{
      for (final ItemWithBatches r in records) r.item.id: r.item,
    };
    int uses = 0;
    double value = 0;
    final Map<String, int> counts = <String, int>{};
    final Map<String, double> values = <String, double>{};
    for (final ConsumptionEntry e in logs) {
      final bool isUse = e.type == ConsumptionType.used ||
          e.type == ConsumptionType.cookedInRecipe;
      if (!isUse || !_sameMonth(e.date, month)) {
        continue;
      }
      final StockBatch? batch = batches[e.batchId];
      final DateTime? expiry = batch?.effectiveExpiry;
      if (batch == null || expiry == null) {
        continue;
      }
      final int daysLeft = daysBetween(dateOnly(e.date), expiry);
      if (daysLeft < 0 || daysLeft > warningDays) {
        continue;
      }
      final double kept = valueOf(batch, e.quantityUsed);
      uses++;
      value += kept;
      counts[e.itemId] = (counts[e.itemId] ?? 0) + 1;
      values[e.itemId] = (values[e.itemId] ?? 0) + kept;
    }
    final List<SavedItem> top = <SavedItem>[
      for (final MapEntry<String, int> c in counts.entries)
        SavedItem(
          itemId: c.key,
          name: items[c.key]?.name ?? 'Removed item',
          uses: c.value,
          value: values[c.key] ?? 0,
        ),
    ];
    top.sort((SavedItem a, SavedItem b) {
      final int byValue = b.value.compareTo(a.value);
      return byValue != 0 ? byValue : b.uses.compareTo(a.uses);
    });
    return MoneySaved(
      month: month,
      value: value,
      uses: uses,
      itemCount: counts.length,
      topItems: top.take(5).toList(),
    );
  }
}
