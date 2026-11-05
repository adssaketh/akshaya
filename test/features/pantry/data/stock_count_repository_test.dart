import 'package:akshaya/features/pantry/data/database/app_database.dart';
import 'package:akshaya/features/pantry/data/drift_pantry_repository.dart';
import 'package:akshaya/features/pantry/domain/consumption_type.dart';
import 'package:akshaya/features/pantry/domain/entities.dart';
import 'package:akshaya/features/pantry/domain/failures.dart';
import 'package:akshaya/features/pantry/domain/stock_count.dart';
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

  Future<Item> addRice() {
    return repo.addItem(
      const ItemDraft(
        name: 'Rice',
        categoryId: 'cat_grains',
        defaultUnit: Unit.kg,
      ),
    );
  }

  Future<StockBatch> addBatch(
    Item item,
    double kg, {
    DateTime? expiry,
    StorageLocation location = StorageLocation.pantry,
  }) {
    return repo.addBatch(
      BatchDraft(
        itemId: item.id,
        quantityBought: kg,
        unit: Unit.kg,
        purchaseDate: DateTime(2026, 10, 20),
        expiryDate: expiry,
        storageLocation: location,
      ),
    );
  }

  Future<ItemWithBatches> load(Item item) async {
    final List<ItemWithBatches> all = await repo.watchItems().first;
    return all.firstWhere((ItemWithBatches r) => r.item.id == item.id);
  }

  double total(ItemWithBatches r) {
    double sum = 0;
    for (final StockBatch b in r.batches) {
      sum += b.unit.convertTo(b.quantityRemaining, r.item.defaultUnit);
    }
    return sum;
  }

  Future<List<ConsumptionEntry>> history(Item item) {
    return repo.watchHistory(item.id).first;
  }

  group('less than expected', () {
    test('lowers the batch expiring first and logs an adjustment', () async {
      final Item rice = await addRice();
      final StockBatch later =
          await addBatch(rice, 2, expiry: DateTime(2026, 12, 1));
      final StockBatch sooner =
          await addBatch(rice, 1, expiry: DateTime(2026, 11, 10));

      final CountResult result = await repo.setStock(
        itemId: rice.id,
        quantity: 2,
        unit: Unit.kg,
      );

      expect(result.changed, isTrue);
      expect(result.before, 3);
      expect(result.after, 2);
      expect(result.difference, -1);
      final ItemWithBatches r = await load(rice);
      expect(
        r.batches.firstWhere((StockBatch b) => b.id == sooner.id)
            .quantityRemaining,
        0,
      );
      expect(
        r.batches.firstWhere((StockBatch b) => b.id == later.id)
            .quantityRemaining,
        2,
      );
      final List<ConsumptionEntry> log = await history(rice);
      expect(log, hasLength(1));
      expect(log.single.type, ConsumptionType.adjustment);
      expect(log.single.quantityUsed, 1);
      expect(log.single.amountLabel, '-1 kg');
    });

    test('logs waste instead when the missing amount was wasted', () async {
      final Item rice = await addRice();
      await addBatch(rice, 3);

      await repo.setStock(
        itemId: rice.id,
        quantity: 2,
        unit: Unit.kg,
        asWaste: true,
      );

      final List<ConsumptionEntry> log = await history(rice);
      expect(log.single.type, ConsumptionType.wasted);
      expect(total(await load(rice)), 2);
    });

    test('zero empties the item', () async {
      final Item rice = await addRice();
      await addBatch(rice, 2);
      await addBatch(rice, 1);

      final CountResult result = await repo.setStock(
        itemId: rice.id,
        quantity: 0,
        unit: Unit.kg,
      );

      expect(result.after, 0);
      expect(total(await load(rice)), 0);
    });

    test('a count in grams converts to the item unit', () async {
      final Item rice = await addRice();
      await addBatch(rice, 2);

      await repo.setStock(itemId: rice.id, quantity: 500, unit: Unit.g);

      expect(total(await load(rice)), closeTo(0.5, 0.0001));
    });

    test('undo restores the batches and removes the log', () async {
      final Item rice = await addRice();
      await addBatch(rice, 3);
      final CountResult result = await repo.setStock(
        itemId: rice.id,
        quantity: 1,
        unit: Unit.kg,
      );

      await repo.undoCount(result);

      expect(total(await load(rice)), 3);
      expect(await history(rice), isEmpty);
    });
  });

  group('more than expected', () {
    test('adds a batch for the surplus with a negative adjustment', () async {
      final Item rice = await addRice();
      await addBatch(rice, 1, expiry: DateTime(2026, 12, 1));

      final CountResult result = await repo.setStock(
        itemId: rice.id,
        quantity: 3,
        unit: Unit.kg,
      );

      expect(result.changed, isTrue);
      expect(result.difference, 2);
      final ItemWithBatches r = await load(rice);
      expect(r.batches, hasLength(2));
      expect(total(r), 3);
      final StockBatch added =
          r.batches.firstWhere((StockBatch b) => b.id == result.addedBatchId);
      expect(added.quantityBought, 2);
      expect(added.quantityRemaining, 2);
      expect(added.purchaseDate, DateTime(2026, 11, 4));
      expect(added.expiryDate, isNull);
      expect(added.price, isNull);
      final List<ConsumptionEntry> log = await history(rice);
      expect(log.single.type, ConsumptionType.adjustment);
      expect(log.single.quantityUsed, -2);
      expect(log.single.amountLabel, '+2 kg');
    });

    test('undo removes the new batch and its log', () async {
      final Item rice = await addRice();
      await addBatch(rice, 1);
      final CountResult result = await repo.setStock(
        itemId: rice.id,
        quantity: 3,
        unit: Unit.kg,
      );

      await repo.undoCount(result);

      final ItemWithBatches r = await load(rice);
      expect(r.batches, hasLength(1));
      expect(total(r), 1);
      expect(await history(rice), isEmpty);
    });
  });

  test('the same amount writes nothing', () async {
    final Item rice = await addRice();
    await addBatch(rice, 2);

    final CountResult result = await repo.setStock(
      itemId: rice.id,
      quantity: 2,
      unit: Unit.kg,
    );

    expect(result.changed, isFalse);
    expect(result.difference, 0);
    expect(await history(rice), isEmpty);
    expect((await load(rice)).batches, hasLength(1));
    // Undo of an unchanged count is harmless.
    await repo.undoCount(result);
    expect(total(await load(rice)), 2);
  });

  group('counting one storage location', () {
    test('only that location is compared and lowered', () async {
      final Item rice = await addRice();
      final StockBatch fridge =
          await addBatch(rice, 1, location: StorageLocation.fridge);
      final StockBatch shelf =
          await addBatch(rice, 2, location: StorageLocation.pantry);

      final CountResult result = await repo.setStock(
        itemId: rice.id,
        quantity: 0.5,
        unit: Unit.kg,
        location: StorageLocation.fridge,
      );

      expect(result.before, 1);
      expect(result.after, 0.5);
      final ItemWithBatches r = await load(rice);
      expect(
        r.batches.firstWhere((StockBatch b) => b.id == fridge.id)
            .quantityRemaining,
        0.5,
      );
      expect(
        r.batches.firstWhere((StockBatch b) => b.id == shelf.id)
            .quantityRemaining,
        2,
      );
    });

    test('a surplus is added in that location', () async {
      final Item rice = await addRice();
      await addBatch(rice, 1, location: StorageLocation.fridge);

      final CountResult result = await repo.setStock(
        itemId: rice.id,
        quantity: 2,
        unit: Unit.kg,
        location: StorageLocation.fridge,
      );

      final ItemWithBatches r = await load(rice);
      final StockBatch added =
          r.batches.firstWhere((StockBatch b) => b.id == result.addedBatchId);
      expect(added.storageLocation, StorageLocation.fridge);
      expect(added.quantityRemaining, 1);
    });
  });

  group('refuses bad input', () {
    test('a negative amount', () async {
      final Item rice = await addRice();
      await addBatch(rice, 2);

      await expectLater(
        repo.setStock(itemId: rice.id, quantity: -1, unit: Unit.kg),
        throwsA(isA<InvalidInputFailure>()),
      );
      expect(total(await load(rice)), 2);
    });

    test('a unit that does not convert', () async {
      final Item rice = await addRice();
      await addBatch(rice, 2);

      await expectLater(
        repo.setStock(itemId: rice.id, quantity: 2, unit: Unit.pcs),
        throwsA(isA<UnitMismatchFailure>()),
      );
    });

    test('an item that does not exist', () async {
      await expectLater(
        repo.setStock(itemId: 'nope', quantity: 1, unit: Unit.kg),
        throwsA(isA<PantryFailure>()),
      );
    });
  });
}
