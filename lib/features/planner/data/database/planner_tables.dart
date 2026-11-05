import 'package:drift/drift.dart';

import '../../../pantry/data/database/converters.dart';
import '../../../pantry/data/database/tables.dart';

/// One meal on the weekly plan: a slot on a day. Added in schema v9; synced
/// with the household (`households/{id}/mealPlan`).
///
/// The recipe (when the meal is a recipe) is kept whole as JSON, so the plan
/// does not depend on the saved recipes or the last ideas still existing.
@DataClassName('MealPlanRow')
@TableIndex(name: 'meal_plan_date_idx', columns: {#planDate})
class MealPlanEntries extends Table with SyncColumns {
  /// The calendar day, stored as `yyyy-MM-dd` text.
  TextColumn get planDate => text().map(const DateOnlyConverter())();

  /// `breakfast`, `lunch`, `dinner` or `snack`.
  TextColumn get slot => text()();

  /// What to show: the recipe's title, the leftover's name or free text.
  TextColumn get title => text().withLength(min: 1, max: 160)();

  /// JSON of the recipe, for a recipe meal.
  TextColumn get recipeJson => text().nullable()();

  /// The cooked pantry item, for a leftover meal.
  TextColumn get leftoverItemId => text().nullable()();

  BoolColumn get isCooked => boolean().withDefault(const Constant(false))();

  /// JSON list of prep reminders `{text, daysBefore, minutes}`; null for none.
  TextColumn get prepJson => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
