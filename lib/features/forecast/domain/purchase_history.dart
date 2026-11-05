import '../../../core/util/quantity.dart';
import '../../pantry/domain/consumption_type.dart';
import '../../pantry/domain/entities.dart';
import '../../pantry/domain/unit.dart';

/// What the batches say about how an item is bought. Pure Dart.
abstract final class PurchaseHistory {
  /// How many of the latest purchases decide the usual pack size.
  static const int packSample = 5;

  /// Batches that Count mode created for stock found on the shelf. They are
  /// not purchases, so they are left out of buying habits. (Count mode logs a
  /// negative "adjustment" against the batch it creates.)
  static Set<String> adjustmentBatchIds(List<ConsumptionEntry> logs) {
    return <String>{
      for (final ConsumptionEntry e in logs)
        if (e.type == ConsumptionType.adjustment && e.quantityUsed < 0)
          e.batchId,
    };
  }

  /// The pack size the person usually buys, in the item's default unit: the
  /// most common amount among the latest [packSample] purchases (the most
  /// recent one wins a tie). Falls back to one sensible unit when the item was
  /// never bought.
  static double usualPackSize(
    Item item,
    List<StockBatch> batches, {
    Set<String> excludedBatchIds = const <String>{},
  }) {
    final Unit unit = item.defaultUnit;
    final List<StockBatch> bought = <StockBatch>[
      for (final StockBatch b in batches)
        if (!excludedBatchIds.contains(b.id) &&
            b.unit.isCompatibleWith(unit) &&
            !isZeroQty(b.quantityBought))
          b,
    ]..sort((StockBatch a, StockBatch b) {
        final int byDate = b.purchaseDate.compareTo(a.purchaseDate);
        return byDate != 0 ? byDate : b.createdAt.compareTo(a.createdAt);
      });
    final List<StockBatch> recent = bought.take(packSample).toList();
    if (recent.isEmpty) {
      return _fallbackPack(unit);
    }

    double sizeOf(StockBatch b) {
      return roundQty(b.unit.convertTo(b.quantityBought, unit));
    }

    final Map<double, int> counts = <double, int>{};
    for (final StockBatch b in recent) {
      final double size = sizeOf(b);
      counts[size] = (counts[size] ?? 0) + 1;
    }
    double best = sizeOf(recent.first);
    int bestCount = 0;
    // Newest first, so a tie keeps the most recent size.
    for (final StockBatch b in recent) {
      final double size = sizeOf(b);
      final int count = counts[size] ?? 0;
      if (count > bestCount) {
        best = size;
        bestCount = count;
      }
    }
    return best;
  }

  static double _fallbackPack(Unit unit) {
    switch (unit) {
      case Unit.g:
      case Unit.ml:
        return 500;
      case Unit.kg:
      case Unit.l:
      case Unit.pcs:
      case Unit.packet:
      case Unit.dozen:
      case Unit.bunch:
      case Unit.portion:
        return 1;
    }
  }
}
