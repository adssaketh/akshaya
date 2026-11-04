import 'dart:async';
import 'dart:io';

import 'package:akshaya/features/pantry/data/database/app_database.dart';
import 'package:akshaya/features/settings/data/drift_settings_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late DriftSettingsRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftSettingsRepository(db);
  });

  tearDown(() => db.close());

  test('starts empty', () async {
    expect(await repo.readAll(), isEmpty);
  });

  test('writes and reads back values', () async {
    await repo.writeAll(<String, String>{'a': '1', 'b': 'two'});
    expect(await repo.readAll(), <String, String>{'a': '1', 'b': 'two'});
  });

  test('writing an existing key replaces its value', () async {
    await repo.writeAll(<String, String>{'a': '1', 'b': '2'});
    await repo.writeAll(<String, String>{'a': '9'});
    expect(await repo.readAll(), <String, String>{'a': '9', 'b': '2'});
  });

  test('remove deletes one key and ignores a missing one', () async {
    await repo.writeAll(<String, String>{'a': '1', 'b': '2'});
    await repo.remove('a');
    await repo.remove('zzz');
    expect(await repo.readAll(), <String, String>{'b': '2'});
  });

  test('watchAll emits the current values and then every change', () async {
    final List<Map<String, String>> seen = <Map<String, String>>[];
    final StreamSubscription<Map<String, String>> subscription =
        repo.watchAll().listen(seen.add);
    addTearDown(subscription.cancel);

    await pumpEventQueue();
    await repo.writeAll(<String, String>{'a': '1'});
    await pumpEventQueue();
    await repo.writeAll(<String, String>{'a': '2'});
    await pumpEventQueue();

    expect(seen.first, isEmpty);
    expect(seen.last, <String, String>{'a': '2'});
    expect(seen.length, greaterThanOrEqualTo(3));
  });

  test('upgrades a version 3 database and adds app_settings', () async {
    final Directory dir = await Directory.systemTemp.createTemp('akshaya_db');
    addTearDown(() => dir.delete(recursive: true));
    final File file = File('${dir.path}/upgrade.db');

    // Make a database that looks like Phase 3 left it.
    final AppDatabase fresh = AppDatabase(NativeDatabase(file));
    await fresh.customSelect('SELECT 1').get();
    await fresh.customStatement('DROP TABLE app_settings');
    await fresh.customStatement('PRAGMA user_version = 3');
    await fresh.close();

    final AppDatabase upgraded = AppDatabase(NativeDatabase(file));
    addTearDown(upgraded.close);
    final DriftSettingsRepository upgradedRepo =
        DriftSettingsRepository(upgraded);

    await upgradedRepo.writeAll(<String, String>{'alerts.enabled': 'false'});
    expect(await upgradedRepo.readAll(), <String, String>{
      'alerts.enabled': 'false',
    });
  });
}
