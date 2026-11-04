import 'package:akshaya/features/pantry/data/database/app_database.dart';
import 'package:akshaya/features/pantry/data/drift_pantry_repository.dart';
import 'package:drift/drift.dart' show QueryRow, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await DriftPantryRepository(db).insertSampleData();
    await db.customStatement("UPDATE items SET sync_status = 'synced'");
  });

  tearDown(() => db.close());

  Future<int> pending() async {
    final List<QueryRow> rows = await db
        .customSelect("SELECT COUNT(*) AS c FROM items WHERE sync_status='pending'")
        .get();
    return (rows.first.data['c']! as num).toInt();
  }

  test('an edit to a synced row marks it pending', () async {
    expect(await pending(), 0);
    await db.customStatement("UPDATE items SET notes = 'x' WHERE rowid = 1");
    expect(await pending(), 1);
  });

  test('changing the status itself does not loop', () async {
    // Moving the status itself (pending, then synced) never re-queues a row.
    await db.customStatement("UPDATE items SET sync_status = 'pending'");
    await db.customStatement("UPDATE items SET sync_status = 'synced'");
    expect(await pending(), 0);
  });

  test('adding an alias marks its item pending', () async {
    await db.customStatement(
      'INSERT INTO item_aliases (id, item_id, alias, created_at) '
      "SELECT 'alias-test', id, 'testalias', 1 FROM items LIMIT 1",
    );
    expect(await pending(), 1);
  });

  test('the suppress flag stops marking', () async {
    await db.customStatement('UPDATE sync_state SET suppress = 1');
    await db.customStatement("UPDATE items SET notes = 'x' WHERE rowid = 1");
    await db.customStatement('UPDATE sync_state SET suppress = 0');
    expect(await pending(), 0);
  });
}
