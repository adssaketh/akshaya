import 'package:drift/drift.dart';

import '../../../pantry/data/database/converters.dart';

/// Every barcode an item answers to. One item can have several (different
/// pack sizes or brands of the same thing); a barcode belongs to one item.
///
/// Like aliases, rows belong to their item and travel with it when sync
/// arrives, so they carry no sync columns of their own. A barcode is not
/// unique at the database level because a deleted item keeps its rows (so
/// Undo works); the repository only looks at rows of live items.
@DataClassName('ItemBarcodeRow')
@TableIndex(name: 'item_barcodes_barcode_idx', columns: {#barcode})
@TableIndex(name: 'item_barcodes_item_idx', columns: {#itemId})
class ItemBarcodes extends Table {
  TextColumn get id => text()();

  TextColumn get itemId => text()();

  /// Canonical digits (see `canonicalBarcode`).
  TextColumn get barcode => text().withLength(min: 1, max: 64)();

  IntColumn get createdAt => integer().map(const EpochMillisConverter())();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Local cache of Open Food Facts answers, so a product is looked up once.
/// Local only: it never syncs.
@DataClassName('ProductCacheRow')
class ProductCache extends Table {
  TextColumn get barcode => text()();

  /// False when Open Food Facts answered that it does not know the barcode.
  BoolColumn get found => boolean()();

  /// `ProductInfo.toJson` as text; null when [found] is false.
  TextColumn get payload => text().nullable()();

  IntColumn get fetchedAt => integer().map(const EpochMillisConverter())();

  @override
  Set<Column<Object>> get primaryKey => {barcode};
}
