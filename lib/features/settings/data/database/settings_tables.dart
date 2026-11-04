import 'package:drift/drift.dart';

import '../../../pantry/data/database/converters.dart';

/// The person's settings as name/value text pairs. Local only: it never syncs,
/// because alert times and similar belong to one phone.
///
/// Keys are owned by the features that use them (for example `alerts.enabled`).
@DataClassName('AppSettingRow')
class AppSettings extends Table {
  TextColumn get name => text().withLength(min: 1, max: 80)();

  TextColumn get value => text()();

  IntColumn get updatedAt => integer().map(const EpochMillisConverter())();

  @override
  Set<Column<Object>> get primaryKey => {name};
}
