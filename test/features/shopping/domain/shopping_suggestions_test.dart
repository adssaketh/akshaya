import 'package:akshaya/features/pantry/domain/entities.dart';
import 'package:akshaya/features/pantry/domain/stock_logic.dart';
import 'package:akshaya/features/pantry/domain/storage_location.dart';
import 'package:akshaya/features/pantry/domain/unit.dart';
import 'package:akshaya/features/shopping/domain/shopping_entities.dart';
import 'package:akshaya/features/shopping/domain/shopping_enums.dart';
import 'package:akshaya/features/shopping/domain/shopping_suggestions.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../pantry/domain/test_data.dart';
import 'shopping_test_data.dart';

ItemStock stockOf(Item item, List<StockBatch> batches) {
  return StockLogic.summarize(
    ItemWithBatches(item: item, batches: batches),
    today: kToday,
    warningDays: 3,
  );
}

List<ShoppingSuggestion> suggest(
  List<ItemStock> stocks, {
  List<ShoppingEntry> entries = const <ShoppingEntry>[],
}) {
  return ShoppingSuggestions.compute(
    stocks: stocks,
    entries: entries,
    today: kToday,
  );
}

Item essentialItem() {
  return Item(
    id: 'salt',
    name: 'Salt',
    categoryId: 'cat_spices',
    defaultUnit: Unit.kg,
    aliases: const <String>[],
    isEssential: true,
    defaultStorageLocation: StorageLocation.pantry,
    createdAt: kToday,
    updatedAt: kToday,
  );
}

void main() {
  final DateTime lastWeek = DateTime(2026, 10, 28);
  final DateTime twoDaysAgo = DateTime(2026, 11, 2);
  final DateTime nextMonth = DateTime(2026, 12, 4);

  group('reasons', () {
    test('suggests an item at or below its low-stock level', () {
      final List<ShoppingSuggestion> result = suggest(<ItemStock>[
        stockOf(
          makeItem(threshold: 2),
          <StockBatch>[makeBatch(bought: 5, remaining: 1.5)],
        ),
      ]);

      expect(result, hasLength(1));
      expect(result.single.reason, SuggestionReason.lowStock);
      expect(result.single.usableLeft, 1.5);
      expect(result.single.detail, '1.5 kg left');
    });

    test('the low-stock level itself counts as low', () {
      final List<ShoppingSuggestion> result = suggest(<ItemStock>[
        stockOf(
          makeItem(threshold: 2),
          <StockBatch>[makeBatch(bought: 5, remaining: 2)],
        ),
      ]);

      expect(result.single.reason, SuggestionReason.lowStock);
    });

    test('plenty left: no suggestion', () {
      final List<ShoppingSuggestion> result = suggest(<ItemStock>[
        stockOf(
          makeItem(threshold: 2),
          <StockBatch>[makeBatch(bought: 5, remaining: 3)],
        ),
        // No low-stock level set: never "low".
        stockOf(
          makeItem(id: 'i2', name: 'Salt'),
          <StockBatch>[makeBatch(id: 'b2', itemId: 'i2', remaining: 0.1)],
        ),
      ]);

      expect(result, isEmpty);
    });

    test('suggests an item that ran out', () {
      final List<ShoppingSuggestion> result = suggest(<ItemStock>[
        stockOf(
          makeItem(),
          <StockBatch>[makeBatch(bought: 2, remaining: 0)],
        ),
      ]);

      expect(result.single.reason, SuggestionReason.outOfStock);
      expect(result.single.detail, 'Nothing left');
    });

    test('an item that was never bought is skipped unless essential', () {
      expect(suggest(<ItemStock>[stockOf(makeItem(), const <StockBatch>[])]),
          isEmpty);

      final List<ShoppingSuggestion> result =
          suggest(<ItemStock>[stockOf(essentialItem(), const <StockBatch>[])]);
      expect(result.single.reason, SuggestionReason.outOfStock);
      expect(result.single.quantity, 1);
      expect(result.single.unit, Unit.kg);
    });

    test('suggests an item when everything left is past its date', () {
      final List<ShoppingSuggestion> result = suggest(<ItemStock>[
        stockOf(
          makeItem(name: 'Curd', unit: Unit.l),
          <StockBatch>[
            makeBatch(unit: Unit.l, bought: 1, expiry: twoDaysAgo),
          ],
        ),
      ]);

      expect(result.single.reason, SuggestionReason.expired);
      expect(result.single.item.name, 'Curd');
    });

    test('expired stock does not count towards what is left', () {
      final List<ShoppingSuggestion> result = suggest(<ItemStock>[
        stockOf(
          makeItem(threshold: 1),
          <StockBatch>[
            makeBatch(id: 'old', bought: 3, expiry: twoDaysAgo),
            makeBatch(id: 'new', bought: 1, expiry: nextMonth),
          ],
        ),
      ]);

      expect(result.single.reason, SuggestionReason.lowStock);
      expect(result.single.usableLeft, 1);
    });

    test('expired batch beside plenty of good stock: nothing to buy', () {
      final List<ShoppingSuggestion> result = suggest(<ItemStock>[
        stockOf(
          makeItem(threshold: 1),
          <StockBatch>[
            makeBatch(id: 'old', bought: 1, expiry: twoDaysAgo),
            makeBatch(id: 'new', bought: 4, expiry: nextMonth),
          ],
        ),
      ]);

      expect(result, isEmpty);
    });

    test('an item expiring today is still usable', () {
      final List<ShoppingSuggestion> result = suggest(<ItemStock>[
        stockOf(
          makeItem(threshold: 1),
          <StockBatch>[makeBatch(bought: 4, expiry: kToday)],
        ),
      ]);

      expect(result, isEmpty);
    });

    test('adds up batches in different convertible units', () {
      final List<ShoppingSuggestion> result = suggest(<ItemStock>[
        stockOf(
          makeItem(threshold: 1),
          <StockBatch>[
            makeBatch(id: 'a', unit: Unit.g, bought: 300),
            makeBatch(id: 'b', bought: 0.4),
          ],
        ),
      ]);

      expect(result.single.reason, SuggestionReason.lowStock);
      expect(result.single.usableLeft, 0.7);
    });
  });

  group('what to buy', () {
    test('suggests what was bought last time', () {
      final List<ShoppingSuggestion> result = suggest(<ItemStock>[
        stockOf(
          makeItem(threshold: 1),
          <StockBatch>[
            makeBatch(id: 'a', bought: 2, remaining: 0, purchase: lastWeek),
            makeBatch(
              id: 'b',
              bought: 5,
              remaining: 0.5,
              purchase: DateTime(2026, 11, 1),
            ),
          ],
        ),
      ]);

      expect(result.single.quantity, 5);
      expect(result.single.unit, Unit.kg);
      expect(result.single.quantityLabel, '5 kg');
    });

    test('keeps the unit the last purchase was made in', () {
      final List<ShoppingSuggestion> result = suggest(<ItemStock>[
        stockOf(
          makeItem(threshold: 1),
          <StockBatch>[
            makeBatch(unit: Unit.g, bought: 500, remaining: 100),
          ],
        ),
      ]);

      expect(result.single.quantityLabel, '500 g');
    });

    test('a suggestion becomes an entry with the matching reason', () {
      final ShoppingSuggestion low = suggest(<ItemStock>[
        stockOf(
          makeItem(threshold: 2),
          <StockBatch>[makeBatch(bought: 5, remaining: 1)],
        ),
      ]).single;
      final ShoppingSuggestion out = suggest(<ItemStock>[
        stockOf(makeItem(), <StockBatch>[makeBatch(remaining: 0)]),
      ]).single;
      final ShoppingSuggestion expired = suggest(<ItemStock>[
        stockOf(makeItem(), <StockBatch>[makeBatch(expiry: twoDaysAgo)]),
      ]).single;

      expect(low.toDraft('L').addedReason, AddedReason.lowStock);
      expect(out.toDraft('L').addedReason, AddedReason.lowStock);
      expect(expired.toDraft('L').addedReason, AddedReason.expired);
      expect(low.toDraft('L').itemId, 'i1');
      expect(low.toDraft('L').listId, 'L');
      expect(low.toDraft('L').quantity, 5);
    });
  });

  group('already on a list', () {
    final ItemStock lowRice = stockOf(
      makeItem(threshold: 2),
      <StockBatch>[makeBatch(bought: 5, remaining: 1)],
    );

    test('an entry linked to the item hides the suggestion', () {
      expect(
        suggest(<ItemStock>[lowRice], entries: [makeEntry(itemId: 'i1')]),
        isEmpty,
      );
    });

    test('a free-text entry with the same name hides it too', () {
      expect(
        suggest(<ItemStock>[lowRice], entries: [makeEntry(name: ' rice ')]),
        isEmpty,
      );
    });

    test('a checked entry still counts as on the list', () {
      expect(
        suggest(
          <ItemStock>[lowRice],
          entries: [makeEntry(itemId: 'i1', checked: true)],
        ),
        isEmpty,
      );
    });

    test('an entry for something else does not', () {
      expect(
        suggest(<ItemStock>[lowRice], entries: [makeEntry(name: 'Milk')]),
        hasLength(1),
      );
    });
  });

  test('orders out of stock, expired, then low stock, each by name', () {
    final List<ShoppingSuggestion> result = suggest(<ItemStock>[
      stockOf(
        makeItem(id: 'a', name: 'Atta', threshold: 2),
        <StockBatch>[makeBatch(id: 'ba', itemId: 'a', bought: 5, remaining: 1)],
      ),
      stockOf(
        makeItem(id: 'c', name: 'Curd'),
        <StockBatch>[makeBatch(id: 'bc', itemId: 'c', expiry: twoDaysAgo)],
      ),
      stockOf(
        makeItem(id: 'z', name: 'Zeera'),
        <StockBatch>[makeBatch(id: 'bz', itemId: 'z', remaining: 0)],
      ),
      stockOf(
        makeItem(id: 'b', name: 'Besan'),
        <StockBatch>[makeBatch(id: 'bb', itemId: 'b', remaining: 0)],
      ),
    ]);

    expect(
      result.map((ShoppingSuggestion s) => s.item.name).toList(),
      <String>['Besan', 'Zeera', 'Curd', 'Atta'],
    );
  });
}
