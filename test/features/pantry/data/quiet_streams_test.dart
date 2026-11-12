import 'dart:async';

import 'package:akshaya/features/pantry/data/database/app_database.dart';
import 'package:akshaya/features/pantry/data/drift_pantry_repository.dart';
import 'package:akshaya/features/pantry/domain/entities.dart';
import 'package:akshaya/features/pantry/domain/unit.dart';
import 'package:akshaya/features/sync/data/sync_store.dart';
import 'package:drift/drift.dart' show TableUpdate, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Watched lists must stay quiet when nothing they show has changed: every
/// emission rebuilds the screens that show them.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late DriftPantryRepository pantry;
  int counter = 0;

  setUp(() {
    counter = 0;
    db = AppDatabase(NativeDatabase.memory());
    pantry = DriftPantryRepository(
      db,
      clock: () => DateTime(2026, 11, 12, 10),
      idGenerator: () => 'id-${counter++}',
    );
  });

  tearDown(() => db.close());

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 50));

  Future<void> addRice() => pantry.addItem(
    const ItemDraft(
      name: 'Rice',
      categoryId: 'cat_grains',
      defaultUnit: Unit.kg,
    ),
  );

  test('items: a touch that changes nothing does not emit again', () async {
    await addRice();
    final List<List<ItemWithBatches>> seen = <List<ItemWithBatches>>[];
    final StreamSubscription<List<ItemWithBatches>> sub = pantry
        .watchItems()
        .listen(seen.add);
    await settle();
    expect(seen, hasLength(1));

    db.notifyUpdates(<TableUpdate>{
      const TableUpdate('items'),
      const TableUpdate('stock_batches'),
    });
    await settle();
    expect(seen, hasLength(1), reason: 'same rows, no new list');

    await pantry.addItem(
      const ItemDraft(
        name: 'Dal',
        categoryId: 'cat_grains',
        defaultUnit: Unit.kg,
      ),
    );
    await settle();
    expect(seen, hasLength(2), reason: 'a real change still comes through');
    expect(seen.last, hasLength(2));
    await sub.cancel();
  });

  test('history: an unchanged reload is dropped', () async {
    final List<List<ConsumptionEntry>> seen = <List<ConsumptionEntry>>[];
    final StreamSubscription<List<ConsumptionEntry>> sub = pantry
        .watchAllHistory()
        .listen(seen.add);
    await settle();
    db.markTablesUpdated(db.allTables);
    await settle();
    expect(seen, hasLength(1));
    await sub.cancel();
  });

  test(
    'sync: assigning a household announces only tables that changed',
    () async {
      final SyncStore store = SyncStore(db);
      await addRice();
      await store.assignHousehold('h1');

      final List<Set<TableUpdate>> updates = <Set<TableUpdate>>[];
      final StreamSubscription<Set<TableUpdate>> sub = db.tableUpdates().listen(
        updates.add,
      );
      await store.assignHousehold('h1');
      await settle();
      expect(updates, isEmpty, reason: 'every row already belongs to h1');

      await pantry.addItem(
        const ItemDraft(
          name: 'Dal',
          categoryId: 'cat_grains',
          defaultUnit: Unit.kg,
        ),
      );
      await settle();
      updates.clear();
      await store.assignHousehold('h1');
      await settle();
      final Set<String> tables = <String>{
        for (final Set<TableUpdate> u in updates)
          for (final TableUpdate t in u) t.table,
      };
      expect(tables, contains('items'));
      expect(tables, isNot(contains('shopping_entries')));
      await sub.cancel();
    },
  );

  test('changedElsewhere: own writes do not count', () async {
    expect(await db.changedElsewhere(), isTrue, reason: 'first look');
    await addRice();
    expect(await db.changedElsewhere(), isFalse);
  });
}
