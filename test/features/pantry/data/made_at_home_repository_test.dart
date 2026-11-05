import 'package:akshaya/features/pantry/data/database/app_database.dart';
import 'package:akshaya/features/pantry/data/drift_pantry_repository.dart';
import 'package:akshaya/features/pantry/domain/entities.dart';
import 'package:akshaya/features/pantry/domain/failures.dart';
import 'package:akshaya/features/pantry/domain/item_kind.dart';
import 'package:akshaya/features/pantry/domain/storage_location.dart';
import 'package:akshaya/features/pantry/domain/unit.dart';
import 'package:akshaya/features/recipes/domain/cook_plan.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late DriftPantryRepository repo;
  int counter = 0;
  final DateTime today = DateTime(2026, 11, 4);

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

  Future<ItemWithBatches> load(String id) async {
    final List<ItemWithBatches> all = await repo.watchItems().first;
    return all.firstWhere((ItemWithBatches r) => r.item.id == id);
  }

  test('kind, shelf life, container and check-by round-trip', () async {
    final Item item = await repo.addItem(
      const ItemDraft(
        name: 'Mango Pickle',
        categoryId: 'cat_other',
        defaultUnit: Unit.pcs,
        kind: ItemKind.homemade,
        shelfLifeDays: 120,
      ),
    );
    await repo.addBatch(
      BatchDraft(
        itemId: item.id,
        quantityBought: 2,
        unit: Unit.pcs,
        purchaseDate: today,
        storageLocation: StorageLocation.pantry,
        containerLabel: 'glass jar',
        checkBy: DateTime(2026, 12, 1),
      ),
    );
    final ItemWithBatches r = await load(item.id);
    expect(r.item.kind, ItemKind.homemade);
    expect(r.item.shelfLifeDays, 120);
    expect(r.batches.single.containerLabel, 'glass jar');
    expect(r.batches.single.checkBy, DateTime(2026, 12, 1));
  });

  test('stocked items read back as stocked', () async {
    final Item item = await repo.addItem(
      const ItemDraft(name: 'Rice', categoryId: 'cat_grains', defaultUnit: Unit.kg),
    );
    final ItemWithBatches r = await load(item.id);
    expect(r.item.kind, ItemKind.stocked);
    expect(r.item.shelfLifeDays, isNull);
  });

  test('rejects an out-of-range shelf life', () async {
    await expectLater(
      repo.addItem(
        const ItemDraft(
          name: 'Dosa Batter',
          categoryId: 'cat_other',
          defaultUnit: Unit.portion,
          kind: ItemKind.cooked,
          shelfLifeDays: 0,
        ),
      ),
      throwsA(isA<InvalidInputFailure>()),
    );
  });

  group('leftovers from cooking', () {
    const LeftoverPlan plan = LeftoverPlan(
      portions: 2,
      location: StorageLocation.fridge,
    );

    test('creates a Cooked item with a two-day fridge expiry', () async {
      final LeftoverOutcome out = await CookExecutor.saveLeftover(
        repo,
        title: 'Tomato Pappu',
        plan: plan,
        today: today,
      );
      expect(out.createdItem, isTrue);
      final ItemWithBatches r = await load(out.itemId);
      expect(r.item.kind, ItemKind.cooked);
      expect(r.item.defaultUnit, Unit.portion);
      expect(r.batches.single.quantityRemaining, 2);
      expect(r.batches.single.expiryDate, DateTime(2026, 11, 6));
    });

    test('a second batch goes to the same item', () async {
      final LeftoverOutcome a = await CookExecutor.saveLeftover(
        repo, title: 'Tomato Pappu', plan: plan, today: today);
      final LeftoverOutcome b = await CookExecutor.saveLeftover(
        repo, title: 'Tomato Pappu', plan: plan, today: today);
      expect(b.itemId, a.itemId);
      expect(b.createdItem, isFalse);
      expect((await load(a.itemId)).batches.length, 2);
    });

    test('a Stocked item with the same name is left alone', () async {
      final Item stocked = await repo.addItem(
        const ItemDraft(name: 'Curd Rice', categoryId: 'cat_other', defaultUnit: Unit.pcs),
      );
      final LeftoverOutcome out = await CookExecutor.saveLeftover(
        repo, title: 'Curd Rice', plan: plan, today: today);
      expect(out.itemId, isNot(stocked.id));
      expect((await load(out.itemId)).item.name, 'Curd Rice (leftover)');
      expect((await load(stocked.id)).batches, isEmpty);
    });

    test('undo removes the batch and the item it created', () async {
      final LeftoverOutcome out = await CookExecutor.saveLeftover(
        repo, title: 'Sambar', plan: plan, today: today);
      await CookExecutor.undo(
        repo,
        CookOutcome(
          results: const <UseResult>[],
          failures: const <String>[],
          leftover: out,
        ),
      );
      final List<ItemWithBatches> all = await repo.watchItems().first;
      expect(all.where((ItemWithBatches r) => r.item.id == out.itemId), isEmpty);
    });
  });
}
