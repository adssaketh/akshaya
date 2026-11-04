import 'dart:async';

import 'package:akshaya/features/pantry/domain/default_categories.dart';
import 'package:akshaya/features/pantry/domain/entities.dart';
import 'package:akshaya/features/pantry/domain/pantry_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../domain/test_data.dart';

/// In-memory repository for widget tests. Only the methods the screens under
/// test call are implemented; anything else throws via [Fake].
class FakePantryRepository extends Fake implements PantryRepository {
  FakePantryRepository({List<ItemWithBatches> items = const <ItemWithBatches>[]})
      : _items = List<ItemWithBatches>.of(items);

  final List<ItemWithBatches> _items;
  final List<ItemDraft> addedItems = <ItemDraft>[];
  final List<BatchDraft> addedBatches = <BatchDraft>[];

  /// Barcode to item id, answered by [findItemByBarcode].
  final Map<String, String> barcodes = <String, String>{};

  /// Every (itemId, barcode) passed to [addBarcode].
  final List<(String, String)> addedBarcodes = <(String, String)>[];

  static final List<Category> categories = <Category>[
    for (int i = 0; i < kDefaultCategories.length; i++)
      Category(
        id: kDefaultCategories[i].id,
        name: kDefaultCategories[i].name,
        iconKey: kDefaultCategories[i].iconKey,
        sortOrder: i,
      ),
  ];

  @override
  Stream<List<ItemWithBatches>> watchItems() =>
      Stream<List<ItemWithBatches>>.value(List<ItemWithBatches>.of(_items));

  @override
  Stream<List<Category>> watchCategories() =>
      Stream<List<Category>>.value(categories);

  @override
  Future<Item?> findItemByName(String name) async {
    for (final ItemWithBatches r in _items) {
      if (r.item.name.toLowerCase() == name.toLowerCase()) {
        return r.item;
      }
    }
    return null;
  }

  @override
  Future<Item?> findItemByBarcode(String barcode) async {
    final String? id = barcodes[barcode];
    if (id == null) {
      return null;
    }
    for (final ItemWithBatches r in _items) {
      if (r.item.id == id) {
        return r.item;
      }
    }
    return null;
  }

  @override
  Future<void> addBarcode(String itemId, String barcode) async {
    addedBarcodes.add((itemId, barcode));
    barcodes[barcode] = itemId;
  }

  @override
  Future<Item> addItem(ItemDraft draft) async {
    addedItems.add(draft);
    return makeItem(
      id: 'new-${addedItems.length}',
      name: draft.name,
      unit: draft.defaultUnit,
    );
  }

  @override
  Future<StockBatch> addBatch(BatchDraft draft) async {
    addedBatches.add(draft);
    return makeBatch(itemId: draft.itemId, bought: draft.quantityBought);
  }
}
