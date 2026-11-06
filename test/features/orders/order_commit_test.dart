import 'package:akshaya/features/orders/domain/order_commit.dart';
import 'package:akshaya/features/orders/domain/order_models.dart';
import 'package:akshaya/features/pantry/data/database/app_database.dart';
import 'package:akshaya/features/pantry/data/drift_pantry_repository.dart';
import 'package:akshaya/features/pantry/domain/entities.dart';
import 'package:akshaya/features/pantry/domain/storage_location.dart';
import 'package:akshaya/features/pantry/domain/unit.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late DriftPantryRepository repo;
  late OrderCommitter committer;
  int counter = 0;
  final DateTime boughtOn = DateTime(2026, 11, 6);

  setUp(() {
    counter = 0;
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftPantryRepository(
      db,
      clock: () => DateTime(2026, 11, 6, 10),
      idGenerator: () => 'id-${counter++}',
    );
    committer = OrderCommitter(repo);
  });

  tearDown(() => db.close());

  OrderDraft draft(
    String name, {
    double quantity = 1,
    Unit unit = Unit.kg,
    double? price,
    String categoryId = 'cat_grains',
    StorageLocation location = StorageLocation.pantry,
    bool include = true,
    String? sourceName,
    int? estimateDays,
    DateTime? expiry,
    String? brand,
  }) {
    return OrderDraft(
      id: name,
      sourceName: sourceName ?? name,
      name: name,
      brand: brand,
      quantity: quantity,
      unit: unit,
      price: price,
      categoryId: categoryId,
      location: location,
      include: include,
      estimateDays: estimateDays,
      expiry: expiry,
    );
  }

  Future<List<ItemWithBatches>> all() => repo.watchItems().first;

  test('adds a new item with a batch: price, store, place and guessed expiry',
      () async {
    final OrderCommitResult result = await committer.commit(
      <OrderDraft>[
        draft(
          'Milk',
          unit: Unit.l,
          price: 76,
          categoryId: 'cat_dairy',
          location: StorageLocation.fridge,
          estimateDays: 3,
          sourceName: "Sid's Farm Toned Milk",
          brand: "Sid's Farm",
        ),
      ],
      boughtOn: boughtOn,
      store: ' Zepto ',
    );
    expect(result.added, 1);
    expect(result.failures, isEmpty);
    final List<ItemWithBatches> items = await all();
    expect(items.single.item.name, 'Milk');
    expect(items.single.item.brand, "Sid's Farm");
    expect(items.single.item.aliases, <String>["Sid's Farm Toned Milk"]);
    expect(items.single.item.defaultStorageLocation, StorageLocation.fridge);
    final StockBatch batch = items.single.batches.single;
    expect(batch.quantityBought, 1);
    expect(batch.unit, Unit.l);
    expect(batch.price, 76);
    expect(batch.store, 'Zepto');
    expect(batch.storageLocation, StorageLocation.fridge);
    expect(batch.purchaseDate, boughtOn);
    expect(batch.expiryDate, DateTime(2026, 11, 9));
  });

  test('a chosen date wins over the guess', () async {
    await committer.commit(
      <OrderDraft>[
        draft('Curd',
            unit: Unit.g,
            estimateDays: 3,
            expiry: DateTime(2026, 11, 20)),
      ],
      boughtOn: boughtOn,
    );
    expect((await all()).single.batches.single.expiryDate, DateTime(2026, 11, 20));
  });

  test('adds a batch to an item the pantry already has', () async {
    final Item rice = await repo.addItem(
      const ItemDraft(
        name: 'Rice',
        categoryId: 'cat_grains',
        defaultUnit: Unit.kg,
      ),
    );
    final OrderCommitResult result = await committer.commit(
      <OrderDraft>[draft('rice', quantity: 5)],
      boughtOn: boughtOn,
    );
    expect(result.added, 1);
    expect(result.createdItemIds, isEmpty);
    final List<ItemWithBatches> items = await all();
    expect(items.length, 1);
    expect(items.single.item.id, rice.id);
    expect(items.single.batches.single.quantityBought, 5);
  });

  test('unticked lines are not added', () async {
    final OrderCommitResult result = await committer.commit(
      <OrderDraft>[
        draft('Harpic', include: false, categoryId: 'cat_cleaning'),
        draft('Garlic', unit: Unit.g, categoryId: 'cat_vegetables'),
      ],
      boughtOn: boughtOn,
    );
    expect(result.added, 1);
    expect((await all()).map((ItemWithBatches r) => r.item.name), <String>['Garlic']);
  });

  test('a line in a different kind of unit fails alone', () async {
    await repo.addItem(
      const ItemDraft(
        name: 'Rice',
        categoryId: 'cat_grains',
        defaultUnit: Unit.kg,
      ),
    );
    final OrderCommitResult result = await committer.commit(
      <OrderDraft>[
        draft('Rice', unit: Unit.l),
        draft('Onion', categoryId: 'cat_vegetables'),
      ],
      boughtOn: boughtOn,
    );
    expect(result.added, 1);
    expect(result.failures.length, 1);
    expect(result.failures.single, startsWith('Rice:'));
    expect(
      (await all()).firstWhere((ItemWithBatches r) => r.item.name == 'Onion').batches,
      hasLength(1),
    );
  });

  test('a name that is only the printed name adds no alias', () async {
    await committer.commit(<OrderDraft>[draft('Onion')], boughtOn: boughtOn);
    expect((await all()).single.item.aliases, isEmpty);
  });

  test('undo takes back new items and new batches', () async {
    final Item rice = await repo.addItem(
      const ItemDraft(
        name: 'Rice',
        categoryId: 'cat_grains',
        defaultUnit: Unit.kg,
      ),
    );
    final OrderCommitResult result = await committer.commit(
      <OrderDraft>[draft('Rice', quantity: 2), draft('Onion')],
      boughtOn: boughtOn,
    );
    expect((await all()).length, 2);
    await committer.undo(result);
    final List<ItemWithBatches> items = await all();
    expect(items.single.item.id, rice.id);
    expect(items.single.batches, isEmpty);
  });
}
