import '../../pantry/domain/entities.dart';
import '../../pantry/domain/stock_logic.dart';

/// Which kind of fresh produce an item is.
enum ProduceKind { vegetable, fruit }

const String _vegetableCategoryId = 'cat_vegetables';
const String _fruitCategoryId = 'cat_fruits';

/// The produce kind of a category, or null when it is not a produce category.
/// Matches the default categories by id, and any category (also one the user
/// made) that uses the vegetables or fruits icon.
ProduceKind? produceKindOfCategory(Category? category, String categoryId) {
  if (categoryId == _vegetableCategoryId ||
      category?.iconKey == 'vegetables') {
    return ProduceKind.vegetable;
  }
  if (categoryId == _fruitCategoryId || category?.iconKey == 'fruits') {
    return ProduceKind.fruit;
  }
  return null;
}

/// Produce stock (optionally only [only]), soonest expiry first, then items
/// with no expiry by name. Items out of stock are listed last so they can be
/// restocked.
List<ItemStock> produceStocks(
  List<ItemStock> stocks,
  Map<String, Category> categories, {
  ProduceKind? only,
}) {
  final List<ItemStock> out = <ItemStock>[
    for (final ItemStock s in stocks)
      if (_matches(s, categories, only)) s,
  ];
  out.sort((ItemStock a, ItemStock b) {
    final bool aIn = a.inStock.isNotEmpty;
    final bool bIn = b.inStock.isNotEmpty;
    if (aIn != bIn) {
      return aIn ? -1 : 1;
    }
    final int? da = a.daysToExpiry;
    final int? db = b.daysToExpiry;
    if (da != db) {
      if (da == null) {
        return 1;
      }
      if (db == null) {
        return -1;
      }
      return da.compareTo(db);
    }
    return a.item.name.toLowerCase().compareTo(b.item.name.toLowerCase());
  });
  return out;
}

bool _matches(
  ItemStock s,
  Map<String, Category> categories,
  ProduceKind? only,
) {
  final ProduceKind? kind = produceKindOfCategory(
    categories[s.item.categoryId],
    s.item.categoryId,
  );
  return kind != null && (only == null || kind == only);
}

/// How many produce items are in stock.
int produceInStockCount(
  List<ItemStock> stocks,
  Map<String, Category> categories,
) {
  int n = 0;
  for (final ItemStock s in produceStocks(stocks, categories)) {
    if (s.inStock.isNotEmpty) {
      n++;
    }
  }
  return n;
}
