import 'package:drift/drift.dart' hide Batch;
import 'package:uuid/uuid.dart';

import '../../../core/util/barcode.dart';
import '../../../core/util/date_only.dart';
import '../../../core/util/quantity.dart';
import '../domain/consumption_type.dart';
import '../domain/default_categories.dart';
import '../domain/entities.dart';
import '../domain/failures.dart';
import '../domain/fifo.dart';
import '../domain/item_kind.dart';
import '../domain/pantry_repository.dart';
import '../domain/sample_data.dart';
import '../domain/shelf_life.dart';
import '../domain/stock_count.dart';
import '../domain/storage_location.dart';
import '../domain/unit.dart';
import '../domain/waste_reason.dart';
import 'database/app_database.dart';
import 'database/sync_status.dart';

/// [PantryRepository] backed by the local Drift database.
///
/// Every write goes to the database first and marks the row `pending`, ready
/// for Phase 6 sync to push. Deletes are soft (`isDeleted`).
class DriftPantryRepository implements PantryRepository {
  DriftPantryRepository(
    this._db, {
    DateTime Function()? clock,
    String Function()? idGenerator,
    String? currentUserId,
  })  : _clock = clock ?? DateTime.now,
        _newId = idGenerator ?? _uuidV4,
        _userId = currentUserId;

  final AppDatabase _db;
  final DateTime Function() _clock;
  final String Function() _newId;
  final String? _userId;

  static String _uuidV4() => const Uuid().v4();

  DateTime _now() => _clock();

  // ---------------------------------------------------------------------
  // Mapping
  // ---------------------------------------------------------------------

  Category _category(CategoryRow r) {
    return Category(
      id: r.id,
      name: r.name,
      iconKey: r.iconKey,
      sortOrder: r.sortOrder,
    );
  }

  Item _item(ItemRow r, List<String> aliases) {
    return Item(
      id: r.id,
      name: r.name,
      brand: r.brand,
      barcode: r.barcode,
      categoryId: r.categoryId,
      defaultUnit: r.defaultUnit,
      imagePath: r.imagePath,
      notes: r.notes,
      aliases: aliases,
      lowStockThreshold: r.lowStockThreshold,
      isEssential: r.isEssential,
      defaultStorageLocation: r.defaultStorageLocation,
      createdAt: r.createdAt,
      updatedAt: r.updatedAt,
      kind: r.kind ?? ItemKind.stocked,
      shelfLifeDays: r.shelfLifeDays,
    );
  }

  StockBatch _batch(BatchRow r) {
    return StockBatch(
      id: r.id,
      itemId: r.itemId,
      quantityBought: r.quantityBought,
      quantityRemaining: r.quantityRemaining,
      unit: r.unit,
      purchaseDate: r.purchaseDate,
      expiryDate: r.expiryDate,
      openedDate: r.openedDate,
      useWithinDaysAfterOpening: r.useWithinDaysAfterOpening,
      price: r.price,
      store: r.store,
      storageLocation: r.storageLocation,
      createdAt: r.createdAt,
      containerLabel: r.containerLabel,
      checkBy: r.checkBy,
    );
  }

  ConsumptionEntry _log(ConsumptionLogRow r) {
    return ConsumptionEntry(
      id: r.id,
      batchId: r.batchId,
      itemId: r.itemId,
      quantityUsed: r.quantityUsed,
      unit: r.unit,
      date: r.date,
      type: r.type,
      wasteReason: r.wasteReason,
    );
  }

  // ---------------------------------------------------------------------
  // Streams
  // ---------------------------------------------------------------------

  @override
  Stream<List<ItemWithBatches>> watchItems() {
    // One trigger query over every table the result depends on; each emission
    // reloads the (small) household dataset.
    return _db
        .customSelect(
          'SELECT 1',
          readsFrom: {_db.items, _db.stockBatches, _db.itemAliases},
        )
        .watch()
        .asyncMap((_) => _loadAll());
  }

  Future<List<ItemWithBatches>> _loadAll() async {
    final List<ItemRow> itemRows = await (_db.select(_db.items)
          ..where((t) => t.isDeleted.equals(false)))
        .get();
    final List<BatchRow> batchRows = await (_db.select(_db.stockBatches)
          ..where((t) => t.isDeleted.equals(false)))
        .get();
    final List<AliasRow> aliasRows = await (_db.select(_db.itemAliases)
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();

    final Map<String, List<String>> aliasesByItem = <String, List<String>>{};
    for (final AliasRow a in aliasRows) {
      aliasesByItem.putIfAbsent(a.itemId, () => <String>[]).add(a.alias);
    }
    final Map<String, List<StockBatch>> batchesByItem =
        <String, List<StockBatch>>{};
    for (final BatchRow b in batchRows) {
      batchesByItem.putIfAbsent(b.itemId, () => <StockBatch>[]).add(_batch(b));
    }

    return <ItemWithBatches>[
      for (final ItemRow r in itemRows)
        ItemWithBatches(
          item: _item(r, aliasesByItem[r.id] ?? const <String>[]),
          batches: batchesByItem[r.id] ?? const <StockBatch>[],
        ),
    ];
  }

  @override
  Stream<List<Category>> watchCategories() {
    final SimpleSelectStatement<$CategoriesTable, CategoryRow> query =
        _db.select(_db.categories)
          ..where((t) => t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]);
    return query.watch().map(
          (List<CategoryRow> rows) => rows.map(_category).toList(),
        );
  }

  @override
  Stream<List<ConsumptionEntry>> watchHistory(String itemId) {
    final SimpleSelectStatement<$ConsumptionLogsTable, ConsumptionLogRow>
        query = _db.select(_db.consumptionLogs)
          ..where((t) => t.itemId.equals(itemId) & t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm.desc(t.date)]);
    return query.watch().map(
          (List<ConsumptionLogRow> rows) => rows.map(_log).toList(),
        );
  }

  @override
  Stream<List<ConsumptionEntry>> watchAllHistory() {
    final SimpleSelectStatement<$ConsumptionLogsTable, ConsumptionLogRow>
        query = _db.select(_db.consumptionLogs)
          ..where((t) => t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm.desc(t.date)]);
    return query.watch().map(
          (List<ConsumptionLogRow> rows) => rows.map(_log).toList(),
        );
  }

  // ---------------------------------------------------------------------
  // Categories
  // ---------------------------------------------------------------------

  String _categoryName(String name) {
    final String clean = name.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (clean.isEmpty) {
      throw const InvalidInputFailure('Give the category a name.');
    }
    if (clean.length > 60) {
      throw const InvalidInputFailure('That name is too long (60 letters).');
    }
    return clean;
  }

  Future<bool> _categoryNameTaken(String name, {String? exceptId}) async {
    final List<CategoryRow> rows = await (_db.select(_db.categories)
          ..where((t) => t.isDeleted.equals(false)))
        .get();
    final String wanted = name.toLowerCase();
    for (final CategoryRow r in rows) {
      if (r.id != exceptId && r.name.toLowerCase() == wanted) {
        return true;
      }
    }
    return false;
  }

  @override
  Future<Category> addCategory({
    required String name,
    required String iconKey,
  }) {
    final String clean = _categoryName(name);
    return _db.transaction<Category>(() async {
      if (await _categoryNameTaken(clean)) {
        throw InvalidInputFailure('"$clean" already exists.');
      }
      final List<CategoryRow> rows = await (_db.select(_db.categories)
            ..where((t) => t.isDeleted.equals(false)))
          .get();
      int last = -1;
      for (final CategoryRow r in rows) {
        if (r.sortOrder > last) {
          last = r.sortOrder;
        }
      }
      final String id = _newId();
      final DateTime now = _now();
      await _db.into(_db.categories).insert(
            CategoriesCompanion.insert(
              id: id,
              name: clean,
              iconKey: iconKey,
              sortOrder: last + 1,
              createdAt: now,
              updatedAt: now,
              updatedBy: Value<String?>(_userId),
            ),
          );
      return Category(id: id, name: clean, iconKey: iconKey, sortOrder: last + 1);
    });
  }

  @override
  Future<void> updateCategory({
    required String id,
    required String name,
    required String iconKey,
  }) {
    final String clean = _categoryName(name);
    return _db.transaction<void>(() async {
      if (await _categoryNameTaken(clean, exceptId: id)) {
        throw InvalidInputFailure('"$clean" already exists.');
      }
      await (_db.update(_db.categories)..where((t) => t.id.equals(id))).write(
        CategoriesCompanion(
          name: Value<String>(clean),
          iconKey: Value<String>(iconKey),
          updatedAt: Value<DateTime>(_now()),
          updatedBy: Value<String?>(_userId),
        ),
      );
    });
  }

  @override
  Future<void> deleteCategory(String id) {
    return _db.transaction<void>(() async {
      if (id == kDefaultCategoryId) {
        throw const InvalidInputFailure('"Other" cannot be removed.');
      }
      final List<ItemRow> used = await (_db.select(_db.items)
            ..where((t) => t.categoryId.equals(id) & t.isDeleted.equals(false)))
          .get();
      if (used.isNotEmpty) {
        throw InvalidInputFailure(
          used.length == 1
              ? '1 item still uses this category. Move it first.'
              : '${used.length} items still use this category. Move them first.',
        );
      }
      await (_db.update(_db.categories)..where((t) => t.id.equals(id))).write(
        CategoriesCompanion(
          isDeleted: const Value<bool>(true),
          updatedAt: Value<DateTime>(_now()),
          updatedBy: Value<String?>(_userId),
        ),
      );
    });
  }

  // ---------------------------------------------------------------------
  // Lookups
  // ---------------------------------------------------------------------

  Future<ItemRow?> _itemRow(String id) {
    return (_db.select(_db.items)
          ..where((t) => t.id.equals(id) & t.isDeleted.equals(false)))
        .getSingleOrNull();
  }

  Future<ItemRow> _requireItem(String id) async {
    final ItemRow? row = await _itemRow(id);
    if (row == null) {
      throw const NotFoundFailure('This item no longer exists.');
    }
    return row;
  }

  Future<ItemRow?> _itemRowByName(String name, {String? excludeId}) {
    final String needle = _cleanName(name).toLowerCase();
    return (_db.select(_db.items)
          ..where((t) {
            Expression<bool> condition =
                t.isDeleted.equals(false) & t.name.lower().equals(needle);
            if (excludeId != null) {
              condition = condition & t.id.equals(excludeId).not();
            }
            return condition;
          })
          ..limit(1))
        .getSingleOrNull();
  }

  /// The live item that answers to [barcode] under any spelling of the code.
  Future<ItemRow?> _itemRowByBarcode(String barcode, {String? excludeId}) async {
    Expression<bool> condition = _db.items.isDeleted.equals(false) &
        _db.itemBarcodes.barcode.isIn(barcodeVariants(barcode));
    if (excludeId != null) {
      condition = condition & _db.items.id.equals(excludeId).not();
    }
    final query = _db.select(_db.items).join([
      innerJoin(
        _db.itemBarcodes,
        _db.itemBarcodes.itemId.equalsExp(_db.items.id),
      ),
    ])
      ..where(condition)
      ..limit(1);
    final List<TypedResult> rows = await query.get();
    return rows.isEmpty ? null : rows.first.readTable(_db.items);
  }

  Future<ItemBarcodeRow?> _barcodeRow(String itemId, String barcode) {
    return (_db.select(_db.itemBarcodes)
          ..where(
            (t) => t.itemId.equals(itemId) & t.barcode.isIn(barcodeVariants(barcode)),
          )
          ..limit(1))
        .getSingleOrNull();
  }

  Future<void> _insertBarcode(String itemId, String barcode, DateTime now) {
    return _db.into(_db.itemBarcodes).insert(
          ItemBarcodesCompanion.insert(
            id: _newId(),
            itemId: itemId,
            barcode: barcode,
            createdAt: now,
          ),
        );
  }

  /// Keeps `item_barcodes` in step with an item's main barcode: the previous
  /// main barcode stops identifying the item and the new one starts.
  Future<void> _syncMainBarcode(
    String itemId, {
    required String? previous,
    required String? current,
    required DateTime now,
  }) async {
    if (previous == current) {
      return;
    }
    if (previous != null) {
      await (_db.delete(_db.itemBarcodes)
            ..where(
              (t) =>
                  t.itemId.equals(itemId) &
                  t.barcode.isIn(barcodeVariants(previous)),
            ))
          .go();
    }
    if (current != null && await _barcodeRow(itemId, current) == null) {
      await _insertBarcode(itemId, current, now);
    }
  }

  Future<List<String>> _aliasesOf(String itemId) async {
    final List<AliasRow> rows = await (_db.select(_db.itemAliases)
          ..where((t) => t.itemId.equals(itemId))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
    return <String>[for (final AliasRow r in rows) r.alias];
  }

  Future<List<BatchRow>> _activeBatchRows(String itemId) {
    return (_db.select(_db.stockBatches)
          ..where((t) => t.itemId.equals(itemId) & t.isDeleted.equals(false)))
        .get();
  }

  Future<BatchRow?> _batchRow(String id, {bool includeDeleted = false}) {
    return (_db.select(_db.stockBatches)
          ..where((t) {
            final Expression<bool> sameId = t.id.equals(id);
            return includeDeleted ? sameId : sameId & t.isDeleted.equals(false);
          }))
        .getSingleOrNull();
  }

  @override
  Future<Item?> findItemByName(String name) async {
    final ItemRow? row = await _itemRowByName(name);
    return row == null ? null : _item(row, await _aliasesOf(row.id));
  }

  @override
  Future<void> addBarcode(String itemId, String barcode) async {
    final String code = canonicalBarcode(barcode);
    if (code.isEmpty) {
      throw const InvalidInputFailure('Enter a barcode.');
    }
    await _db.transaction<void>(() async {
      final ItemRow item = await _requireItem(itemId);
      final ItemRow? owner = await _itemRowByBarcode(code);
      if (owner != null) {
        if (owner.id == itemId) {
          return;
        }
        throw DuplicateBarcodeFailure(
          existingItemId: owner.id,
          itemName: owner.name,
        );
      }

      final DateTime now = _now();
      await _insertBarcode(itemId, code, now);
      await (_db.update(_db.items)..where((t) => t.id.equals(itemId))).write(
        ItemsCompanion(
          // The first barcode an item gets is its main one.
          barcode: item.barcode == null
              ? Value<String?>(code)
              : const Value<String?>.absent(),
          updatedAt: Value<DateTime>(now),
          updatedBy: Value<String?>(_userId),
          syncStatus: const Value<SyncStatus>(SyncStatus.pending),
        ),
      );
    });
  }

  @override
  Future<Item?> findItemByBarcode(String barcode) async {
    final String cleaned = barcode.trim();
    if (cleaned.isEmpty) {
      return null;
    }
    final ItemRow? row = await _itemRowByBarcode(cleaned);
    return row == null ? null : _item(row, await _aliasesOf(row.id));
  }

  // ---------------------------------------------------------------------
  // Cleaning and validation
  // ---------------------------------------------------------------------

  String _cleanName(String text) {
    return text.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// A barcode in canonical form, or null when there is none.
  String? _cleanBarcode(String? text) {
    final String? cleaned = _cleanOptional(text);
    return cleaned == null ? null : canonicalBarcode(cleaned);
  }

  String? _cleanOptional(String? text) {
    if (text == null) {
      return null;
    }
    final String cleaned = text.trim();
    return cleaned.isEmpty ? null : cleaned;
  }

  List<String> _cleanAliases(List<String> aliases, String itemName) {
    final Set<String> seen = <String>{itemName.toLowerCase()};
    final List<String> result = <String>[];
    for (final String raw in aliases) {
      final String alias = _cleanName(raw);
      if (alias.isEmpty) {
        continue;
      }
      if (seen.add(alias.toLowerCase())) {
        result.add(alias);
      }
    }
    return result;
  }

  void _validateItem({
    required String name,
    required double? threshold,
    int? shelfLifeDays,
  }) {
    if (shelfLifeDays != null &&
        (shelfLifeDays < 1 || shelfLifeDays > ShelfLife.maxDays)) {
      throw InvalidInputFailure(
        'Shelf life must be between 1 and ${ShelfLife.maxDays} days.',
      );
    }
    if (name.isEmpty) {
      throw const InvalidInputFailure('Enter a name for the item.');
    }
    if (name.length > 120) {
      throw const InvalidInputFailure('The name is too long.');
    }
    if (threshold != null && (!threshold.isFinite || threshold < 0)) {
      throw const InvalidInputFailure(
        'Low-stock level cannot be negative.',
      );
    }
  }

  void _validateBatch({
    required double quantityBought,
    required double quantityRemaining,
    required Unit unit,
    required Unit itemUnit,
    required double? price,
    required int? useWithinDays,
  }) {
    if (!quantityBought.isFinite || quantityBought <= 0) {
      throw const InvalidInputFailure('Enter a quantity greater than zero.');
    }
    if (!quantityRemaining.isFinite || quantityRemaining < 0) {
      throw const InvalidInputFailure('Remaining quantity cannot be negative.');
    }
    if (roundQty(quantityRemaining) > roundQty(quantityBought)) {
      throw const InvalidInputFailure(
        'Remaining quantity cannot be more than the quantity bought.',
      );
    }
    if (!unit.isCompatibleWith(itemUnit)) {
      throw UnitMismatchFailure(unit.symbol, itemUnit.symbol);
    }
    if (price != null && (!price.isFinite || price < 0)) {
      throw const InvalidInputFailure('Price cannot be negative.');
    }
    if (useWithinDays != null && useWithinDays < 1) {
      throw const InvalidInputFailure(
        'Use-within days must be at least 1.',
      );
    }
  }

  // ---------------------------------------------------------------------
  // Items
  // ---------------------------------------------------------------------

  @override
  Future<Item> addItem(ItemDraft draft) async {
    final String name = _cleanName(draft.name);
    _validateItem(
      name: name,
      threshold: draft.lowStockThreshold,
      shelfLifeDays: draft.shelfLifeDays,
    );

    return _db.transaction<Item>(() async {
      final ItemRow? duplicate = await _itemRowByName(name);
      if (duplicate != null) {
        throw DuplicateItemFailure(
          existingItemId: duplicate.id,
          name: duplicate.name,
        );
      }
      final String? barcode = _cleanBarcode(draft.barcode);
      if (barcode != null) {
        final ItemRow? sameBarcode = await _itemRowByBarcode(barcode);
        if (sameBarcode != null) {
          throw DuplicateBarcodeFailure(
            existingItemId: sameBarcode.id,
            itemName: sameBarcode.name,
          );
        }
      }

      final String id = _newId();
      final DateTime now = _now();
      final List<String> aliases = _cleanAliases(draft.aliases, name);

      await _db.into(_db.items).insert(
            ItemsCompanion.insert(
              id: id,
              name: name,
              categoryId: draft.categoryId,
              defaultUnit: draft.defaultUnit,
              createdAt: now,
              updatedAt: now,
              brand: Value<String?>(_cleanOptional(draft.brand)),
              barcode: Value<String?>(barcode),
              imagePath: Value<String?>(draft.imagePath),
              notes: Value<String?>(_cleanOptional(draft.notes)),
              lowStockThreshold: Value<double?>(draft.lowStockThreshold),
              isEssential: Value<bool>(draft.isEssential),
              defaultStorageLocation:
                  Value<StorageLocation>(draft.defaultStorageLocation),
              kind: Value<ItemKind?>(draft.kind.isStocked ? null : draft.kind),
              shelfLifeDays: Value<int?>(draft.shelfLifeDays),
              updatedBy: Value<String?>(_userId),
            ),
          );
      await _replaceAliases(id, aliases, now);
      if (barcode != null) {
        await _insertBarcode(id, barcode, now);
      }

      return Item(
        id: id,
        name: name,
        brand: _cleanOptional(draft.brand),
        barcode: barcode,
        categoryId: draft.categoryId,
        defaultUnit: draft.defaultUnit,
        imagePath: draft.imagePath,
        notes: _cleanOptional(draft.notes),
        aliases: aliases,
        lowStockThreshold: draft.lowStockThreshold,
        isEssential: draft.isEssential,
        defaultStorageLocation: draft.defaultStorageLocation,
        createdAt: now,
        updatedAt: now,
        kind: draft.kind,
        shelfLifeDays: draft.shelfLifeDays,
      );
    });
  }

  Future<void> _replaceAliases(
    String itemId,
    List<String> aliases,
    DateTime now,
  ) async {
    await (_db.delete(_db.itemAliases)..where((t) => t.itemId.equals(itemId)))
        .go();
    for (int i = 0; i < aliases.length; i++) {
      await _db.into(_db.itemAliases).insert(
            ItemAliasesCompanion.insert(
              id: _newId(),
              itemId: itemId,
              alias: aliases[i],
              // Keep list order: each alias is one millisecond after the last.
              createdAt: now.add(Duration(milliseconds: i)),
            ),
          );
    }
  }

  @override
  Future<Item> updateItem(Item item) async {
    final String name = _cleanName(item.name);
    _validateItem(
      name: name,
      threshold: item.lowStockThreshold,
      shelfLifeDays: item.shelfLifeDays,
    );

    return _db.transaction<Item>(() async {
      final ItemRow existing = await _requireItem(item.id);

      final ItemRow? duplicate =
          await _itemRowByName(name, excludeId: item.id);
      if (duplicate != null) {
        throw DuplicateItemFailure(
          existingItemId: duplicate.id,
          name: duplicate.name,
        );
      }
      final String? barcode = _cleanBarcode(item.barcode);
      if (barcode != null) {
        final ItemRow? sameBarcode =
            await _itemRowByBarcode(barcode, excludeId: item.id);
        if (sameBarcode != null) {
          throw DuplicateBarcodeFailure(
            existingItemId: sameBarcode.id,
            itemName: sameBarcode.name,
          );
        }
      }
      if (item.defaultUnit != existing.defaultUnit) {
        final List<BatchRow> batches = await _activeBatchRows(item.id);
        for (final BatchRow b in batches) {
          if (!b.unit.isCompatibleWith(item.defaultUnit)) {
            throw InvalidInputFailure(
              'This item has stock in ${b.unit.symbol}, which cannot be '
              'converted to ${item.defaultUnit.symbol}.',
            );
          }
        }
      }

      final DateTime now = _now();
      final List<String> aliases = _cleanAliases(item.aliases, name);

      await (_db.update(_db.items)..where((t) => t.id.equals(item.id))).write(
        ItemsCompanion(
          name: Value<String>(name),
          brand: Value<String?>(_cleanOptional(item.brand)),
          barcode: Value<String?>(barcode),
          categoryId: Value<String>(item.categoryId),
          defaultUnit: Value<Unit>(item.defaultUnit),
          imagePath: Value<String?>(item.imagePath),
          notes: Value<String?>(_cleanOptional(item.notes)),
          lowStockThreshold: Value<double?>(item.lowStockThreshold),
          isEssential: Value<bool>(item.isEssential),
          defaultStorageLocation:
              Value<StorageLocation>(item.defaultStorageLocation),
          kind: Value<ItemKind?>(item.kind.isStocked ? null : item.kind),
          shelfLifeDays: Value<int?>(item.shelfLifeDays),
          updatedAt: Value<DateTime>(now),
          updatedBy: Value<String?>(_userId),
          syncStatus: const Value<SyncStatus>(SyncStatus.pending),
        ),
      );
      await _replaceAliases(item.id, aliases, now);
      await _syncMainBarcode(
        item.id,
        previous: existing.barcode,
        current: barcode,
        now: now,
      );

      return Item(
        id: item.id,
        name: name,
        brand: _cleanOptional(item.brand),
        barcode: barcode,
        categoryId: item.categoryId,
        defaultUnit: item.defaultUnit,
        imagePath: item.imagePath,
        notes: _cleanOptional(item.notes),
        aliases: aliases,
        lowStockThreshold: item.lowStockThreshold,
        isEssential: item.isEssential,
        defaultStorageLocation: item.defaultStorageLocation,
        createdAt: existing.createdAt,
        updatedAt: now,
        kind: item.kind,
        shelfLifeDays: item.shelfLifeDays,
      );
    });
  }

  @override
  Future<DeleteToken> deleteItem(String itemId) {
    return _db.transaction<DeleteToken>(() async {
      await _requireItem(itemId);
      final DateTime now = _now();

      final List<BatchRow> batches = await _activeBatchRows(itemId);
      final List<String> batchIds = <String>[
        for (final BatchRow b in batches) b.id,
      ];
      for (final String batchId in batchIds) {
        await _setBatchDeleted(batchId, deleted: true, now: now);
      }
      await _setItemDeleted(itemId, deleted: true, now: now);

      return DeleteToken(itemId: itemId, batchIds: batchIds);
    });
  }

  @override
  Future<void> undoDeleteItem(DeleteToken token) {
    return _db.transaction<void>(() async {
      final DateTime now = _now();
      await _setItemDeleted(token.itemId, deleted: false, now: now);
      for (final String batchId in token.batchIds) {
        await _setBatchDeleted(batchId, deleted: false, now: now);
      }
    });
  }

  Future<void> _setItemDeleted(
    String id, {
    required bool deleted,
    required DateTime now,
  }) async {
    await (_db.update(_db.items)..where((t) => t.id.equals(id))).write(
      ItemsCompanion(
        isDeleted: Value<bool>(deleted),
        updatedAt: Value<DateTime>(now),
        updatedBy: Value<String?>(_userId),
        syncStatus: const Value<SyncStatus>(SyncStatus.pending),
      ),
    );
  }

  Future<void> _setBatchDeleted(
    String id, {
    required bool deleted,
    required DateTime now,
  }) async {
    await (_db.update(_db.stockBatches)..where((t) => t.id.equals(id))).write(
      StockBatchesCompanion(
        isDeleted: Value<bool>(deleted),
        updatedAt: Value<DateTime>(now),
        updatedBy: Value<String?>(_userId),
        syncStatus: const Value<SyncStatus>(SyncStatus.pending),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Batches
  // ---------------------------------------------------------------------

  @override
  Future<StockBatch> addBatch(BatchDraft draft) {
    return _db.transaction<StockBatch>(() async {
      final ItemRow item = await _requireItem(draft.itemId);
      final double remaining = draft.quantityRemaining ?? draft.quantityBought;
      _validateBatch(
        quantityBought: draft.quantityBought,
        quantityRemaining: remaining,
        unit: draft.unit,
        itemUnit: item.defaultUnit,
        price: draft.price,
        useWithinDays: draft.useWithinDaysAfterOpening,
      );

      final String id = _newId();
      final DateTime now = _now();
      final double bought = roundQty(draft.quantityBought);
      final double left = roundQty(remaining);
      final DateTime purchaseDate = dateOnly(draft.purchaseDate);
      final DateTime? expiry = _dateOrNull(draft.expiryDate);
      final DateTime? opened = _dateOrNull(draft.openedDate);
      final String? store = _cleanOptional(draft.store);
      final String? container = _cleanOptional(draft.containerLabel);
      final DateTime? checkBy = _dateOrNull(draft.checkBy);

      await _db.into(_db.stockBatches).insert(
            StockBatchesCompanion.insert(
              id: id,
              itemId: draft.itemId,
              quantityBought: bought,
              quantityRemaining: left,
              unit: draft.unit,
              purchaseDate: purchaseDate,
              storageLocation: draft.storageLocation,
              createdAt: now,
              updatedAt: now,
              expiryDate: Value<DateTime?>(expiry),
              openedDate: Value<DateTime?>(opened),
              useWithinDaysAfterOpening:
                  Value<int?>(draft.useWithinDaysAfterOpening),
              price: Value<double?>(draft.price),
              store: Value<String?>(store),
              containerLabel: Value<String?>(container),
              checkBy: Value<DateTime?>(checkBy),
              updatedBy: Value<String?>(_userId),
            ),
          );

      return StockBatch(
        id: id,
        itemId: draft.itemId,
        quantityBought: bought,
        quantityRemaining: left,
        unit: draft.unit,
        purchaseDate: purchaseDate,
        expiryDate: expiry,
        openedDate: opened,
        useWithinDaysAfterOpening: draft.useWithinDaysAfterOpening,
        price: draft.price,
        store: store,
        storageLocation: draft.storageLocation,
        createdAt: now,
        containerLabel: container,
        checkBy: checkBy,
      );
    });
  }

  DateTime? _dateOrNull(DateTime? value) {
    return value == null ? null : dateOnly(value);
  }

  @override
  Future<StockBatch> updateBatch(StockBatch batch) {
    return _db.transaction<StockBatch>(() async {
      final BatchRow? existing = await _batchRow(batch.id);
      if (existing == null) {
        throw const NotFoundFailure('This batch no longer exists.');
      }
      final ItemRow item = await _requireItem(existing.itemId);
      _validateBatch(
        quantityBought: batch.quantityBought,
        quantityRemaining: batch.quantityRemaining,
        unit: batch.unit,
        itemUnit: item.defaultUnit,
        price: batch.price,
        useWithinDays: batch.useWithinDaysAfterOpening,
      );

      final DateTime now = _now();
      final double bought = roundQty(batch.quantityBought);
      final double left = roundQty(batch.quantityRemaining);
      final DateTime purchaseDate = dateOnly(batch.purchaseDate);
      final DateTime? expiry = _dateOrNull(batch.expiryDate);
      final DateTime? opened = _dateOrNull(batch.openedDate);
      final String? store = _cleanOptional(batch.store);
      final String? container = _cleanOptional(batch.containerLabel);
      final DateTime? checkBy = _dateOrNull(batch.checkBy);

      await (_db.update(_db.stockBatches)
            ..where((t) => t.id.equals(batch.id)))
          .write(
        StockBatchesCompanion(
          quantityBought: Value<double>(bought),
          quantityRemaining: Value<double>(left),
          unit: Value<Unit>(batch.unit),
          purchaseDate: Value<DateTime>(purchaseDate),
          expiryDate: Value<DateTime?>(expiry),
          openedDate: Value<DateTime?>(opened),
          useWithinDaysAfterOpening:
              Value<int?>(batch.useWithinDaysAfterOpening),
          price: Value<double?>(batch.price),
          store: Value<String?>(store),
          storageLocation: Value<StorageLocation>(batch.storageLocation),
          containerLabel: Value<String?>(container),
          checkBy: Value<DateTime?>(checkBy),
          updatedAt: Value<DateTime>(now),
          updatedBy: Value<String?>(_userId),
          syncStatus: const Value<SyncStatus>(SyncStatus.pending),
        ),
      );

      return StockBatch(
        id: batch.id,
        itemId: existing.itemId,
        quantityBought: bought,
        quantityRemaining: left,
        unit: batch.unit,
        purchaseDate: purchaseDate,
        expiryDate: expiry,
        openedDate: opened,
        useWithinDaysAfterOpening: batch.useWithinDaysAfterOpening,
        price: batch.price,
        store: store,
        storageLocation: batch.storageLocation,
        createdAt: existing.createdAt,
        containerLabel: container,
        checkBy: checkBy,
      );
    });
  }

  @override
  Future<void> deleteBatch(String batchId) {
    return _db.transaction<void>(() async {
      final BatchRow? row = await _batchRow(batchId);
      if (row == null) {
        throw const NotFoundFailure('This batch no longer exists.');
      }
      await _setBatchDeleted(batchId, deleted: true, now: _now());
    });
  }

  @override
  Future<void> undoDeleteBatch(String batchId) {
    return _db.transaction<void>(() async {
      await _setBatchDeleted(batchId, deleted: false, now: _now());
    });
  }

  // ---------------------------------------------------------------------
  // Using up stock
  // ---------------------------------------------------------------------

  @override
  Future<UseResult> useStock({
    required String itemId,
    required double quantity,
    required Unit unit,
    ConsumptionType type = ConsumptionType.used,
    WasteReason? wasteReason,
  }) {
    return _db.transaction<UseResult>(() async {
      final ItemRow item = await _requireItem(itemId);
      if (!quantity.isFinite || isZeroQty(quantity)) {
        throw const InvalidInputFailure('Enter an amount greater than zero.');
      }
      if (!unit.isCompatibleWith(item.defaultUnit)) {
        throw UnitMismatchFailure(unit.symbol, item.defaultUnit.symbol);
      }

      final List<StockBatch> batches = <StockBatch>[
        for (final BatchRow r in await _activeBatchRows(itemId)) _batch(r),
      ];
      final double requested = roundQty(quantity);
      final FifoPlan plan = Fifo.plan(
        batches: batches,
        quantity: requested,
        unit: unit,
      );
      if (!plan.isComplete) {
        final double available = roundQty(requested - plan.shortfall);
        throw InsufficientStockFailure(
          available: available,
          availableLabel: unit.format(available),
        );
      }

      final DateTime now = _now();
      final List<AppliedDeduction> applied = <AppliedDeduction>[];
      for (final Deduction d in plan.deductions) {
        applied.add(
          await _applyDeduction(
            batchId: d.batchId,
            itemId: itemId,
            amount: d.amount,
            unit: d.unit,
            type: type,
            now: now,
            wasteReason: wasteReason,
          ),
        );
      }

      return UseResult(
        itemId: itemId,
        quantity: requested,
        unit: unit,
        type: type,
        applied: applied,
      );
    });
  }

  @override
  Future<UseResult> discardBatch({
    required String batchId,
    required ConsumptionType type,
    WasteReason? wasteReason,
  }) {
    return _db.transaction<UseResult>(() async {
      final BatchRow? row = await _batchRow(batchId);
      if (row == null) {
        throw const NotFoundFailure('This batch no longer exists.');
      }
      if (isZeroQty(row.quantityRemaining)) {
        throw const InvalidInputFailure('Nothing is left in this batch.');
      }
      final AppliedDeduction applied = await _applyDeduction(
        batchId: batchId,
        itemId: row.itemId,
        amount: row.quantityRemaining,
        unit: row.unit,
        type: type,
        now: _now(),
        wasteReason: wasteReason,
      );
      return UseResult(
        itemId: row.itemId,
        quantity: applied.amount,
        unit: row.unit,
        type: type,
        applied: <AppliedDeduction>[applied],
      );
    });
  }

  /// The reason worth storing: only waste carries one. Expired food with no
  /// reason picked is stored as "expired", which is what happened to it.
  WasteReason? _reasonFor(ConsumptionType type, WasteReason? picked) {
    switch (type) {
      case ConsumptionType.wasted:
        return picked == WasteReason.unspecified ? null : picked;
      case ConsumptionType.expired:
        return picked == null || picked == WasteReason.unspecified
            ? WasteReason.expired
            : picked;
      case ConsumptionType.used:
      case ConsumptionType.givenAway:
      case ConsumptionType.cookedInRecipe:
      case ConsumptionType.adjustment:
        return null;
    }
  }

  /// Lowers one batch and writes the matching consumption log. Must run inside
  /// a transaction.
  Future<AppliedDeduction> _applyDeduction({
    required String batchId,
    required String itemId,
    required double amount,
    required Unit unit,
    required ConsumptionType type,
    required DateTime now,
    WasteReason? wasteReason,
  }) async {
    final BatchRow? row = await _batchRow(batchId);
    if (row == null) {
      throw const NotFoundFailure('This batch no longer exists.');
    }
    double remaining = roundQty(row.quantityRemaining - amount);
    if (isZeroQty(remaining)) {
      remaining = 0;
    }

    await (_db.update(_db.stockBatches)..where((t) => t.id.equals(batchId)))
        .write(
      StockBatchesCompanion(
        quantityRemaining: Value<double>(remaining),
        updatedAt: Value<DateTime>(now),
        updatedBy: Value<String?>(_userId),
        syncStatus: const Value<SyncStatus>(SyncStatus.pending),
      ),
    );

    final String logId = _newId();
    await _db.into(_db.consumptionLogs).insert(
          ConsumptionLogsCompanion.insert(
            id: logId,
            batchId: batchId,
            itemId: itemId,
            quantityUsed: amount,
            unit: unit,
            date: now,
            type: type,
            wasteReason: Value<WasteReason?>(_reasonFor(type, wasteReason)),
            createdAt: now,
            updatedAt: now,
            updatedBy: Value<String?>(_userId),
          ),
        );

    return AppliedDeduction(
      batchId: batchId,
      logId: logId,
      amount: amount,
      unit: unit,
    );
  }

  @override
  Future<void> undoUse(UseResult result) {
    return _db.transaction<void>(() async {
      final DateTime now = _now();
      for (final AppliedDeduction a in result.applied) {
        final BatchRow? row = await _batchRow(a.batchId, includeDeleted: true);
        if (row != null) {
          await (_db.update(_db.stockBatches)
                ..where((t) => t.id.equals(a.batchId)))
              .write(
            StockBatchesCompanion(
              quantityRemaining:
                  Value<double>(roundQty(row.quantityRemaining + a.amount)),
              updatedAt: Value<DateTime>(now),
              updatedBy: Value<String?>(_userId),
              syncStatus: const Value<SyncStatus>(SyncStatus.pending),
            ),
          );
        }
        await (_db.update(_db.consumptionLogs)
              ..where((t) => t.id.equals(a.logId)))
            .write(
          ConsumptionLogsCompanion(
            isDeleted: const Value<bool>(true),
            updatedAt: Value<DateTime>(now),
            updatedBy: Value<String?>(_userId),
            syncStatus: const Value<SyncStatus>(SyncStatus.pending),
          ),
        );
      }
    });
  }

  // ---------------------------------------------------------------------
  // Counting
  // ---------------------------------------------------------------------

  @override
  Future<CountResult> setStock({
    required String itemId,
    required double quantity,
    required Unit unit,
    StorageLocation? location,
    bool asWaste = false,
  }) {
    return _db.transaction<CountResult>(() async {
      final ItemRow item = await _requireItem(itemId);
      if (!quantity.isFinite || quantity < 0) {
        throw const InvalidInputFailure('Enter an amount of zero or more.');
      }
      final Unit base = item.defaultUnit;
      if (!unit.isCompatibleWith(base)) {
        throw UnitMismatchFailure(unit.symbol, base.symbol);
      }

      final double target = roundQty(unit.convertTo(quantity, base));
      final List<StockBatch> scoped = <StockBatch>[
        for (final BatchRow r in await _activeBatchRows(itemId))
          if (!isZeroQty(r.quantityRemaining) &&
              r.unit.isCompatibleWith(base) &&
              (location == null || r.storageLocation == location))
            _batch(r),
      ];
      double current = 0;
      for (final StockBatch b in scoped) {
        current += b.unit.convertTo(b.quantityRemaining, base);
      }
      current = roundQty(current);

      final double difference = roundQty(target - current);
      if (isZeroQty(difference.abs())) {
        return CountResult(
          itemId: itemId,
          before: current,
          after: current,
          unit: base,
        );
      }

      final DateTime now = _now();
      if (difference < 0) {
        final ConsumptionType type =
            asWaste ? ConsumptionType.wasted : ConsumptionType.adjustment;
        final double lowered = roundQty(-difference);
        final FifoPlan plan = Fifo.plan(
          batches: scoped,
          quantity: lowered,
          unit: base,
        );
        if (!plan.isComplete) {
          throw const InvalidInputFailure(
            'The stock changed while counting. Count this item again.',
          );
        }
        final List<AppliedDeduction> applied = <AppliedDeduction>[];
        for (final Deduction d in plan.deductions) {
          applied.add(
            await _applyDeduction(
              batchId: d.batchId,
              itemId: itemId,
              amount: d.amount,
              unit: d.unit,
              type: type,
              now: now,
            ),
          );
        }
        return CountResult(
          itemId: itemId,
          before: current,
          after: target,
          unit: base,
          deduction: UseResult(
            itemId: itemId,
            quantity: lowered,
            unit: base,
            type: type,
            applied: applied,
          ),
        );
      }

      final double added = roundQty(difference);
      _validateBatch(
        quantityBought: added,
        quantityRemaining: added,
        unit: base,
        itemUnit: base,
        price: null,
        useWithinDays: null,
      );
      final String batchId = _newId();
      await _db.into(_db.stockBatches).insert(
            StockBatchesCompanion.insert(
              id: batchId,
              itemId: itemId,
              quantityBought: added,
              quantityRemaining: added,
              unit: base,
              purchaseDate: dateOnly(now),
              storageLocation: location ?? item.defaultStorageLocation,
              createdAt: now,
              updatedAt: now,
              updatedBy: Value<String?>(_userId),
            ),
          );
      final String logId = _newId();
      await _db.into(_db.consumptionLogs).insert(
            ConsumptionLogsCompanion.insert(
              id: logId,
              batchId: batchId,
              itemId: itemId,
              quantityUsed: -added,
              unit: base,
              date: now,
              type: ConsumptionType.adjustment,
              createdAt: now,
              updatedAt: now,
              updatedBy: Value<String?>(_userId),
            ),
          );
      return CountResult(
        itemId: itemId,
        before: current,
        after: target,
        unit: base,
        addedBatchId: batchId,
        addedLogId: logId,
      );
    });
  }

  @override
  Future<void> undoCount(CountResult result) async {
    final UseResult? deduction = result.deduction;
    if (deduction != null) {
      await undoUse(deduction);
      return;
    }
    final String? batchId = result.addedBatchId;
    final String? logId = result.addedLogId;
    if (batchId == null || logId == null) {
      return;
    }
    await _db.transaction<void>(() async {
      final DateTime now = _now();
      await _setBatchDeleted(batchId, deleted: true, now: now);
      await (_db.update(_db.consumptionLogs)..where((t) => t.id.equals(logId)))
          .write(
        ConsumptionLogsCompanion(
          isDeleted: const Value<bool>(true),
          updatedAt: Value<DateTime>(now),
          updatedBy: Value<String?>(_userId),
          syncStatus: const Value<SyncStatus>(SyncStatus.pending),
        ),
      );
    });
  }

  // ---------------------------------------------------------------------
  // Sample data
  // ---------------------------------------------------------------------

  @override
  Future<int> insertSampleData() async {
    final DateTime today = dateOnly(_now());
    int added = 0;

    for (final SampleItem sample in kSampleItems) {
      if (await findItemByName(sample.name) != null) {
        continue;
      }
      final Item item = await addItem(
        ItemDraft(
          name: sample.name,
          categoryId: sample.categoryId,
          defaultUnit: sample.unit,
          aliases: sample.aliases,
          lowStockThreshold: sample.lowStockThreshold,
          isEssential: sample.isEssential,
          defaultStorageLocation: sample.location,
        ),
      );
      for (final SampleStock stock in sample.stocks) {
        final int? expiresIn = stock.expiresInDays;
        final int? openedAgo = stock.openedDaysAgo;
        await addBatch(
          BatchDraft(
            itemId: item.id,
            quantityBought: stock.quantityBought,
            quantityRemaining: stock.quantityRemaining,
            unit: sample.unit,
            purchaseDate: addDays(today, -stock.purchasedDaysAgo),
            expiryDate: expiresIn == null ? null : addDays(today, expiresIn),
            openedDate: openedAgo == null ? null : addDays(today, -openedAgo),
            useWithinDaysAfterOpening: stock.useWithinDays,
            price: stock.price,
            store: stock.store,
            storageLocation: stock.location ?? sample.location,
          ),
        );
      }
      added++;
    }
    return added;
  }
}
