import 'package:drift/drift.dart';

import '../../../pantry/data/database/converters.dart';
import '../../../pantry/data/database/tables.dart';

/// Recipes the person kept. Added in schema v6; synced with the household
/// (`households/{id}/recipes`).
///
/// The ingredients and steps are stored as JSON text, because they are always
/// read and written together with the recipe. [diet] is `veg`, `egg` or
/// `non_veg` (the spec's `isVeg` is `diet == 'veg'`; eggetarian needs the
/// third value).
@DataClassName('SavedRecipeRow')
class SavedRecipes extends Table with SyncColumns {
  TextColumn get title => text().withLength(min: 1, max: 160)();

  TextColumn get cuisine => text().nullable()();

  IntColumn get timeMinutes => integer()();

  IntColumn get servings => integer()();

  TextColumn get diet => text()();

  /// JSON list of `{name, quantity?, unit?, itemId?}`.
  TextColumn get ingredientsJson => text()();

  /// JSON list of strings.
  TextColumn get stepsJson => text()();

  /// Where the recipe came from (only `ai` today).
  TextColumn get source => text().withDefault(const Constant('ai'))();

  IntColumn get savedAt => integer().map(const EpochMillisConverter())();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// The last set of recipe ideas, so they can be read offline and an unchanged
/// pantry does not ask the AI again. One row (id `last`). Added in schema v6;
/// local only, never synced.
@DataClassName('RecipeCacheRow')
class RecipeCache extends Table {
  TextColumn get id => text()();

  /// Identifies the pantry and preferences the ideas were made for.
  TextColumn get fingerprint => text()();

  /// JSON list of recipes.
  TextColumn get recipesJson => text()();

  IntColumn get generatedAt => integer().map(const EpochMillisConverter())();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
