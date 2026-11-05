import 'package:drift/drift.dart';

import '../../../pantry/data/database/converters.dart';
import '../../../pantry/data/database/tables.dart';

/// A trip the household is away on. Added in schema v11; synced with the
/// household (`households/{id}/trips`).
///
/// The essentials to buy on the way back travel as JSON text inside the row.
@DataClassName('TripRow')
class Trips extends Table with SyncColumns {
  /// What the person called the trip; may be empty.
  TextColumn get name => text().withDefault(const Constant(''))();

  /// The leaving day, stored as `yyyy-MM-dd` text.
  TextColumn get startDate => text().map(const DateOnlyConverter())();

  /// The day everyone is back, stored as `yyyy-MM-dd` text.
  TextColumn get endDate => text().map(const DateOnlyConverter())();

  BoolColumn get pauseRecurring => boolean().withDefault(const Constant(true))();

  BoolColumn get pauseAlerts => boolean().withDefault(const Constant(true))();

  /// JSON list of `{name, quantity, unit}`; null means none.
  TextColumn get essentialsJson => text().nullable()();

  /// True once the essentials were put on the shopping list.
  BoolColumn get essentialsAdded =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
