import 'dart:io';

import 'package:akshaya/features/pantry/data/database/app_database.dart';
import 'package:akshaya/features/pantry/data/drift_pantry_repository.dart';
import 'package:akshaya/features/sync/data/sync_engine.dart';
import 'package:akshaya/features/sync/data/sync_store.dart';
import 'package:akshaya/features/sync/domain/change_digest.dart';
import 'package:akshaya/features/sync/domain/sync_documents.dart';
import 'package:akshaya/features/sync/domain/sync_models.dart';
import 'package:akshaya/features/sync/domain/sync_schema.dart';
import 'package:drift/drift.dart' show QueryRow, Variable, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_sync_remote.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late SyncStore store;
  late FakeSyncRemote remote;
  late SyncEngine engine;
  late DriftPantryRepository pantry;
  final List<List<RemoteChange>> changes = <List<RemoteChange>>[];
  bool denied = false;

  setUp(() {
    changes.clear();
    denied = false;
    db = AppDatabase(NativeDatabase.memory());
    store = SyncStore(db);
    remote = FakeSyncRemote();
    pantry = DriftPantryRepository(db);
    engine = SyncEngine(
      store: store,
      remote: remote,
      onChanges: changes.add,
      onDenied: () async => denied = true,
    );
  });

  tearDown(() async {
    await engine.dispose();
    await db.close();
  });

  Future<int> count(String sql) async {
    final List<QueryRow> rows = await db.customSelect(sql).get();
    return (rows.first.data.values.first! as num).toInt();
  }

  /// Waits until the engine has stopped working: attach starts a sync of its
  /// own, so a second call made right away only queues another pass.
  Future<void> settle() async {
    int calm = 0;
    for (int i = 0; i < 300 && calm < 4; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final SyncPhase phase = engine.status.phase;
      final bool working = phase == SyncPhase.syncing || phase == SyncPhase.idle;
      calm = working ? 0 : calm + 1;
    }
  }

  Future<void> attachAndSync() async {
    await engine.attach(householdId: 'h1', userId: 'me', resetCursors: true);
    await settle();
  }

  test('pushes local rows and marks them synced', () async {
    await pantry.insertSampleData();
    expect(await count("SELECT COUNT(*) FROM items WHERE sync_status='pending'"),
        greaterThan(0));

    await attachAndSync();

    expect(remote.count('items'), 10);
    expect(await count("SELECT COUNT(*) FROM items WHERE sync_status='pending'"),
        0);
    expect(engine.status.phase, SyncPhase.synced);
    final Map<String, Object?> any = remote.docs['items']!.values.first;
    expect(any['householdId'], 'h1');
    expect(any['updatedBy'], 'me');
  });

  test('a later edit goes pending again and is pushed', () async {
    await pantry.insertSampleData();
    await attachAndSync();
    final String id = remote.docs['items']!.keys.first;

    await db.customStatement(
      "UPDATE items SET notes = 'edited', updated_at = updated_at + 1000 "
      'WHERE id = ?',
      <Object?>[id],
    );
    expect(await count("SELECT COUNT(*) FROM items WHERE sync_status='pending'"),
        1);

    await engine.syncNow();
    expect(remote.get('items', id)!['notes'], 'edited');
    expect(await count("SELECT COUNT(*) FROM items WHERE sync_status='pending'"),
        0);
  });

  test('pulls what another member added and reports it', () async {
    await pantry.insertSampleData();
    await attachAndSync();
    // The first sync only baselines; alerts start after it.
    changes.clear();

    final Map<String, Object?> doc = SyncDocuments.toRemote(
      SyncSchema.entries,
      <String, Object?>{
        'id': 'e-remote',
        'created_at': 5000,
        'updated_at': 5000,
        'is_deleted': 0,
        'list_id': 'list_default',
        'name': 'Salt',
        'quantity': 1.0,
        'unit': 'packet',
        'is_checked': 0,
        'added_reason': 'manual',
        'priority': 'normal',
        'recurrence': 'none',
      },
      householdId: 'h1',
      userId: 'priya',
    );
    remote.put(
      'entries',
      doc,
      at: DateTime.now().millisecondsSinceEpoch + 60000,
    );

    await engine.syncNow();

    expect(
      await count("SELECT COUNT(*) FROM shopping_entries WHERE id='e-remote'"),
      1,
    );
    expect(
      await count(
        "SELECT COUNT(*) FROM shopping_entries WHERE id='e-remote' "
        "AND sync_status='synced'",
      ),
      1,
    );
    expect(changes, hasLength(1));
    expect(changes.single.single.userId, 'priya');
    expect(changes.single.single.collection, 'entries');
  });

  test('history downloaded when first attaching does not alert', () async {
    final Map<String, Object?> doc = SyncDocuments.toRemote(
      SyncSchema.entries,
      <String, Object?>{
        'id': 'old',
        'created_at': 1,
        'updated_at': 1,
        'is_deleted': 0,
        'list_id': 'list_default',
        'name': 'Salt',
        'quantity': 1.0,
        'unit': 'packet',
        'is_checked': 0,
        'added_reason': 'manual',
        'priority': 'normal',
        'recurrence': 'none',
      },
      householdId: 'h1',
      userId: 'priya',
    );
    remote.put('entries', doc, at: 5);

    await attachAndSync();

    expect(await count("SELECT COUNT(*) FROM shopping_entries WHERE id='old'"),
        1);
    expect(changes, isEmpty);
  });

  test('offline keeps rows pending and reports offline', () async {
    await pantry.insertSampleData();
    remote.failure = const SyncException(SyncErrorKind.offline, 'No internet');

    await attachAndSync();

    expect(engine.status.phase, SyncPhase.offline);
    expect(await count("SELECT COUNT(*) FROM items WHERE sync_status='pending'"),
        greaterThan(0));
    expect(remote.count('items'), 0);

    // Back online: the next sync sends everything.
    remote.failure = null;
    await engine.syncNow();
    expect(remote.count('items'), 10);
    expect(engine.status.phase, SyncPhase.synced);
  });

  test('quota errors show the limit and lose nothing', () async {
    await pantry.insertSampleData();
    remote.failure = const SyncException(SyncErrorKind.quota, 'Limit reached');

    await attachAndSync();

    expect(engine.status.phase, SyncPhase.quotaReached);
    expect(await count("SELECT COUNT(*) FROM items WHERE sync_status='pending'"),
        greaterThan(0));
  });

  test('a refusal from the cloud calls onDenied', () async {
    remote.failure = const SyncException(SyncErrorKind.denied, 'Not allowed');
    await attachAndSync();
    expect(denied, isTrue);
  });

  test('purge runs at most once a day', () async {
    await attachAndSync();
    final int first = remote.purged.length;
    expect(first, SyncSchema.tables.length);
    await engine.syncNow();
    expect(remote.purged.length, first);
  });

  test('detach leaves local data alone', () async {
    await pantry.insertSampleData();
    await attachAndSync();
    await engine.detach();
    expect(engine.isAttached, isFalse);
    expect(await count('SELECT COUNT(*) FROM items'), 10);
  });

  group('store', () {
    test('clearLocalData empties the pantry but keeps categories', () async {
      await pantry.insertSampleData();
      final int categories = await count('SELECT COUNT(*) FROM categories');
      await store.clearLocalData();
      expect(await count('SELECT COUNT(*) FROM items'), 0);
      expect(await count('SELECT COUNT(*) FROM categories'), categories);
      expect(await store.hasLocalData(), isFalse);
    });

    test('a suppressed write does not mark the row pending', () async {
      await pantry.insertSampleData();
      await attachAndSync();
      final String id = remote.docs['items']!.keys.first;
      final Map<String, Object?> doc = Map<String, Object?>.of(
        remote.get('items', id)!,
      )
        ..['name'] = 'Renamed elsewhere'
        ..['updatedAt'] = 9999999999999
        ..['updatedBy'] = 'priya';
      remote.put('items', doc);

      await engine.syncNow();

      final List<QueryRow> rows = await db
          .customSelect('SELECT name, sync_status FROM items WHERE id = ?',
              variables: <Variable<Object>>[Variable.withString(id)])
          .get();
      expect(rows.single.data['name'], 'Renamed elsewhere');
      expect(rows.single.data['sync_status'], 'synced');
    });

    test('identity round-trips and signing out clears it', () async {
      await store.setIdentity(householdId: 'h1', userId: 'me');
      expect((await store.identity()).isActive, isTrue);
      await store.setIdentity();
      expect((await store.identity()).isActive, isFalse);
    });

    test('members are cached by id', () async {
      await store.replaceMembers(const <Member>[
        Member(userId: 'a', displayName: 'Asha', role: MemberRole.owner),
        Member(userId: 'b', displayName: 'Ravi', role: MemberRole.member),
      ]);
      expect(await store.memberNames(), <String, String>{
        'a': 'Asha',
        'b': 'Ravi',
      });
    });
  });

  test('upgrades a version 4 database to 5', () async {
    final Directory dir = await Directory.systemTemp.createTemp('akshaya_db5');
    addTearDown(() => dir.delete(recursive: true));
    final File file = File('${dir.path}/upgrade.db');

    final AppDatabase fresh = AppDatabase(NativeDatabase(file));
    await fresh.customSelect('SELECT 1').get();
    for (final String t in <String>[
      'sync_state',
      'sync_cursors',
      'sync_batch_bases',
      'household_members',
    ]) {
      await fresh.customStatement('DROP TABLE $t');
    }
    await fresh.customStatement('PRAGMA user_version = 4');
    await fresh.close();

    final AppDatabase upgraded = AppDatabase(NativeDatabase(file));
    addTearDown(upgraded.close);
    final SyncStore upgradedStore = SyncStore(upgraded);
    expect((await upgradedStore.identity()).isActive, isFalse);
    await upgradedStore.advanceCursor('items', 5);
    expect(await upgradedStore.cursor('items'), 5);
    await upgradedStore.replaceMembers(const <Member>[
      Member(userId: 'a', displayName: 'Asha', role: MemberRole.owner),
    ]);
    expect(await upgradedStore.memberNames(), <String, String>{'a': 'Asha'});
  });
}
