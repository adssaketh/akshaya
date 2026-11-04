import 'package:akshaya/features/commands/domain/command_executor.dart';
import 'package:akshaya/features/commands/domain/command_models.dart';
import 'package:akshaya/features/pantry/data/database/app_database.dart';
import 'package:akshaya/features/pantry/data/drift_pantry_repository.dart';
import 'package:akshaya/features/pantry/domain/entities.dart';
import 'package:akshaya/features/pantry/domain/storage_location.dart';
import 'package:akshaya/features/pantry/domain/unit.dart';
import 'package:akshaya/features/shopping/data/drift_shopping_repository.dart';
import 'package:akshaya/features/shopping/domain/shopping_entities.dart';
import 'package:akshaya/features/shopping/domain/shopping_enums.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late DriftPantryRepository pantry;
  late DriftShoppingRepository shop;
  late CommandExecutor executor;
  int counter = 0;
  int tick = 0;

  setUp(() {
    counter = 0;
    tick = 0;
    db = AppDatabase(NativeDatabase.memory());
    String nextId() => 'id-${counter++}';
    DateTime clock() =>
        DateTime(2026, 11, 4, 10).add(Duration(milliseconds: tick++));
    pantry = DriftPantryRepository(db, clock: clock, idGenerator: nextId);
    shop = DriftShoppingRepository(db, pantry, clock: clock, idGenerator: nextId);
    executor = CommandExecutor(
      pantry: pantry,
      shopping: shop,
      now: () => DateTime(2026, 11, 4, 10),
      warningDays: 3,
    );
  });

  tearDown(() => db.close());

  Future<Item> addRice({double kg = 0}) async {
    final Item rice = await pantry.addItem(
      const ItemDraft(
        name: 'Rice',
        categoryId: 'cat_grains',
        defaultUnit: Unit.kg,
        aliases: <String>['biyyam'],
      ),
    );
    if (kg > 0) {
      await pantry.addBatch(
        BatchDraft(
          itemId: rice.id,
          quantityBought: kg,
          unit: Unit.kg,
          purchaseDate: DateTime(2026, 11, 1),
          storageLocation: StorageLocation.pantry,
        ),
      );
    }
    return rice;
  }

  Future<ItemWithBatches> record(String name) async {
    final List<ItemWithBatches> all = await pantry.watchItems().first;
    return all.firstWhere((ItemWithBatches r) => r.item.name == name);
  }

  double remaining(ItemWithBatches r) => r.batches.fold<double>(
        0,
        (double sum, StockBatch b) => sum + b.quantityRemaining,
      );

  Future<CommandRunResult> run(
    List<CommandAction> actions, {
    bool learn = false,
  }) {
    return executor.execute(actions, listId: kDefaultListId, learnAliases: learn);
  }

  group('add_stock', () {
    test('creates a new item with an English name and keeps the word as '
        'an alias', () async {
      final CommandRunResult result = await run(<CommandAction>[
        const CommandAction(
          intent: CommandIntent.addStock,
          itemName: 'Toor Dal',
          originalText: 'kandi pappu',
          quantity: 1,
          unit: Unit.kg,
          categoryId: 'cat_dals',
          typicalUnit: Unit.kg,
        ),
      ]);

      expect(result.allSucceeded, isTrue);
      final ItemWithBatches dal = await record('Toor Dal');
      expect(dal.item.aliases, contains('kandi pappu'));
      expect(dal.item.categoryId, 'cat_dals');
      expect(remaining(dal), 1);
    });

    test('adds a batch to an existing item', () async {
      await addRice(kg: 2);
      await run(<CommandAction>[
        const CommandAction(
          intent: CommandIntent.addStock,
          itemName: 'Rice',
          quantity: 500,
          unit: Unit.g,
        ),
      ]);
      expect(remaining(await record('Rice')), closeTo(2.5, 0.0001));
    });

    test('a spoken name finds the item through its alias, no duplicate',
        () async {
      await addRice();
      await run(<CommandAction>[
        const CommandAction(
          intent: CommandIntent.addStock,
          itemName: 'biyyam',
          quantity: 1,
        ),
      ]);
      final List<ItemWithBatches> all = await pantry.watchItems().first;
      expect(all, hasLength(1));
      expect(remaining(all.single), 1);
    });

    test('a unit that cannot be converted is refused', () async {
      await addRice();
      final CommandRunResult result = await run(<CommandAction>[
        const CommandAction(
          intent: CommandIntent.addStock,
          itemName: 'Rice',
          quantity: 1,
          unit: Unit.l,
        ),
      ]);
      expect(result.allSucceeded, isFalse);
      expect(result.outcomes.single.message, contains('kg'));
      expect(remaining(await record('Rice')), 0);
    });

    test('undo removes a new item, or just the new batch', () async {
      await addRice(kg: 1);
      final CommandRunResult result = await run(<CommandAction>[
        const CommandAction(
          intent: CommandIntent.addStock,
          itemName: 'Rice',
          quantity: 2,
          unit: Unit.kg,
        ),
        const CommandAction(
          intent: CommandIntent.addStock,
          itemName: 'Salt',
          quantity: 1,
          unit: Unit.kg,
        ),
      ]);
      expect(remaining(await record('Rice')), 3);
      await result.undoAll();
      expect(remaining(await record('Rice')), 1);
      final List<ItemWithBatches> all = await pantry.watchItems().first;
      expect(all.map((ItemWithBatches r) => r.item.name), <String>['Rice']);
    });

    test('an AI-read command teaches an existing item the new word', () async {
      await addRice();
      await run(
        <CommandAction>[
          const CommandAction(
            intent: CommandIntent.addStock,
            itemName: 'Rice',
            originalText: 'chawal',
            quantity: 1,
          ),
        ],
        learn: true,
      );
      expect((await record('Rice')).item.aliases, <String>['biyyam', 'chawal']);
    });

    test('an offline-read command does not touch aliases', () async {
      await addRice();
      await run(<CommandAction>[
        const CommandAction(
          intent: CommandIntent.addStock,
          itemName: 'Rice',
          originalText: 'chawal',
          quantity: 1,
        ),
      ]);
      expect((await record('Rice')).item.aliases, <String>['biyyam']);
    });
  });

  group('use_stock and mark_finished', () {
    test('uses stock first-expiring first and can be undone', () async {
      await addRice(kg: 3);
      final CommandRunResult result = await run(<CommandAction>[
        const CommandAction(
          intent: CommandIntent.useStock,
          itemName: 'Rice',
          quantity: 500,
          unit: Unit.g,
        ),
      ]);
      expect(remaining(await record('Rice')), closeTo(2.5, 0.0001));
      await result.undoAll();
      expect(remaining(await record('Rice')), closeTo(3, 0.0001));
    });

    test('asks for an amount, and refuses more than is there', () async {
      await addRice(kg: 1);
      final CommandRunResult noAmount = await run(<CommandAction>[
        const CommandAction(intent: CommandIntent.useStock, itemName: 'Rice'),
      ]);
      expect(noAmount.allSucceeded, isFalse);
      final CommandRunResult tooMuch = await run(<CommandAction>[
        const CommandAction(
          intent: CommandIntent.useStock,
          itemName: 'Rice',
          quantity: 5,
          unit: Unit.kg,
        ),
      ]);
      expect(tooMuch.allSucceeded, isFalse);
      expect(remaining(await record('Rice')), 1);
    });

    test('an item that is not in the pantry fails with a clear message',
        () async {
      final CommandRunResult result = await run(<CommandAction>[
        const CommandAction(
          intent: CommandIntent.useStock,
          itemName: 'Saffron',
          quantity: 1,
        ),
      ]);
      expect(result.outcomes.single.succeeded, isFalse);
      expect(result.outcomes.single.message, 'Saffron is not in your pantry.');
    });

    test('mark_finished empties every batch, and undo restores them',
        () async {
      final Item rice = await addRice(kg: 2);
      await pantry.addBatch(
        BatchDraft(
          itemId: rice.id,
          quantityBought: 1.5,
          unit: Unit.kg,
          purchaseDate: DateTime(2026, 11, 2),
          storageLocation: StorageLocation.pantry,
        ),
      );
      final CommandRunResult result = await run(<CommandAction>[
        const CommandAction(
          intent: CommandIntent.markFinished,
          itemName: 'Rice',
        ),
      ]);
      expect(remaining(await record('Rice')), 0);
      await result.undoAll();
      expect(remaining(await record('Rice')), closeTo(3.5, 0.0001));
    });

    test('finishing something already finished is a harmless success',
        () async {
      await addRice();
      final CommandRunResult result = await run(<CommandAction>[
        const CommandAction(
          intent: CommandIntent.markFinished,
          itemName: 'Rice',
        ),
      ]);
      expect(result.allSucceeded, isTrue);
      expect(result.outcomes.single.message, contains('already finished'));
      expect(result.hasUndo, isFalse);
    });
  });

  group('shopping list', () {
    test('adds an entry linked to the pantry item, marked as voice', () async {
      final Item rice = await addRice();
      final CommandRunResult result = await run(<CommandAction>[
        const CommandAction(
          intent: CommandIntent.addToShoppingList,
          itemName: 'Rice',
          quantity: 2,
          unit: Unit.kg,
        ),
      ]);
      expect(result.allSucceeded, isTrue);
      final List<ShoppingEntry> entries = await shop.watchEntries().first;
      expect(entries.single.itemId, rice.id);
      expect(entries.single.addedReason, AddedReason.voice);
      expect(entries.single.quantity, 2);
    });

    test('an unknown product becomes a free-text entry', () async {
      await run(<CommandAction>[
        const CommandAction(
          intent: CommandIntent.addToShoppingList,
          itemName: 'Saffron',
          quantity: 1,
          unit: Unit.packet,
        ),
      ]);
      final List<ShoppingEntry> entries = await shop.watchEntries().first;
      expect(entries.single.itemId, isNull);
      expect(entries.single.name, 'Saffron');
    });

    test('adding the same thing again merges, and undo restores the amount',
        () async {
      await addRice();
      const CommandAction add = CommandAction(
        intent: CommandIntent.addToShoppingList,
        itemName: 'Rice',
        quantity: 2,
        unit: Unit.kg,
      );
      await run(<CommandAction>[add]);
      final CommandRunResult second = await run(<CommandAction>[add]);
      expect((await shop.watchEntries().first).single.quantity, 4);
      await second.undoAll();
      expect((await shop.watchEntries().first).single.quantity, 2);
    });

    test('removes by name and undo brings it back', () async {
      await run(<CommandAction>[
        const CommandAction(
          intent: CommandIntent.addToShoppingList,
          itemName: 'Milk',
          quantity: 1,
          unit: Unit.l,
        ),
      ]);
      final CommandRunResult result = await run(<CommandAction>[
        const CommandAction(
          intent: CommandIntent.removeFromShoppingList,
          itemName: 'Milk',
        ),
      ]);
      expect(result.allSucceeded, isTrue);
      expect(await shop.watchEntries().first, isEmpty);
      await result.undoAll();
      expect(await shop.watchEntries().first, hasLength(1));
    });

    test('removing something that is not on the list says so', () async {
      final CommandRunResult result = await run(<CommandAction>[
        const CommandAction(
          intent: CommandIntent.removeFromShoppingList,
          itemName: 'Milk',
        ),
      ]);
      expect(result.allSucceeded, isFalse);
    });
  });

  group('questions', () {
    test('query_stock answers without changing anything', () async {
      await addRice(kg: 2.5);
      final CommandRunResult result = await run(<CommandAction>[
        const CommandAction(intent: CommandIntent.queryStock, itemName: 'Rice'),
      ]);
      expect(result.onlyQueries, isTrue);
      expect(result.outcomes.single.message, startsWith('Rice: 2.5 kg left'));
      expect(result.hasUndo, isFalse);
    });

    test('query_expiring lists what is expiring', () async {
      final Item milk = await pantry.addItem(
        const ItemDraft(
          name: 'Milk',
          categoryId: 'cat_dairy',
          defaultUnit: Unit.l,
        ),
      );
      await pantry.addBatch(
        BatchDraft(
          itemId: milk.id,
          quantityBought: 1,
          unit: Unit.l,
          purchaseDate: DateTime(2026, 11, 3),
          expiryDate: DateTime(2026, 11, 5),
          storageLocation: StorageLocation.fridge,
        ),
      );
      final CommandRunResult result = await run(<CommandAction>[
        const CommandAction(intent: CommandIntent.queryExpiring, itemName: ''),
      ]);
      expect(result.outcomes.single.message, contains('Milk'));
    });

    test('nothing expiring is said plainly', () async {
      final CommandRunResult result = await run(<CommandAction>[
        const CommandAction(intent: CommandIntent.queryExpiring, itemName: ''),
      ]);
      expect(result.outcomes.single.message, startsWith('Nothing is expiring'));
    });
  });

  test('one failing action does not stop the others', () async {
    await addRice(kg: 1);
    final CommandRunResult result = await run(<CommandAction>[
      const CommandAction(
        intent: CommandIntent.useStock,
        itemName: 'Saffron',
        quantity: 1,
      ),
      const CommandAction(
        intent: CommandIntent.useStock,
        itemName: 'Rice',
        quantity: 0.5,
        unit: Unit.kg,
      ),
    ]);
    expect(result.outcomes.map((ActionOutcome o) => o.succeeded), <bool>[
      false,
      true,
    ]);
    expect(remaining(await record('Rice')), closeTo(0.5, 0.0001));
  });
}
