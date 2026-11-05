import '../../../core/util/quantity.dart';
import '../../pantry/domain/entities.dart';
import '../../pantry/domain/stock_logic.dart';
import '../../pantry/domain/unit.dart';
import 'shopping_entities.dart';
import 'shopping_enums.dart';

/// Why the pantry suggests buying something.
enum SuggestionReason {
  outOfStock('Out of stock', AddedReason.lowStock),
  expired('Expired', AddedReason.expired),
  lowStock('Low stock', AddedReason.lowStock);

  const SuggestionReason(this.label, this.addedReason);

  final String label;

  /// The reason stored on the entry if the suggestion is accepted. Out of
  /// stock is stored as low stock.
  final AddedReason addedReason;
}

/// A pantry item worth restocking, worked out live from the pantry. Nothing is
/// stored until the person accepts it.
final class ShoppingSuggestion {
  const ShoppingSuggestion({
    required this.item,
    required this.reason,
    required this.quantity,
    required this.unit,
    required this.usableLeft,
  });

  final Item item;
  final SuggestionReason reason;

  /// How much to buy: what was bought last time.
  final double quantity;
  final Unit unit;

  /// Stock that is still good, in the item's default unit.
  final double usableLeft;

  String get quantityLabel => unit.format(quantity);

  /// "0.5 kg left", "Nothing left" or "All of it is past its date".
  String get detail {
    switch (reason) {
      case SuggestionReason.outOfStock:
        return 'Nothing left';
      case SuggestionReason.expired:
        return 'All of it is past its date';
      case SuggestionReason.lowStock:
        return '${item.defaultUnit.format(usableLeft)} left';
    }
  }

  /// The entry to add if the person accepts this suggestion.
  ShoppingEntryDraft toDraft(String listId) {
    return ShoppingEntryDraft(
      listId: listId,
      itemId: item.id,
      name: item.name,
      quantity: quantity,
      unit: unit,
      addedReason: reason.addedReason,
    );
  }
}

/// Works out which pantry items to suggest. Pure: no Flutter, no database.
abstract final class ShoppingSuggestions {
  /// Suggestions for [today], most urgent first (out of stock, expired, then
  /// low stock; each by name).
  ///
  /// An item is suggested when
  ///  - nothing is left (only if it was ever bought, or is marked essential),
  ///  - everything left is past its date, or
  ///  - the stock that is still good is at or below its low-stock level.
  ///
  /// Items already on any list (matched by item, or by name for free-text
  /// entries) are left out.
  static List<ShoppingSuggestion> compute({
    required List<ItemStock> stocks,
    required List<ShoppingEntry> entries,
    required DateTime today,
  }) {
    final Set<String> listedItemIds = <String>{
      for (final ShoppingEntry e in entries)
        if (e.itemId != null) e.itemId!,
    };
    final Set<String> listedNames = <String>{
      for (final ShoppingEntry e in entries) _key(e.name),
    };

    final List<ShoppingSuggestion> result = <ShoppingSuggestion>[];
    for (final ItemStock stock in stocks) {
      final Item item = stock.item;
      if (listedItemIds.contains(item.id) ||
          listedNames.contains(_key(item.name))) {
        continue;
      }

      double usable = 0;
      double pastDate = 0;
      for (final StockBatch b in stock.inStock) {
        if (!b.unit.isCompatibleWith(item.defaultUnit)) {
          continue;
        }
        final double amount =
            b.unit.convertTo(b.quantityRemaining, item.defaultUnit);
        final DateTime? expiry = b.effectiveExpiry;
        if (expiry != null && expiry.isBefore(today)) {
          pastDate += amount;
        } else {
          usable += amount;
        }
      }
      usable = roundQty(usable);
      pastDate = roundQty(pastDate);

      final SuggestionReason reason;
      if (isZeroQty(usable) && isZeroQty(pastDate)) {
        if (stock.batches.isEmpty && !item.isEssential) {
          // Never bought and not essential: nothing to restock.
          continue;
        }
        reason = SuggestionReason.outOfStock;
      } else if (isZeroQty(usable)) {
        reason = SuggestionReason.expired;
      } else {
        final double? threshold = item.lowStockThreshold;
        if (threshold != null && usable <= threshold + kQtyEpsilon) {
          reason = SuggestionReason.lowStock;
        } else {
          continue;
        }
      }

      final ({double quantity, Unit unit}) buy = _usualPurchase(stock);
      result.add(
        ShoppingSuggestion(
          item: item,
          reason: reason,
          quantity: buy.quantity,
          unit: buy.unit,
          usableLeft: usable,
        ),
      );
    }

    result.sort((ShoppingSuggestion a, ShoppingSuggestion b) {
      final int byReason = a.reason.index.compareTo(b.reason.index);
      if (byReason != 0) {
        return byReason;
      }
      return a.item.name.toLowerCase().compareTo(b.item.name.toLowerCase());
    });
    return result;
  }

  /// What was bought last time (latest purchase date, then latest created),
  /// or one of the item's default unit when it was never bought.
  static ({double quantity, Unit unit}) usualPurchase(ItemStock stock) {
    return _usualPurchase(stock);
  }

  static ({double quantity, Unit unit}) _usualPurchase(ItemStock stock) {
    StockBatch? latest;
    for (final StockBatch b in stock.batches) {
      if (latest == null) {
        latest = b;
        continue;
      }
      final int byDate = b.purchaseDate.compareTo(latest.purchaseDate);
      if (byDate > 0 || (byDate == 0 && b.createdAt.isAfter(latest.createdAt))) {
        latest = b;
      }
    }
    if (latest == null || isZeroQty(latest.quantityBought)) {
      return (quantity: 1, unit: stock.item.defaultUnit);
    }
    return (quantity: roundQty(latest.quantityBought), unit: latest.unit);
  }

  static String _key(String name) => name.trim().toLowerCase();
}
