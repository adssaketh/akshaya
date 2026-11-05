import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/util/date_only.dart';
import '../../../core/util/quantity.dart';
import '../../pantry/data/database/app_database.dart';
import '../../pantry/data/database/sync_status.dart';
import '../../pantry/domain/default_categories.dart';
import '../../pantry/domain/entities.dart';
import '../../pantry/domain/failures.dart';
import '../../pantry/domain/pantry_repository.dart';
import '../../pantry/domain/storage_location.dart';
import '../../pantry/domain/unit.dart';
import '../domain/shopping_entities.dart';
import '../domain/shopping_enums.dart';
import '../domain/shopping_repository.dart';

/// [ShoppingRepository] backed by the local Drift database.
///
/// Like the pantry repository, every write marks the row `pending` for Phase 6
/// sync and deletes are soft. "Done shopping" writes pantry stock through
/// [PantryRepository], so batch validation lives in one place.
class DriftShoppingRepository implements ShoppingRepository {
  DriftShoppingRepository(
    this._db,
    this._pantry, {
    DateTime Function()? clock,
    String Function()? idGenerator,
    String? currentUserId,
  })  : _clock = clock ?? DateTime.now,
        _newId = idGenerator ?? _uuidV4,
        _userId = currentUserId;

  final AppDatabase _db;
  final PantryRepository _pantry;
  final DateTime Function() _clock;
  final String Function() _newId;
  final String? _userId;

  static String _uuidV4() => const Uuid().v4();

  DateTime _now() => _clock();

  // ---------------------------------------------------------------------
  // Mapping
  // ---------------------------------------------------------------------

  ShoppingList _list(ShoppingListRow r) {
    return ShoppingList(id: r.id, name: r.name, sortOrder: r.sortOrder);
  }

  ShoppingEntry _entry(ShoppingEntryRow r) {
    return ShoppingEntry(
      id: r.id,
      listId: r.listId,
      itemId: r.itemId,
      name: r.name,
      quantity: r.quantity,
      unit: r.unit,
      isChecked: r.isChecked,
      addedReason: r.addedReason,
      priority: r.priority,
      notes: r.notes,
      recurrence: r.recurrence,
      dueOn: r.dueOn,
      repeatEveryDays: r.repeatEveryDays,
      createdAt: r.createdAt,
      updatedAt: r.updatedAt,
    );
  }

  // ---------------------------------------------------------------------
  // Streams
  // ---------------------------------------------------------------------

  @override
  Stream<List<ShoppingList>> watchLists() {
    final SimpleSelectStatement<$ShoppingListsTable, ShoppingListRow> query =
        _db.select(_db.shoppingLists)
          ..where((t) => t.isDeleted.equals(false))
          ..orderBy([
            (t) => OrderingTerm.asc(t.sortOrder),
            (t) => OrderingTerm.asc(t.createdAt),
          ]);
    return query.watch().map(
          (List<ShoppingListRow> rows) => rows.map(_list).toList(),
        );
  }

  @override
  Stream<List<ShoppingEntry>> watchEntries() {
    final SimpleSelectStatement<$ShoppingEntriesTable, ShoppingEntryRow>
        query = _db.select(_db.shoppingEntries)
          ..where((t) => t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]);
    return query.watch().map(
          (List<ShoppingEntryRow> rows) => rows.map(_entry).toList(),
        );
  }

  // ---------------------------------------------------------------------
  // Lookups and validation
  // ---------------------------------------------------------------------

  Future<ShoppingListRow?> _listRow(String id) {
    return (_db.select(_db.shoppingLists)
          ..where((t) => t.id.equals(id) & t.isDeleted.equals(false)))
        .getSingleOrNull();
  }

  Future<ShoppingEntryRow?> _entryRow(String id) {
    return (_db.select(_db.shoppingEntries)
          ..where((t) => t.id.equals(id) & t.isDeleted.equals(false)))
        .getSingleOrNull();
  }

  Future<ShoppingEntryRow> _requireEntry(String id) async {
    final ShoppingEntryRow? row = await _entryRow(id);
    if (row == null) {
      throw const NotFoundFailure('This entry no longer exists.');
    }
    return row;
  }

  Future<void> _requireList(String id) async {
    if (await _listRow(id) == null) {
      throw const NotFoundFailure('This list no longer exists.');
    }
  }

  String _cleanName(String text) {
    return text.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  String? _cleanOptional(String? text) {
    if (text == null) {
      return null;
    }
    final String cleaned = text.trim();
    return cleaned.isEmpty ? null : cleaned;
  }

  void _validateListName(String name) {
    if (name.isEmpty) {
      throw const InvalidInputFailure('Enter a name for the list.');
    }
    if (name.length > 60) {
      throw const InvalidInputFailure('The name is too long.');
    }
  }

  void _validateEntry({required String name, required double quantity}) {
    if (name.isEmpty) {
      throw const InvalidInputFailure('Enter a name for the item.');
    }
    if (name.length > 120) {
      throw const InvalidInputFailure('The name is too long.');
    }
    if (!quantity.isFinite || isZeroQty(quantity)) {
      throw const InvalidInputFailure('Enter a quantity greater than zero.');
    }
  }

  /// A custom repeat only makes sense for an entry that repeats, and must be
  /// a sensible number of days.
  void _validateRepeat(Recurrence recurrence, int? days) {
    if (days == null || !recurrence.repeats) {
      return;
    }
    if (days < 1 || days > kMaxRepeatEveryDays) {
      throw const InvalidInputFailure(
        'Repeat every 1 to $kMaxRepeatEveryDays days.',
      );
    }
  }

  /// The custom repeat to store: null unless the entry repeats.
  int? _repeatToStore(Recurrence recurrence, int? days) {
    return recurrence.repeats ? days : null;
  }

  Future<void> _requireListNameFree(String name, {String? excludeId}) async {
    final String needle = name.toLowerCase();
    final ShoppingListRow? clash = await (_db.select(_db.shoppingLists)
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
    if (clash != null) {
      throw InvalidInputFailure('A list named "${clash.name}" already exists.');
    }
  }

  // ---------------------------------------------------------------------
  // Lists
  // ---------------------------------------------------------------------

  @override
  Future<ShoppingList> addList(String name) async {
    final String cleaned = _cleanName(name);
    _validateListName(cleaned);

    return _db.transaction<ShoppingList>(() async {
      await _requireListNameFree(cleaned);

      final List<ShoppingListRow> existing = await (_db.select(
        _db.shoppingLists,
      )..where((t) => t.isDeleted.equals(false)))
          .get();
      int next = 0;
      for (final ShoppingListRow r in existing) {
        if (r.sortOrder >= next) {
          next = r.sortOrder + 1;
        }
      }

      final String id = _newId();
      final DateTime now = _now();
      await _db.into(_db.shoppingLists).insert(
            ShoppingListsCompanion.insert(
              id: id,
              name: cleaned,
              sortOrder: next,
              createdAt: now,
              updatedAt: now,
              updatedBy: Value<String?>(_userId),
            ),
          );
      return ShoppingList(id: id, name: cleaned, sortOrder: next);
    });
  }

  @override
  Future<ShoppingList> renameList(String listId, String name) async {
    final String cleaned = _cleanName(name);
    _validateListName(cleaned);

    return _db.transaction<ShoppingList>(() async {
      final ShoppingListRow? row = await _listRow(listId);
      if (row == null) {
        throw const NotFoundFailure('This list no longer exists.');
      }
      await _requireListNameFree(cleaned, excludeId: listId);

      await (_db.update(_db.shoppingLists)..where((t) => t.id.equals(listId)))
          .write(
        ShoppingListsCompanion(
          name: Value<String>(cleaned),
          updatedAt: Value<DateTime>(_now()),
          updatedBy: Value<String?>(_userId),
          syncStatus: const Value<SyncStatus>(SyncStatus.pending),
        ),
      );
      return ShoppingList(id: listId, name: cleaned, sortOrder: row.sortOrder);
    });
  }

  @override
  Future<ListDeleteToken> deleteList(String listId) {
    return _db.transaction<ListDeleteToken>(() async {
      await _requireList(listId);
      final List<ShoppingListRow> active = await (_db.select(
        _db.shoppingLists,
      )..where((t) => t.isDeleted.equals(false)))
          .get();
      if (active.length <= 1) {
        throw const InvalidInputFailure('Keep at least one shopping list.');
      }

      final DateTime now = _now();
      final List<ShoppingEntryRow> entries = await (_db.select(
        _db.shoppingEntries,
      )..where((t) => t.listId.equals(listId) & t.isDeleted.equals(false)))
          .get();
      final List<String> entryIds = <String>[
        for (final ShoppingEntryRow e in entries) e.id,
      ];
      for (final String id in entryIds) {
        await _setEntryDeleted(id, deleted: true, now: now);
      }
      await _setListDeleted(listId, deleted: true, now: now);
      return ListDeleteToken(listId: listId, entryIds: entryIds);
    });
  }

  @override
  Future<void> undoDeleteList(ListDeleteToken token) {
    return _db.transaction<void>(() async {
      final DateTime now = _now();
      await _setListDeleted(token.listId, deleted: false, now: now);
      for (final String id in token.entryIds) {
        await _setEntryDeleted(id, deleted: false, now: now);
      }
    });
  }

  Future<void> _setListDeleted(
    String id, {
    required bool deleted,
    required DateTime now,
  }) async {
    await (_db.update(_db.shoppingLists)..where((t) => t.id.equals(id))).write(
      ShoppingListsCompanion(
        isDeleted: Value<bool>(deleted),
        updatedAt: Value<DateTime>(now),
        updatedBy: Value<String?>(_userId),
        syncStatus: const Value<SyncStatus>(SyncStatus.pending),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Entries
  // ---------------------------------------------------------------------

  @override
  Future<ShoppingEntry> addEntry(ShoppingEntryDraft draft) {
    return _db.transaction<ShoppingEntry>(() => _insertOrMerge(draft));
  }

  @override
  Future<int> addEntries(List<ShoppingEntryDraft> drafts) {
    return _db.transaction<int>(() async {
      int count = 0;
      for (final ShoppingEntryDraft draft in drafts) {
        await _insertOrMerge(draft);
        count++;
      }
      return count;
    });
  }

  /// Adds [draft], or raises the quantity of the entry it duplicates. Must run
  /// inside a transaction.
  Future<ShoppingEntry> _insertOrMerge(ShoppingEntryDraft draft) async {
    final String name = _cleanName(draft.name);
    _validateEntry(name: name, quantity: draft.quantity);
    _validateRepeat(draft.recurrence, draft.repeatEveryDays);
    await _requireList(draft.listId);

    final DateTime now = _now();
    final String? notes = _cleanOptional(draft.notes);
    final double quantity = roundQty(draft.quantity);
    final int? repeatDays =
        _repeatToStore(draft.recurrence, draft.repeatEveryDays);

    final ShoppingEntryRow? target = await _mergeTarget(
      listId: draft.listId,
      itemId: draft.itemId,
      name: name,
      unit: draft.unit,
      recurrence: draft.recurrence,
      repeatEveryDays: repeatDays,
      today: dateOnly(now),
    );

    if (target != null) {
      final double added = draft.unit.convertTo(quantity, target.unit);
      final bool urgent = target.priority == ShoppingPriority.high ||
          draft.priority == ShoppingPriority.high;
      await (_db.update(_db.shoppingEntries)
            ..where((t) => t.id.equals(target.id)))
          .write(
        ShoppingEntriesCompanion(
          quantity: Value<double>(roundQty(target.quantity + added)),
          priority: Value<ShoppingPriority>(
            urgent ? ShoppingPriority.high : ShoppingPriority.normal,
          ),
          notes: Value<String?>(target.notes ?? notes),
          updatedAt: Value<DateTime>(now),
          updatedBy: Value<String?>(_userId),
          syncStatus: const Value<SyncStatus>(SyncStatus.pending),
        ),
      );
      return _entry(await _requireEntry(target.id));
    }

    final String id = _newId();
    await _db.into(_db.shoppingEntries).insert(
          ShoppingEntriesCompanion.insert(
            id: id,
            listId: draft.listId,
            name: name,
            quantity: quantity,
            unit: draft.unit,
            createdAt: now,
            updatedAt: now,
            itemId: Value<String?>(draft.itemId),
            addedReason: Value<AddedReason>(draft.addedReason),
            priority: Value<ShoppingPriority>(draft.priority),
            notes: Value<String?>(notes),
            recurrence: Value<Recurrence>(draft.recurrence),
            repeatEveryDays: Value<int?>(repeatDays),
            updatedBy: Value<String?>(_userId),
          ),
        );
    return ShoppingEntry(
      id: id,
      listId: draft.listId,
      itemId: draft.itemId,
      name: name,
      quantity: quantity,
      unit: draft.unit,
      isChecked: false,
      addedReason: draft.addedReason,
      priority: draft.priority,
      notes: notes,
      recurrence: draft.recurrence,
      repeatEveryDays: repeatDays,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// An unchecked entry on the list that [name] / [itemId] would duplicate:
  /// same thing, convertible unit, same repeat, and on the list today.
  Future<ShoppingEntryRow?> _mergeTarget({
    required String listId,
    required String? itemId,
    required String name,
    required Unit unit,
    required Recurrence recurrence,
    required int? repeatEveryDays,
    required DateTime today,
  }) async {
    final List<ShoppingEntryRow> rows = await (_db.select(_db.shoppingEntries)
          ..where(
            (t) =>
                t.listId.equals(listId) &
                t.isDeleted.equals(false) &
                t.isChecked.equals(false),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
    final String key = name.toLowerCase();
    for (final ShoppingEntryRow r in rows) {
      final bool sameThing =
          (itemId != null && r.itemId == itemId) || r.name.toLowerCase() == key;
      if (!sameThing ||
          r.recurrence != recurrence ||
          r.repeatEveryDays != repeatEveryDays ||
          !r.unit.isCompatibleWith(unit)) {
        continue;
      }
      final DateTime? due = r.dueOn;
      if (due != null && due.isAfter(today)) {
        continue;
      }
      return r;
    }
    return null;
  }

  @override
  Future<ShoppingEntry> updateEntry(ShoppingEntry entry) {
    final String name = _cleanName(entry.name);
    _validateEntry(name: name, quantity: entry.quantity);
    _validateRepeat(entry.recurrence, entry.repeatEveryDays);

    return _db.transaction<ShoppingEntry>(() async {
      final ShoppingEntryRow row = await _requireEntry(entry.id);
      if (entry.listId != row.listId) {
        await _requireList(entry.listId);
      }

      await (_db.update(_db.shoppingEntries)
            ..where((t) => t.id.equals(entry.id)))
          .write(
        ShoppingEntriesCompanion(
          listId: Value<String>(entry.listId),
          itemId: Value<String?>(entry.itemId),
          name: Value<String>(name),
          quantity: Value<double>(roundQty(entry.quantity)),
          unit: Value<Unit>(entry.unit),
          priority: Value<ShoppingPriority>(entry.priority),
          notes: Value<String?>(_cleanOptional(entry.notes)),
          recurrence: Value<Recurrence>(entry.recurrence),
          repeatEveryDays: Value<int?>(
            _repeatToStore(entry.recurrence, entry.repeatEveryDays),
          ),
          dueOn: Value<DateTime?>(
            entry.recurrence.repeats ? _dateOrNull(entry.dueOn) : null,
          ),
          updatedAt: Value<DateTime>(_now()),
          updatedBy: Value<String?>(_userId),
          syncStatus: const Value<SyncStatus>(SyncStatus.pending),
        ),
      );
      return _entry(await _requireEntry(entry.id));
    });
  }

  DateTime? _dateOrNull(DateTime? value) {
    return value == null ? null : dateOnly(value);
  }

  @override
  Future<void> setChecked(String entryId, {required bool checked}) {
    return _db.transaction<void>(() async {
      await _requireEntry(entryId);
      await (_db.update(_db.shoppingEntries)
            ..where((t) => t.id.equals(entryId)))
          .write(
        ShoppingEntriesCompanion(
          isChecked: Value<bool>(checked),
          updatedAt: Value<DateTime>(_now()),
          updatedBy: Value<String?>(_userId),
          syncStatus: const Value<SyncStatus>(SyncStatus.pending),
        ),
      );
    });
  }

  @override
  Future<void> deleteEntry(String entryId) {
    return _db.transaction<void>(() async {
      await _requireEntry(entryId);
      await _setEntryDeleted(entryId, deleted: true, now: _now());
    });
  }

  @override
  Future<void> undoDeleteEntry(String entryId) {
    return _db.transaction<void>(() async {
      await _setEntryDeleted(entryId, deleted: false, now: _now());
    });
  }

  Future<void> _setEntryDeleted(
    String id, {
    required bool deleted,
    required DateTime now,
  }) async {
    await (_db.update(_db.shoppingEntries)..where((t) => t.id.equals(id)))
        .write(
      ShoppingEntriesCompanion(
        isDeleted: Value<bool>(deleted),
        updatedAt: Value<DateTime>(now),
        updatedBy: Value<String?>(_userId),
        syncStatus: const Value<SyncStatus>(SyncStatus.pending),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Done shopping
  // ---------------------------------------------------------------------

  @override
  Future<CheckoutResult> completeShopping({
    required String listId,
    required List<CheckoutLine> lines,
    String? store,
  }) {
    return _db.transaction<CheckoutResult>(() async {
      final DateTime now = _now();
      final DateTime today = dateOnly(now);
      final String? storeName = _cleanOptional(store);

      final List<ShoppingEntryRow> checked = await (_db.select(
        _db.shoppingEntries,
      )
            ..where(
              (t) =>
                  t.listId.equals(listId) &
                  t.isDeleted.equals(false) &
                  t.isChecked.equals(true),
            )
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
          .get();
      if (checked.isEmpty) {
        throw const InvalidInputFailure('Check off what you bought first.');
      }

      final Map<String, CheckoutLine> lineByEntry = <String, CheckoutLine>{
        for (final CheckoutLine l in lines) l.entryId: l,
      };
      final List<String> batchIds = <String>[];
      final List<ShoppingEntry> previous = <ShoppingEntry>[];
      final List<String> createdItemIds = <String>[];

      for (final ShoppingEntryRow row in checked) {
        final ShoppingEntry entry = _entry(row);
        final CheckoutLine? line = lineByEntry[entry.id];
        final double? price = line?.price;
        if (price != null && (!price.isFinite || price < 0)) {
          throw InvalidInputFailure('Price for "${entry.name}" is not valid.');
        }

        final _ResolvedItem item = await _resolveItem(entry, createdItemIds);
        if (!entry.unit.isCompatibleWith(item.unit)) {
          throw InvalidInputFailure(
            '"${entry.name}" is on the list in ${entry.unit.symbol} but your '
            'pantry counts it in ${item.unit.symbol}. Edit the entry first.',
          );
        }

        final StockBatch batch = await _pantry.addBatch(
          BatchDraft(
            itemId: item.id,
            quantityBought: entry.quantity,
            unit: entry.unit,
            purchaseDate: today,
            expiryDate: line?.expiryDate,
            price: price,
            store: storeName,
            storageLocation: item.location,
          ),
        );
        batchIds.add(batch.id);
        previous.add(entry);

        if (entry.recurrence.repeats) {
          await (_db.update(_db.shoppingEntries)
                ..where((t) => t.id.equals(entry.id)))
              .write(
            ShoppingEntriesCompanion(
              isChecked: const Value<bool>(false),
              dueOn: Value<DateTime?>(entry.nextDueAfter(today)),
              addedReason: const Value<AddedReason>(AddedReason.recurring),
              updatedAt: Value<DateTime>(now),
              updatedBy: Value<String?>(_userId),
              syncStatus: const Value<SyncStatus>(SyncStatus.pending),
            ),
          );
        } else {
          await _setEntryDeleted(entry.id, deleted: true, now: now);
        }
      }

      return CheckoutResult(
        batchIds: batchIds,
        previousEntries: previous,
        createdItemIds: createdItemIds,
      );
    });
  }

  /// The pantry item an entry restocks: its linked item, else the item with
  /// the same name, else a new item (category Other) in the entry's unit.
  Future<_ResolvedItem> _resolveItem(
    ShoppingEntry entry,
    List<String> createdItemIds,
  ) async {
    final String? linked = entry.itemId;
    if (linked != null) {
      final ItemRow? row = await (_db.select(_db.items)
            ..where((t) => t.id.equals(linked) & t.isDeleted.equals(false)))
          .getSingleOrNull();
      if (row != null) {
        return _ResolvedItem(
          id: row.id,
          unit: row.defaultUnit,
          location: row.defaultStorageLocation,
        );
      }
    }

    final Item? byName = await _pantry.findItemByName(entry.name);
    if (byName != null) {
      return _ResolvedItem(
        id: byName.id,
        unit: byName.defaultUnit,
        location: byName.defaultStorageLocation,
      );
    }

    final Item created = await _pantry.addItem(
      ItemDraft(
        name: entry.name,
        categoryId: kDefaultCategoryId,
        defaultUnit: entry.unit,
      ),
    );
    createdItemIds.add(created.id);
    return _ResolvedItem(
      id: created.id,
      unit: created.defaultUnit,
      location: created.defaultStorageLocation,
    );
  }

  @override
  Future<void> undoCompleteShopping(CheckoutResult result) {
    return _db.transaction<void>(() async {
      final DateTime now = _now();

      for (final String batchId in result.batchIds) {
        try {
          await _pantry.deleteBatch(batchId);
        } on NotFoundFailure {
          // Already removed since: nothing to undo for this batch.
        }
      }
      for (final String itemId in result.createdItemIds) {
        try {
          await _pantry.deleteItem(itemId);
        } on NotFoundFailure {
          // Already removed since.
        }
      }
      for (final ShoppingEntry before in result.previousEntries) {
        await (_db.update(_db.shoppingEntries)
              ..where((t) => t.id.equals(before.id)))
            .write(
          ShoppingEntriesCompanion(
            isChecked: Value<bool>(before.isChecked),
            isDeleted: const Value<bool>(false),
            dueOn: Value<DateTime?>(before.dueOn),
            addedReason: Value<AddedReason>(before.addedReason),
            updatedAt: Value<DateTime>(now),
            updatedBy: Value<String?>(_userId),
            syncStatus: const Value<SyncStatus>(SyncStatus.pending),
          ),
        );
      }
    });
  }
}

/// The pantry item a checked-off entry is bought into.
final class _ResolvedItem {
  const _ResolvedItem({
    required this.id,
    required this.unit,
    required this.location,
  });

  final String id;
  final Unit unit;
  final StorageLocation location;
}
