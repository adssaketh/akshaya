import '../../../core/util/quantity.dart';
import 'entities.dart';
import 'unit.dart';

/// Amount to take from one batch, in that batch's own unit.
final class Deduction {
  const Deduction({
    required this.batchId,
    required this.amount,
    required this.unit,
  });

  final String batchId;
  final double amount;
  final Unit unit;
}

/// Result of planning a deduction across batches.
final class FifoPlan {
  const FifoPlan({
    required this.deductions,
    required this.shortfall,
    required this.unit,
  });

  final List<Deduction> deductions;

  /// Part of the request that no batch could cover, in [unit].
  final double shortfall;

  /// The unit the request was made in.
  final Unit unit;

  bool get isComplete => shortfall < kQtyEpsilon;
}

/// "First expiring, first out": uses the batch that expires first, then the
/// next, and so on. Batches without an expiry come last, oldest purchase
/// first.
abstract final class Fifo {
  /// Batches that still hold stock, in the order they should be used.
  static List<StockBatch> order(Iterable<StockBatch> batches) {
    final List<StockBatch> list = batches
        .where((StockBatch b) => !isZeroQty(b.quantityRemaining))
        .toList();
    list.sort(_compare);
    return list;
  }

  static int _compare(StockBatch a, StockBatch b) {
    final DateTime? ea = a.effectiveExpiry;
    final DateTime? eb = b.effectiveExpiry;
    if (ea != null && eb != null) {
      final int byExpiry = ea.compareTo(eb);
      if (byExpiry != 0) {
        return byExpiry;
      }
    } else if (ea != null) {
      return -1;
    } else if (eb != null) {
      return 1;
    }
    final int byPurchase = a.purchaseDate.compareTo(b.purchaseDate);
    if (byPurchase != 0) {
      return byPurchase;
    }
    return a.createdAt.compareTo(b.createdAt);
  }

  /// Plans taking [quantity] (in [unit]) from [batches]. Batches whose unit
  /// cannot be converted to [unit] are skipped.
  static FifoPlan plan({
    required Iterable<StockBatch> batches,
    required double quantity,
    required Unit unit,
  }) {
    double left = roundQty(quantity);
    final List<Deduction> deductions = <Deduction>[];

    for (final StockBatch batch in order(batches)) {
      if (isZeroQty(left)) {
        break;
      }
      if (!batch.unit.isCompatibleWith(unit)) {
        continue;
      }
      final double availableInRequested =
          batch.unit.convertTo(batch.quantityRemaining, unit);
      final double takeInRequested =
          left < availableInRequested ? left : availableInRequested;

      double amount = roundQty(unit.convertTo(takeInRequested, batch.unit));
      if (amount > batch.quantityRemaining) {
        amount = batch.quantityRemaining;
      }
      if (isZeroQty(amount)) {
        continue;
      }
      deductions.add(
        Deduction(batchId: batch.id, amount: amount, unit: batch.unit),
      );
      left = roundQty(left - takeInRequested);
    }

    return FifoPlan(
      deductions: deductions,
      shortfall: isZeroQty(left) ? 0 : left,
      unit: unit,
    );
  }
}
