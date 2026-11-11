import 'package:drift/drift.dart';

import '../../../pantry/data/database/converters.dart';
import '../../../pantry/data/database/tables.dart';

/// Food eaten from outside the home. Added in schema v12; synced with the
/// household (`households/{id}/takeaways`).
///
/// Gemini's estimate for one serving travels as JSON text inside the row, so
/// every device shows the same numbers without asking again.
@DataClassName('TakeawayRow')
@TableIndex(name: 'takeaway_day_idx', columns: {#eatenOn})
class TakeawayMeals extends Table with SyncColumns {
  /// What it was ("Masala dosa").
  TextColumn get name => text().withLength(min: 1, max: 80)();

  /// The enum name of a `MealSlot`.
  TextColumn get meal => text().withDefault(const Constant('snack'))();

  /// How many servings.
  RealColumn get portions => real().withDefault(const Constant(1))();

  /// The day it was eaten, stored as `yyyy-MM-dd` text.
  TextColumn get eatenOn => text().map(const DateOnlyConverter())();

  /// Total paid, in rupees.
  RealColumn get price => real().nullable()();

  /// JSON of a `FoodEstimate`; null until it has been worked out.
  TextColumn get estimateJson => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
