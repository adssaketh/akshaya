import 'package:drift/drift.dart';

/// Who the local database syncs as and to which household. One row (id 1).
/// Added in schema v5; local only.
///
/// The database triggers read `suppress` so that changes the sync engine
/// itself makes (applying what arrived from the cloud) are not mistaken for
/// edits that still have to be sent.
@DataClassName('SyncStateRow')
class SyncState extends Table {
  IntColumn get id => integer()();

  TextColumn get householdId => text().nullable()();

  TextColumn get userId => text().nullable()();

  IntColumn get suppress => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Per collection, the newest `syncedAt` (epoch milliseconds) this phone has
/// received, so the next query asks only for what changed after it. Special
/// keys start with an underscore (see `SyncStore`). Local only.
@DataClassName('SyncCursorRow')
class SyncCursors extends Table {
  TextColumn get collection => text()();

  IntColumn get lastMillis => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {collection};
}

/// The remaining quantity of a batch as the cloud last held it, so the part
/// that changed on this phone can be sent as a difference. Local only.
@DataClassName('SyncBatchBaseRow')
class SyncBatchBases extends Table {
  TextColumn get batchId => text()();

  RealColumn get baseRemaining => real()();

  @override
  Set<Column<Object>> get primaryKey => {batchId};
}

/// The household's members as last seen, for names in alerts and for showing
/// the household offline. Local only.
@DataClassName('HouseholdMemberRow')
class HouseholdMembers extends Table {
  TextColumn get userId => text()();

  TextColumn get displayName => text()();

  TextColumn get role => text()();

  @override
  Set<Column<Object>> get primaryKey => {userId};
}
