import 'package:akshaya/core/design/design.dart' show StatusKind;

import '../../../core/util/date_only.dart';
import '../../../core/util/quantity.dart';
import 'entities.dart';
import 'storage_location.dart';

/// Number of days before expiry at which an item counts as "expiring soon".
/// Becomes a setting in Phase 8.
const int kDefaultExpiryWarningDays = 3;

/// An item with its stock figures and status worked out for one calendar day.
final class ItemStock {
  const ItemStock({
    required this.item,
    required this.batches,
    required this.totalRemaining,
    required this.nearestExpiry,
    required this.daysToExpiry,
    required this.status,
    required this.primaryLocation,
  });

  final Item item;

  /// All active batches, including used-up ones.
  final List<StockBatch> batches;

  /// Remaining quantity across batches, in the item's default unit.
  final double totalRemaining;

  /// Earliest effective expiry among batches that still have stock.
  final DateTime? nearestExpiry;

  /// Calendar days from today to [nearestExpiry] (negative when past).
  final int? daysToExpiry;

  final StatusKind status;

  /// Where most urgently needed stock is kept (nearest-expiry batch), or the
  /// item's default location when nothing is in stock.
  final StorageLocation primaryLocation;

  /// Batches that still hold stock.
  List<StockBatch> get inStock {
    return batches
        .where((StockBatch b) => !isZeroQty(b.quantityRemaining))
        .toList(growable: false);
  }

  /// "2.5 kg".
  String get remainingLabel => item.defaultUnit.format(totalRemaining);

  /// Replacement for the status chip text when more detail helps
  /// ("In 2 days", "Expired 3d ago"); null keeps the default label.
  String? get statusLabel {
    final int? days = daysToExpiry;
    if (days == null) {
      return null;
    }
    switch (status) {
      case StatusKind.expiring:
        return StockLogic.expiringLabel(days);
      case StatusKind.expired:
        return StockLogic.expiredLabel(-days);
      case StatusKind.fresh:
      case StatusKind.lowStock:
      case StatusKind.outOfStock:
        return null;
    }
  }
}

/// Pure stock and expiry rules. No Flutter, no database.
abstract final class StockLogic {
  static String expiringLabel(int daysLeft) {
    if (daysLeft <= 0) {
      return 'Today';
    }
    if (daysLeft == 1) {
      return 'Tomorrow';
    }
    return 'In $daysLeft days';
  }

  static String expiredLabel(int daysAgo) => 'Expired ${daysAgo}d ago';

  /// Status of a single date: expired, expiring within [warningDays], or fresh.
  static ({StatusKind kind, String? label}) expiryStatus(
    DateTime? expiry, {
    required DateTime today,
    required int warningDays,
  }) {
    if (expiry == null) {
      return (kind: StatusKind.fresh, label: null);
    }
    final int days = daysBetween(today, expiry);
    if (days < 0) {
      return (kind: StatusKind.expired, label: expiredLabel(-days));
    }
    if (days <= warningDays) {
      return (kind: StatusKind.expiring, label: expiringLabel(days));
    }
    return (kind: StatusKind.fresh, label: null);
  }

  /// Status chip for one batch. A used-up batch reads "Used up".
  static ({StatusKind kind, String? label}) batchStatus(
    StockBatch batch, {
    required DateTime today,
    required int warningDays,
  }) {
    if (isZeroQty(batch.quantityRemaining)) {
      return (kind: StatusKind.outOfStock, label: 'Used up');
    }
    return expiryStatus(
      batch.effectiveExpiry,
      today: today,
      warningDays: warningDays,
    );
  }

  /// Works out totals, nearest expiry and status for [record] on [today].
  ///
  /// Priority: expired stock, then expiring soon, then low stock, then fresh.
  /// An item with nothing left is out of stock.
  static ItemStock summarize(
    ItemWithBatches record, {
    required DateTime today,
    required int warningDays,
  }) {
    final Item item = record.item;
    final List<StockBatch> inStock = record.batches
        .where((StockBatch b) => !isZeroQty(b.quantityRemaining))
        .toList();

    double total = 0;
    for (final StockBatch b in inStock) {
      if (b.unit.isCompatibleWith(item.defaultUnit)) {
        total += b.unit.convertTo(b.quantityRemaining, item.defaultUnit);
      }
    }
    total = roundQty(total);

    DateTime? nearest;
    StockBatch? nearestBatch;
    for (final StockBatch b in inStock) {
      final DateTime? expiry = b.effectiveExpiry;
      if (expiry == null) {
        continue;
      }
      if (nearest == null || expiry.isBefore(nearest)) {
        nearest = expiry;
        nearestBatch = b;
      }
    }

    final int? days = nearest == null ? null : daysBetween(today, nearest);

    final StatusKind status;
    if (inStock.isEmpty) {
      status = StatusKind.outOfStock;
    } else {
      final StatusKind expiryKind = expiryStatus(
        nearest,
        today: today,
        warningDays: warningDays,
      ).kind;
      final double? threshold = item.lowStockThreshold;
      if (expiryKind == StatusKind.expired ||
          expiryKind == StatusKind.expiring) {
        status = expiryKind;
      } else if (threshold != null && total <= threshold + kQtyEpsilon) {
        status = StatusKind.lowStock;
      } else {
        status = StatusKind.fresh;
      }
    }

    final StorageLocation location = nearestBatch != null
        ? nearestBatch.storageLocation
        : (inStock.isNotEmpty
            ? inStock.first.storageLocation
            : item.defaultStorageLocation);

    return ItemStock(
      item: item,
      batches: record.batches,
      totalRemaining: total,
      nearestExpiry: nearest,
      daysToExpiry: days,
      status: status,
      primaryLocation: location,
    );
  }
}
