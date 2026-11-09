import 'package:akshaya/features/pantry/data/database/app_database.dart';
import 'package:akshaya/features/pantry/data/drift_pantry_repository.dart';
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
  late DateTime now;
  int counter = 0;

  setUp(() {
    counter = 0;
    now = DateTime(2026, 11, 4, 10);
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftPantryRepository(
      db,
      clock: () => now,
      idGenerator: () => 'id-${counter++}',
    );
  });

  tearDown(() => db.close());

  Future<Item> addItem(String name) => repo.addItem(
    ItemDraft(name: name, categoryId: 'cat_grains', defaultUnit: Unit.kg),
  );

  Future<StockBatch> addBatch(String itemId, double qty) => repo.addBatch(
    BatchDraft(
      itemId: itemId,
      quantityBought: qty,
      unit: Unit.kg,
      purchaseDate: DateTime(2026, 11, 1),
      storageLocation: StorageLocation.pantry,
    ),
  );

  Future<List<DeletedItem>> bin({Duration? within}) =>
      (within == null
              ? repo.watchDeletedItems()
              : repo.watchDeletedItems(within: within))
          .first;

  Future<List<ItemWithBatches>> live() => repo.watchItems().first;

  test('nothing is in the bin until something is deleted', () async {
    await addItem('Rice');
    expect(await bin(), isEmpty);
  });

  test('a deleted item is in the bin, and out of the pantry', () async {
    final Item rice = await addItem('Rice');
    await repo.deleteItem(rice.id);
    final List<DeletedItem> items = await bin();
    expect(items.single.item.name, 'Rice');
    expect(items.single.deletedAt, now);
    expect(await live(), isEmpty);
  });

  test('it remembers how many batches went with it', () async {
    final Item rice = await addItem('Rice');
    await addBatch(rice.id, 5);
    await addBatch(rice.id, 2);
    await repo.deleteItem(rice.id);
    expect((await bin()).single.batchCount, 2);
  });

  test('restoring brings back the item and every batch it had', () async {
    final Item rice = await addItem('Rice');
    await addBatch(rice.id, 5);
    await addBatch(rice.id, 2);
    await repo.deleteItem(rice.id);
    now = now.add(const Duration(hours: 3));
    await repo.restoreDeletedItem(rice.id);
    final List<ItemWithBatches> back = await live();
    expect(back.single.item.name, 'Rice');
    expect(back.single.batches.length, 2);
    expect(
      back.single.batches.map((StockBatch b) => b.quantityRemaining).toList()
        ..sort(),
      <double>[2, 5],
    );
    expect(await bin(), isEmpty);
  });

  test('a batch deleted on its own earlier stays deleted when the item '
      'is restored', () async {
    final Item rice = await addItem('Rice');
    final StockBatch old = await addBatch(rice.id, 9);
    await addBatch(rice.id, 2);
    await repo.deleteBatch(old.id);
    now = now.add(const Duration(days: 2));
    await repo.deleteItem(rice.id);
    now = now.add(const Duration(hours: 1));
    await repo.restoreDeletedItem(rice.id);
    final ItemWithBatches back = (await live()).single;
    expect(back.batches.map((StockBatch b) => b.quantityRemaining), <double>[
      2,
    ]);
  });

  test('newest deletion is first', () async {
    final Item a = await addItem('Rice');
    final Item b = await addItem('Dal');
    await repo.deleteItem(a.id);
    now = now.add(const Duration(hours: 1));
    await repo.deleteItem(b.id);
    expect((await bin()).map((DeletedItem d) => d.item.name), <String>[
      'Dal',
      'Rice',
    ]);
  });

  test('items older than the limit are no longer in the bin', () async {
    final Item rice = await addItem('Rice');
    await repo.deleteItem(rice.id);
    now = now.add(const Duration(days: 31));
    expect(await bin(), isEmpty);
    now = DateTime(2026, 11, 4, 10).add(const Duration(days: 29));
    expect(await bin(), hasLength(1));
    expect(await bin(within: const Duration(days: 7)), isEmpty);
  });

  test('restoring while a live item has the same name is refused, and '
      'nothing changes', () async {
    final Item old = await addItem('Rice');
    await addBatch(old.id, 5);
    await repo.deleteItem(old.id);
    await addItem('rice');
    await expectLater(
      repo.restoreDeletedItem(old.id),
      throwsA(isA<DuplicateItemFailure>()),
    );
    expect(await bin(), hasLength(1));
    expect(await live(), hasLength(1));
  });

  test('restoring something that is not in the bin says so', () async {
    final Item rice = await addItem('Rice');
    await expectLater(
      repo.restoreDeletedItem(rice.id),
      throwsA(isA<NotFoundFailure>()),
    );
    await expectLater(
      repo.restoreDeletedItem('nope'),
      throwsA(isA<NotFoundFailure>()),
    );
  });

  test('restoring twice does not duplicate', () async {
    final Item rice = await addItem('Rice');
    await repo.deleteItem(rice.id);
    await repo.restoreDeletedItem(rice.id);
    await expectLater(
      repo.restoreDeletedItem(rice.id),
      throwsA(isA<NotFoundFailure>()),
    );
    expect(await live(), hasLength(1));
  });

  test('the item keeps its aliases and details', () async {
    final Item rice = await repo.addItem(
      const ItemDraft(
        name: 'Rice',
        categoryId: 'cat_grains',
        defaultUnit: Unit.kg,
        aliases: <String>['biyyam', 'chawal'],
      ),
    );
    await repo.deleteItem(rice.id);
    expect(
      (await bin()).single.item.aliases,
      containsAll(<String>['biyyam', 'chawal']),
    );
    await repo.restoreDeletedItem(rice.id);
    expect(
      (await live()).single.item.aliases,
      containsAll(<String>['biyyam', 'chawal']),
    );
  });

  test('a deleted item can be deleted and restored again and again', () async {
    final Item rice = await addItem('Rice');
    await addBatch(rice.id, 5);
    for (int i = 0; i < 3; i++) {
      now = now.add(const Duration(hours: 1));
      await repo.deleteItem(rice.id);
      expect(await bin(), hasLength(1));
      now = now.add(const Duration(hours: 1));
      await repo.restoreDeletedItem(rice.id);
      expect((await live()).single.batches, hasLength(1));
    }
  });

  test(
    'restoring marks it for syncing, so other phones get it back too',
    () async {
      final Item rice = await addItem('Rice');
      await repo.deleteItem(rice.id);
      await repo.restoreDeletedItem(rice.id);
      final ItemRow row = await (db.select(
        db.items,
      )..where((t) => t.id.equals(rice.id))).getSingle();
      expect(row.isDeleted, isFalse);
      expect(row.syncStatus.name, 'pending');
    },
  );

  test('the Undo after a delete and the bin agree', () async {
    final Item rice = await addItem('Rice');
    await addBatch(rice.id, 5);
    final DeleteToken token = await repo.deleteItem(rice.id);
    await repo.undoDeleteItem(token);
    expect(await bin(), isEmpty);
    expect((await live()).single.batches, hasLength(1));
  });
}
