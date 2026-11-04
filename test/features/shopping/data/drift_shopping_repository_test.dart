import 'dart:io';

import 'package:akshaya/features/pantry/data/database/app_database.dart';
import 'package:akshaya/features/pantry/data/drift_pantry_repository.dart';
import 'package:akshaya/features/pantry/domain/entities.dart';
import 'package:akshaya/features/pantry/domain/failures.dart';
import 'package:akshaya/features/pantry/domain/storage_location.dart';
import 'package:akshaya/features/pantry/domain/unit.dart';
import 'package:akshaya/features/shopping/data/drift_shopping_repository.dart';
import 'package:akshaya/features/shopping/domain/shopping_entities.dart';
import 'package:akshaya/features/shopping/domain/shopping_enums.dart';
import 'package:drift/drift.dart' show QueryRow, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late DriftPantryRepository pantry;
  late DriftShoppingRepository shop;
  int counter = 0;
  int tick = 0;

  setUp(() {
    counter = 0;
    tick = 0;
    db = AppDatabase(NativeDatabase.memory());
    String nextId() => 'id-${counter++}';
    // Always 4 Nov 2026, but every call is a millisecond later, so rows
    // created one after another keep their order.
    DateTime clock() =>
        DateTime(2026, 11, 4, 10).add(Duration(milliseconds: tick++));
    pantry = DriftPantryRepository(db, clock: clock, idGenerator: nextId);
    shop = DriftShoppingRepository(
      db,
      pantry,
      clock: clock,
      idGenerator: nextId,
    );
  });

  tearDown(() => db.close());

  ShoppingEntryDraft draft(
    String name, {
    double quantity = 1,
    Unit unit = Unit.kg,
    String? itemId,
    String listId = kDefaultListId,
    ShoppingPriority priority = ShoppingPriority.normal,
    Recurrence recurrence = Recurrence.none,
    String? notes,
  }) {
    return ShoppingEntryDraft(
      listId: listId,
      itemId: itemId,
      name: name,
      quantity: quantity,
      unit: unit,
      priority: priority,
      recurrence: recurrence,
      notes: notes,
    );
  }

  Future<List<ShoppingEntry>> entries() => shop.watchEntries().first;

  Future<ItemWithBatches> pantryItem(String name) async {
    final List<ItemWithBatches> all = await pantry.watchItems().first;
    return all.firstWhere((ItemWithBatches r) => r.item.name == name);
  }

  Future<Item> addRice() {
    return pantry.addItem(
      const ItemDraft(
        name: 'Rice',
        categoryId: 'cat_grains',
        defaultUnit: Unit.kg,
      ),
    );
  }

  Future<ShoppingEntry> checked(ShoppingEntryDraft d) async {
    final ShoppingEntry entry = await shop.addEntry(d);
    await shop.setChecked(entry.id, checked: true);
    return entry;
  }

  group('lists', () {
    test('a new database starts with the default list', () async {
      final List<ShoppingList> lists = await shop.watchLists().first;

      expect(lists, hasLength(1));
      expect(lists.single.id, kDefaultListId);
      expect(lists.single.name, kDefaultListName);
    });

    test('adds lists in order and rejects bad or duplicate names', () async {
      final ShoppingList weekly = await shop.addList('  Weekly  ');
      final ShoppingList dmart = await shop.addList('DMart');

      expect(weekly.name, 'Weekly');
      expect(dmart.sortOrder, greaterThan(weekly.sortOrder));
      expect(
        (await shop.watchLists().first).map((ShoppingList l) => l.name),
        <String>[kDefaultListName, 'Weekly', 'DMart'],
      );

      await expectLater(shop.addList('   '), throwsA(isA<InvalidInputFailure>()));
      await expectLater(shop.addList('weekly'), throwsA(isA<InvalidInputFailure>()));
    });

    test('renames a list, but not to another list\'s name', () async {
      final ShoppingList weekly = await shop.addList('Weekly');
      await shop.addList('Monthly');

      final ShoppingList renamed = await shop.renameList(weekly.id, 'Groceries');
      expect(renamed.name, 'Groceries');

      await expectLater(
        shop.renameList(weekly.id, 'monthly'),
        throwsA(isA<InvalidInputFailure>()),
      );
      // Keeping its own name (even in other case) is fine.
      await shop.renameList(weekly.id, 'GROCERIES');
    });

    test('deleting a list removes its entries and Undo restores them', () async {
      final ShoppingList dmart = await shop.addList('DMart');
      await shop.addEntry(draft('Rice', listId: dmart.id));
      await shop.addEntry(draft('Salt'));

      final ListDeleteToken token = await shop.deleteList(dmart.id);

      expect(
        (await shop.watchLists().first).map((ShoppingList l) => l.id),
        <String>[kDefaultListId],
      );
      expect((await entries()).map((ShoppingEntry e) => e.name), <String>['Salt']);

      await shop.undoDeleteList(token);

      expect(await shop.watchLists().first, hasLength(2));
      expect(
        (await entries()).map((ShoppingEntry e) => e.name).toSet(),
        <String>{'Rice', 'Salt'},
      );
    });

    test('the last list cannot be deleted', () async {
      await expectLater(
        shop.deleteList(kDefaultListId),
        throwsA(isA<InvalidInputFailure>()),
      );
    });
  });

  group('entries', () {
    test('adds an entry with its details', () async {
      final ShoppingEntry entry = await shop.addEntry(
        draft(
          '  Toor  Dal ',
          quantity: 2,
          itemId: 'i9',
          priority: ShoppingPriority.high,
          notes: ' the small packs ',
        ),
      );

      expect(entry.name, 'Toor Dal');
      expect(entry.quantity, 2);
      expect(entry.itemId, 'i9');
      expect(entry.priority, ShoppingPriority.high);
      expect(entry.notes, 'the small packs');
      expect(entry.isChecked, isFalse);
      expect(entry.addedReason, AddedReason.manual);
      expect(entry.dueOn, isNull);
      expect(await entries(), hasLength(1));
    });

    test('rejects a blank name, a zero quantity and an unknown list', () async {
      await expectLater(
        shop.addEntry(draft('  ')),
        throwsA(isA<InvalidInputFailure>()),
      );
      await expectLater(
        shop.addEntry(draft('Rice', quantity: 0)),
        throwsA(isA<InvalidInputFailure>()),
      );
      await expectLater(
        shop.addEntry(draft('Rice', quantity: -1)),
        throwsA(isA<InvalidInputFailure>()),
      );
      await expectLater(
        shop.addEntry(draft('Rice', listId: 'nope')),
        throwsA(isA<NotFoundFailure>()),
      );
      expect(await entries(), isEmpty);
    });

    test('adding the same thing again raises the quantity', () async {
      await shop.addEntry(draft('Rice', itemId: 'i1'));
      final ShoppingEntry merged = await shop.addEntry(
        draft('rice', quantity: 500, unit: Unit.g, priority: ShoppingPriority.high),
      );

      final List<ShoppingEntry> all = await entries();
      expect(all, hasLength(1));
      expect(merged.id, all.single.id);
      expect(all.single.quantity, 1.5);
      expect(all.single.unit, Unit.kg);
      expect(all.single.priority, ShoppingPriority.high);
    });

    test('does not merge across different units, repeats or lists', () async {
      final ShoppingList other = await shop.addList('Other');
      await shop.addEntry(draft('Milk', unit: Unit.l));
      await shop.addEntry(draft('Milk', unit: Unit.packet));
      await shop.addEntry(draft('Milk', unit: Unit.l, recurrence: Recurrence.daily));
      await shop.addEntry(draft('Milk', unit: Unit.l, listId: other.id));

      expect(await entries(), hasLength(4));
    });

    test('a checked entry is not merged into', () async {
      await checked(draft('Rice'));
      await shop.addEntry(draft('Rice'));

      expect(await entries(), hasLength(2));
    });

    test('addEntries adds several in one go and counts them', () async {
      final int count = await shop.addEntries(<ShoppingEntryDraft>[
        draft('Rice'),
        draft('Salt'),
        draft('rice'),
      ]);

      expect(count, 3);
      expect(await entries(), hasLength(2));
    });

    test('addEntries adds nothing when one draft is invalid', () async {
      await expectLater(
        shop.addEntries(<ShoppingEntryDraft>[
          draft('Rice'),
          draft('Salt', quantity: 0),
        ]),
        throwsA(isA<InvalidInputFailure>()),
      );

      expect(await entries(), isEmpty);
    });

    test('updates an entry, and clears the date when it stops repeating',
        () async {
      final ShoppingEntry entry = await shop.addEntry(
        draft('Milk', unit: Unit.l, recurrence: Recurrence.weekly),
      );
      final ShoppingEntry withDate =
          await shop.updateEntry(entry.copyWith(dueOn: DateTime(2026, 11, 10)));
      expect(withDate.dueOn, DateTime(2026, 11, 10));

      final ShoppingEntry edited = await shop.updateEntry(
        withDate.copyWith(
          name: 'Toned Milk',
          quantity: 2,
          recurrence: Recurrence.none,
          notes: 'blue packet',
        ),
      );

      expect(edited.name, 'Toned Milk');
      expect(edited.quantity, 2);
      expect(edited.recurrence, Recurrence.none);
      expect(edited.dueOn, isNull);
      expect(edited.notes, 'blue packet');
    });

    test('moves an entry to another list', () async {
      final ShoppingList other = await shop.addList('DMart');
      final ShoppingEntry entry = await shop.addEntry(draft('Rice'));

      final ShoppingEntry moved =
          await shop.updateEntry(entry.copyWith(listId: other.id));

      expect(moved.listId, other.id);
      await expectLater(
        shop.updateEntry(entry.copyWith(listId: 'nope')),
        throwsA(isA<NotFoundFailure>()),
      );
    });

    test('checks and unchecks', () async {
      final ShoppingEntry entry = await shop.addEntry(draft('Rice'));

      await shop.setChecked(entry.id, checked: true);
      expect((await entries()).single.isChecked, isTrue);

      await shop.setChecked(entry.id, checked: false);
      expect((await entries()).single.isChecked, isFalse);
    });

    test('delete hides an entry and Undo brings it back', () async {
      final ShoppingEntry entry = await shop.addEntry(draft('Rice'));

      await shop.deleteEntry(entry.id);
      expect(await entries(), isEmpty);
      await expectLater(
        shop.setChecked(entry.id, checked: true),
        throwsA(isA<NotFoundFailure>()),
      );

      await shop.undoDeleteEntry(entry.id);
      expect((await entries()).single.name, 'Rice');
    });
  });

  group('Done shopping', () {
    test('adds a batch to the linked pantry item and removes the entry',
        () async {
      final Item rice = await addRice();
      final ShoppingEntry entry = await checked(
        draft('Rice', quantity: 2, itemId: rice.id),
      );

      final CheckoutResult result = await shop.completeShopping(
        listId: kDefaultListId,
        lines: <CheckoutLine>[
          CheckoutLine(
            entryId: entry.id,
            expiryDate: DateTime(2027, 5, 1),
            price: 180,
          ),
        ],
        store: ' DMart ',
      );

      expect(result.count, 1);
      expect(await entries(), isEmpty);

      final ItemWithBatches stocked = await pantryItem('Rice');
      final StockBatch batch = stocked.batches.single;
      expect(batch.quantityBought, 2);
      expect(batch.quantityRemaining, 2);
      expect(batch.unit, Unit.kg);
      expect(batch.purchaseDate, DateTime(2026, 11, 4));
      expect(batch.expiryDate, DateTime(2027, 5, 1));
      expect(batch.price, 180);
      expect(batch.store, 'DMart');
      expect(batch.storageLocation, StorageLocation.pantry);
    });

    test('lines are optional: expiry and price may be left out', () async {
      final Item rice = await addRice();
      await checked(draft('Rice', itemId: rice.id));

      await shop.completeShopping(
        listId: kDefaultListId,
        lines: const <CheckoutLine>[],
      );

      final StockBatch batch = (await pantryItem('Rice')).batches.single;
      expect(batch.expiryDate, isNull);
      expect(batch.price, isNull);
      expect(batch.store, isNull);
    });

    test('a free-text entry creates a pantry item in Other', () async {
      await checked(draft('Candles', quantity: 4, unit: Unit.pcs));

      final CheckoutResult result = await shop.completeShopping(
        listId: kDefaultListId,
        lines: const <CheckoutLine>[],
      );

      expect(result.createdItemIds, hasLength(1));
      final ItemWithBatches candles = await pantryItem('Candles');
      expect(candles.item.categoryId, 'cat_other');
      expect(candles.item.defaultUnit, Unit.pcs);
      expect(candles.batches.single.quantityBought, 4);
    });

    test('a free-text entry reuses the pantry item with the same name',
        () async {
      await addRice();
      await checked(draft('rice', quantity: 3));

      final CheckoutResult result = await shop.completeShopping(
        listId: kDefaultListId,
        lines: const <CheckoutLine>[],
      );

      expect(result.createdItemIds, isEmpty);
      expect((await pantryItem('Rice')).batches.single.quantityBought, 3);
      expect((await pantry.watchItems().first), hasLength(1));
    });

    test('quantities in a convertible unit are bought in that unit', () async {
      final Item rice = await addRice();
      await checked(draft('Rice', quantity: 500, unit: Unit.g, itemId: rice.id));

      await shop.completeShopping(
        listId: kDefaultListId,
        lines: const <CheckoutLine>[],
      );

      final StockBatch batch = (await pantryItem('Rice')).batches.single;
      expect(batch.unit, Unit.g);
      expect(batch.quantityBought, 500);
    });

    test('only checked entries of that list are bought', () async {
      final ShoppingList other = await shop.addList('Other');
      await shop.addEntry(draft('Salt'));
      await checked(draft('Candles', unit: Unit.pcs));
      await checked(draft('Soap', unit: Unit.pcs, listId: other.id));

      await shop.completeShopping(
        listId: kDefaultListId,
        lines: const <CheckoutLine>[],
      );

      expect(
        (await entries()).map((ShoppingEntry e) => e.name).toSet(),
        <String>{'Salt', 'Soap'},
      );
      expect(
        (await pantry.watchItems().first).map((ItemWithBatches r) => r.item.name),
        <String>['Candles'],
      );
    });

    test('a repeating entry goes back to unchecked and comes due again',
        () async {
      await checked(draft('Milk', unit: Unit.l, recurrence: Recurrence.weekly));

      await shop.completeShopping(
        listId: kDefaultListId,
        lines: const <CheckoutLine>[],
      );

      final ShoppingEntry milk = (await entries()).single;
      expect(milk.isChecked, isFalse);
      expect(milk.dueOn, DateTime(2026, 11, 11));
      expect(milk.addedReason, AddedReason.recurring);
      expect(milk.isDueOn(DateTime(2026, 11, 4)), isFalse);
      expect(milk.isDueOn(DateTime(2026, 11, 11)), isTrue);
    });

    test('nothing checked is an error', () async {
      await shop.addEntry(draft('Rice'));

      await expectLater(
        shop.completeShopping(
          listId: kDefaultListId,
          lines: const <CheckoutLine>[],
        ),
        throwsA(isA<InvalidInputFailure>()),
      );
    });

    test('rejects a negative price', () async {
      final Item rice = await addRice();
      final ShoppingEntry entry = await checked(draft('Rice', itemId: rice.id));

      await expectLater(
        shop.completeShopping(
          listId: kDefaultListId,
          lines: <CheckoutLine>[CheckoutLine(entryId: entry.id, price: -5)],
        ),
        throwsA(isA<InvalidInputFailure>()),
      );
    });

    test('a unit that cannot convert fails and changes nothing', () async {
      final Item rice = await addRice();
      // Oldest first, so the good entry is processed before the bad one.
      await checked(draft('Candles', unit: Unit.pcs));
      await checked(draft('Rice', unit: Unit.pcs, itemId: rice.id));

      await expectLater(
        shop.completeShopping(
          listId: kDefaultListId,
          lines: const <CheckoutLine>[],
        ),
        throwsA(isA<InvalidInputFailure>()),
      );

      // Everything rolled back: entries still checked, no new item or stock.
      expect(await entries(), hasLength(2));
      expect((await entries()).every((ShoppingEntry e) => e.isChecked), isTrue);
      final List<ItemWithBatches> items = await pantry.watchItems().first;
      expect(items.map((ItemWithBatches r) => r.item.name), <String>['Rice']);
      expect(items.single.batches, isEmpty);
    });

    test('Undo removes the stock and the new items and restores the entries',
        () async {
      final Item rice = await addRice();
      await checked(draft('Rice', itemId: rice.id));
      await checked(draft('Candles', unit: Unit.pcs));
      await checked(draft('Milk', unit: Unit.l, recurrence: Recurrence.daily));

      final CheckoutResult result = await shop.completeShopping(
        listId: kDefaultListId,
        lines: const <CheckoutLine>[],
      );
      expect(result.count, 3);

      await shop.undoCompleteShopping(result);

      final List<ItemWithBatches> items = await pantry.watchItems().first;
      expect(items.map((ItemWithBatches r) => r.item.name).toSet(), <String>{'Rice'});
      expect(items.single.batches, isEmpty);

      final List<ShoppingEntry> restored = await entries();
      expect(restored, hasLength(3));
      expect(restored.every((ShoppingEntry e) => e.isChecked), isTrue);
      final ShoppingEntry milk =
          restored.firstWhere((ShoppingEntry e) => e.name == 'Milk');
      expect(milk.dueOn, isNull);
      expect(milk.addedReason, AddedReason.manual);
    });
  });

  group('schema', () {
    test('upgrades a version 1 database and adds the default list', () async {
      final Directory dir = await Directory.systemTemp.createTemp('akshaya_db');
      addTearDown(() => dir.delete(recursive: true));
      final File file = File('${dir.path}/upgrade.db');

      // Make a database that looks like Phase 1 left it.
      final AppDatabase fresh = AppDatabase(NativeDatabase(file));
      await fresh.customSelect('SELECT 1').get();
      await fresh.customStatement('DROP TABLE shopping_entries');
      await fresh.customStatement('DROP TABLE shopping_lists');
      await fresh.customStatement('PRAGMA user_version = 1');
      await fresh.close();

      final AppDatabase upgraded = AppDatabase(NativeDatabase(file));
      addTearDown(upgraded.close);
      final DriftPantryRepository upgradedPantry =
          DriftPantryRepository(upgraded);
      final DriftShoppingRepository upgradedShop =
          DriftShoppingRepository(upgraded, upgradedPantry);

      final List<ShoppingList> lists = await upgradedShop.watchLists().first;
      expect(lists.single.id, kDefaultListId);

      final ShoppingEntry entry = await upgradedShop.addEntry(
        ShoppingEntryDraft(
          listId: kDefaultListId,
          name: 'Rice',
          quantity: 1,
          unit: Unit.kg,
        ),
      );
      expect(entry.name, 'Rice');

      final List<String> indexes = (await upgraded
              .customSelect(
                "SELECT name FROM sqlite_master WHERE type = 'index' "
                "AND name LIKE 'shopping_entries_%' ORDER BY name",
              )
              .get())
          .map((QueryRow row) => row.read<String>('name'))
          .toList();
      expect(indexes, <String>[
        'shopping_entries_item_idx',
        'shopping_entries_list_idx',
      ]);
    });
  });
}
