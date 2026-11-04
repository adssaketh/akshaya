import 'package:drift/drift.dart';

import '../../pantry/data/database/app_database.dart';
import '../domain/settings_repository.dart';

/// [SettingsRepository] backed by the local Drift database.
class DriftSettingsRepository implements SettingsRepository {
  DriftSettingsRepository(this._db, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _clock;

  @override
  Stream<Map<String, String>> watchAll() {
    return _db.select(_db.appSettings).watch().map(_toMap);
  }

  @override
  Future<Map<String, String>> readAll() async {
    return _toMap(await _db.select(_db.appSettings).get());
  }

  @override
  Future<void> writeAll(Map<String, String> values) async {
    if (values.isEmpty) {
      return;
    }
    final DateTime now = _clock();
    await _db.transaction(() async {
      for (final MapEntry<String, String> entry in values.entries) {
        await _db.into(_db.appSettings).insertOnConflictUpdate(
              AppSettingsCompanion.insert(
                name: entry.key,
                value: entry.value,
                updatedAt: now,
              ),
            );
      }
    });
  }

  @override
  Future<void> remove(String key) async {
    await (_db.delete(_db.appSettings)..where((t) => t.name.equals(key))).go();
  }

  static Map<String, String> _toMap(List<AppSettingRow> rows) {
    return <String, String>{
      for (final AppSettingRow row in rows) row.name: row.value,
    };
  }
}
