import 'package:akshaya/features/pantry/data/database/app_database.dart';
import 'package:akshaya/features/pantry/data/drift_pantry_repository.dart';
import 'package:akshaya/features/pantry/domain/consumption_type.dart';
import 'package:akshaya/features/pantry/domain/entities.dart';
import 'package:akshaya/features/pantry/domain/failures.dart';
import 'package:akshaya/features/pantry/domain/storage_location.dart';
import 'package:akshaya/features/pantry/domain/unit.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late DriftPantryRepository repo;
  int counter = 0;

  setUp(() {
    counter = 0;
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftPantryRepository(
      db,
      clock: () => DateTime(2026, 11, 4, 10),
      idGenerator: () => 'id-${counter++}',
    );
  });

  tearDown(() => db.close());

  ItemDraft rice({List<String> aliases = const <String>[], String? barcode}) {
    return ItemDraft(
      name: 'Rice',
      categoryId: 'cat_grains',
      defaultUnit: Unit.kg,
      aliases: aliases,
      barcode: barcode,
    );
  }

  BatchDraft batch(
    String itemId,
    double qty, {
    DateTime? expiry,
    Unit unit = Unit.kg,
  }) {
    return BatchDraft(
      itemId: itemId,
      quantityBought: qty,
      unit: unit,
      purchaseDate: DateTime(2026, 11, 1),
      expiryDate: expiry,
      storageLocation: StorageLocation.pantry,
    );
  }

  Future<ItemWithBatches> load(String itemId) async {
    final List<ItemWithBatches> all = await repo.watchItems().first;
    return all.firstWhere((ItemWithBatches r) => r.item.id == itemId);
  }

  test('seeds the default categories', () async {
    final List<Category> cats = await repo.watchCategories().first;
    expect(cats.length, 15);
  });

  test('adds an item with aliases and finds it by name', () async {
    final Item item = await repo.addItem(rice(aliases: <String>['బియ్యం', 'chawal']));
    expect(item.aliases, containsAll(<String>['బియ్యం', 'chawal']));
    expect((await repo.findItemByName('rice'))?.id, item.id);
  });

  test('rejects duplicate names and barcodes', () async {
    await repo.addItem(rice(barcode: '123'));
    await expectLater(
      repo.addItem(rice()),
      throwsA(isA<DuplicateItemFailure>()),
    );
    await expectLater(
      repo.addItem(
        const ItemDraft(
          name: 'Other',
          categoryId: 'cat_other',
          defaultUnit: Unit.pcs,
          barcode: '123',
        ),
      ),
      throwsA(isA<DuplicateBarcodeFailure>()),
    );
  });

  test('rejects empty names, zero quantity and unit mismatch', () async {
    await expectLater(
      repo.addItem(
        const ItemDraft(name: '  ', categoryId: 'cat_other', defaultUnit: Unit.pcs),
      ),
      throwsA(isA<InvalidInputFailure>()),
    );
    final Item item = await repo.addItem(rice());
    await expectLater(repo.addBatch(batch(item.id, 0)), throwsA(isA<InvalidInputFailure>()));
    await expectLater(
      repo.addBatch(batch(item.id, 1, unit: Unit.l)),
      throwsA(isA<UnitMismatchFailure>()),
    );
  });

  test('useStock deducts FIFO and logs', () async {
    final Item item = await repo.addItem(rice());
    final StockBatch late = await repo.addBatch(batch(item.id, 2, expiry: DateTime(2026, 12, 30)));
    final StockBatch soon = await repo.addBatch(batch(item.id, 1, expiry: DateTime(2026, 11, 10)));

    final UseResult result = await repo.useStock(
      itemId: item.id,
      quantity: 1.5,
      unit: Unit.kg,
    );
    expect(result.applied.length, 2);

    final ItemWithBatches after = await load(item.id);
    StockBatch find(String id) => after.batches.firstWhere((StockBatch b) => b.id == id);
    expect(find(soon.id).quantityRemaining, 0);
    expect(find(late.id).quantityRemaining, 1.5);

    final List<ConsumptionEntry> history = await repo.watchHistory(item.id).first;
    expect(history.length, 2);
    expect(history.every((ConsumptionEntry e) => e.type == ConsumptionType.used), isTrue);
  });

  test('useStock in grams against a kg batch', () async {
    final Item item = await repo.addItem(rice());
    await repo.addBatch(batch(item.id, 1));
    await repo.useStock(itemId: item.id, quantity: 250, unit: Unit.g);
    expect((await load(item.id)).batches.single.quantityRemaining, 0.75);
  });

  test('useStock more than available fails and changes nothing', () async {
    final Item item = await repo.addItem(rice());
    await repo.addBatch(batch(item.id, 1));
    await expectLater(
      repo.useStock(itemId: item.id, quantity: 3, unit: Unit.kg),
      throwsA(isA<InsufficientStockFailure>()),
    );
    expect((await load(item.id)).batches.single.quantityRemaining, 1);
    expect(await repo.watchHistory(item.id).first, isEmpty);
  });

  test('undoUse restores quantities and removes the log', () async {
    final Item item = await repo.addItem(rice());
    await repo.addBatch(batch(item.id, 2));
    final UseResult result = await repo.useStock(itemId: item.id, quantity: 1, unit: Unit.kg);
    await repo.undoUse(result);
    expect((await load(item.id)).batches.single.quantityRemaining, 2);
    expect(await repo.watchHistory(item.id).first, isEmpty);
  });

  test('discardBatch writes off the remainder', () async {
    final Item item = await repo.addItem(rice());
    final StockBatch b = await repo.addBatch(batch(item.id, 2));
    final UseResult result = await repo.discardBatch(
      batchId: b.id,
      type: ConsumptionType.wasted,
    );
    expect(result.quantity, 2);
    expect((await load(item.id)).batches.single.quantityRemaining, 0);
  });

  test('soft delete hides the item and undo restores it with its batches', () async {
    final Item item = await repo.addItem(rice());
    await repo.addBatch(batch(item.id, 2));
    final DeleteToken token = await repo.deleteItem(item.id);
    expect(await repo.watchItems().first, isEmpty);
    expect(await repo.findItemByName('Rice'), isNull);

    await repo.undoDeleteItem(token);
    expect((await load(item.id)).batches.length, 1);
  });

  test('deleted name can be reused', () async {
    final Item item = await repo.addItem(rice());
    await repo.deleteItem(item.id);
    final Item again = await repo.addItem(rice());
    expect(again.id, isNot(item.id));
  });
}
