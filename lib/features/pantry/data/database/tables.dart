import 'package:drift/drift.dart';

import '../../domain/consumption_type.dart';
import '../../domain/storage_location.dart';
import '../../domain/unit.dart';
import 'converters.dart';
import 'sync_status.dart';

/// Columns every synced table carries (Phase 6 sync reads these):
/// a UUID id, the household the row belongs to (null while local-only), audit
/// timestamps, who last changed it, a soft-delete flag and the local-only
/// sync state.
mixin SyncColumns on Table {
  TextColumn get id => text()();

  TextColumn get householdId => text().nullable()();

  IntColumn get createdAt => integer().map(const EpochMillisConverter())();

  IntColumn get updatedAt => integer().map(const EpochMillisConverter())();

  TextColumn get updatedBy => text().nullable()();

  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  TextColumn get syncStatus =>
      textEnum<SyncStatus>().withDefault(const Constant('pending'))();
}

/// Editable product categories.
@DataClassName('CategoryRow')
class Categories extends Table with SyncColumns {
  TextColumn get name => text().withLength(min: 1, max: 60)();

  TextColumn get iconKey => text()();

  IntColumn get sortOrder => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Product definitions.
@DataClassName('ItemRow')
class Items extends Table with SyncColumns {
  /// Always English, canonical.
  TextColumn get name => text().withLength(min: 1, max: 120)();

  TextColumn get brand => text().nullable()();

  TextColumn get barcode => text().nullable()();

  TextColumn get categoryId => text()();

  TextColumn get defaultUnit => textEnum<Unit>()();

  TextColumn get imagePath => text().nullable()();

  TextColumn get notes => text().nullable()();

  RealColumn get lowStockThreshold => real().nullable()();

  BoolColumn get isEssential => boolean().withDefault(const Constant(false))();

  TextColumn get defaultStorageLocation => textEnum<StorageLocation>()
      .withDefault(const Constant('pantry'))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Other names for an item in any language or script. Rows belong to their
/// item and travel with it when sync arrives (as an `aliases` array on the
/// item document), so they carry no sync columns of their own.
@DataClassName('AliasRow')
@TableIndex(name: 'item_aliases_item_idx', columns: {#itemId})
class ItemAliases extends Table {
  TextColumn get id => text()();

  TextColumn get itemId => text()();

  TextColumn get alias => text().withLength(min: 1, max: 120)();

  IntColumn get createdAt => integer().map(const EpochMillisConverter())();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// One purchase of an item.
@DataClassName('BatchRow')
@TableIndex(name: 'stock_batches_item_idx', columns: {#itemId})
class StockBatches extends Table with SyncColumns {
  TextColumn get itemId => text()();

  RealColumn get quantityBought => real()();

  RealColumn get quantityRemaining => real()();

  TextColumn get unit => textEnum<Unit>()();

  TextColumn get purchaseDate => text().map(const DateOnlyConverter())();

  TextColumn get expiryDate =>
      text().map(const DateOnlyConverter()).nullable()();

  TextColumn get openedDate =>
      text().map(const DateOnlyConverter()).nullable()();

  IntColumn get useWithinDaysAfterOpening => integer().nullable()();

  /// Total price paid for the batch, in rupees.
  RealColumn get price => real().nullable()();

  TextColumn get store => text().nullable()();

  TextColumn get storageLocation => textEnum<StorageLocation>()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Every time stock leaves a batch.
@DataClassName('ConsumptionLogRow')
@TableIndex(name: 'consumption_logs_item_idx', columns: {#itemId})
class ConsumptionLogs extends Table with SyncColumns {
  TextColumn get batchId => text()();

  /// Denormalised from the batch so an item's history needs no join.
  TextColumn get itemId => text()();

  /// Amount that left the batch, in [unit] (the batch's unit).
  RealColumn get quantityUsed => real()();

  TextColumn get unit => textEnum<Unit>()();

  IntColumn get date => integer().map(const EpochMillisConverter())();

  TextColumn get type => textEnum<ConsumptionType>()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
