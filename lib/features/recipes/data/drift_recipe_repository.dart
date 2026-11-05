import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../pantry/data/database/app_database.dart';
import '../domain/recipe_models.dart';
import '../domain/recipe_repository.dart';

/// [RecipeRepository] backed by the local Drift database.
///
/// Like the other repositories, every write marks the row `pending` for sync
/// (a database trigger does this for edits) and deletes are soft.
class DriftRecipeRepository implements RecipeRepository {
  DriftRecipeRepository(
    this._db, {
    DateTime Function()? clock,
    String Function()? idGenerator,
    String? currentUserId,
  })  : _clock = clock ?? DateTime.now,
        _newId = idGenerator ?? _uuidV4,
        _userId = currentUserId;

  final AppDatabase _db;
  final DateTime Function() _clock;
  final String Function() _newId;
  final String? _userId;

  static const String _cacheId = 'last';

  static String _uuidV4() => const Uuid().v4();

  SavedRecipe? _saved(SavedRecipeRow row) {
    final List<RecipeIngredient> ingredients =
        Recipe.decodeIngredients(row.ingredientsJson);
    final List<String> steps = Recipe.decodeSteps(row.stepsJson);
    final RecipeDiet? diet = RecipeDiet.fromKey(row.diet);
    if (ingredients.isEmpty || steps.isEmpty || diet == null) {
      // Damaged or unknown data is skipped, never shown half-broken.
      return null;
    }
    return SavedRecipe(
      id: row.id,
      savedAt: row.savedAt,
      recipe: Recipe(
        title: row.title,
        timeMinutes: row.timeMinutes,
        servings: row.servings,
        diet: diet,
        cuisine: row.cuisine,
        ingredients: ingredients,
        steps: steps,
      ),
    );
  }

  @override
  Stream<List<SavedRecipe>> watchSaved() {
    final SimpleSelectStatement<$SavedRecipesTable, SavedRecipeRow> query =
        _db.select(_db.savedRecipes)
          ..where((t) => t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm.desc(t.savedAt)]);
    return query.watch().map((List<SavedRecipeRow> rows) {
      final List<SavedRecipe> out = <SavedRecipe>[];
      for (final SavedRecipeRow row in rows) {
        final SavedRecipe? saved = _saved(row);
        if (saved != null) {
          out.add(saved);
        }
      }
      return out;
    });
  }

  @override
  Future<SavedRecipe> save(Recipe recipe) {
    return _db.transaction<SavedRecipe>(() async {
      final List<SavedRecipeRow> rows = await (_db.select(_db.savedRecipes)
            ..where((t) => t.isDeleted.equals(false)))
          .get();
      final String key = recipe.contentKey;
      for (final SavedRecipeRow row in rows) {
        final SavedRecipe? existing = _saved(row);
        if (existing != null && existing.recipe.contentKey == key) {
          return existing;
        }
      }
      final String id = _newId();
      final DateTime now = _clock();
      await _db.into(_db.savedRecipes).insert(
            SavedRecipesCompanion.insert(
              id: id,
              createdAt: now,
              updatedAt: now,
              updatedBy: Value<String?>(_userId),
              title: recipe.title,
              cuisine: Value<String?>(recipe.cuisine),
              timeMinutes: recipe.timeMinutes,
              servings: recipe.servings,
              diet: recipe.diet.key,
              ingredientsJson: Recipe.encodeIngredients(recipe.ingredients),
              stepsJson: Recipe.encodeSteps(recipe.steps),
              savedAt: now,
            ),
          );
      return SavedRecipe(id: id, recipe: recipe, savedAt: now);
    });
  }

  @override
  Future<void> unsave(String savedId) => _setDeleted(savedId, deleted: true);

  @override
  Future<void> undoUnsave(String savedId) =>
      _setDeleted(savedId, deleted: false);

  Future<void> _setDeleted(String id, {required bool deleted}) async {
    await (_db.update(_db.savedRecipes)..where((t) => t.id.equals(id))).write(
      SavedRecipesCompanion(
        isDeleted: Value<bool>(deleted),
        updatedAt: Value<DateTime>(_clock()),
        updatedBy: Value<String?>(_userId),
      ),
    );
  }

  RecipeCacheEntry? _cacheEntry(RecipeCacheRow? row) {
    if (row == null) {
      return null;
    }
    final List<Recipe> recipes = RecipeCacheEntry.decodeRecipes(row.recipesJson);
    if (recipes.isEmpty) {
      return null;
    }
    return RecipeCacheEntry(
      fingerprint: row.fingerprint,
      recipes: recipes,
      generatedAt: row.generatedAt,
    );
  }

  @override
  Stream<RecipeCacheEntry?> watchCache() {
    final SimpleSelectStatement<$RecipeCacheTable, RecipeCacheRow> query =
        _db.select(_db.recipeCache)..where((t) => t.id.equals(_cacheId));
    return query.watchSingleOrNull().map(_cacheEntry);
  }

  @override
  Future<RecipeCacheEntry?> readCache() async {
    final RecipeCacheRow? row = await (_db.select(_db.recipeCache)
          ..where((t) => t.id.equals(_cacheId)))
        .getSingleOrNull();
    return _cacheEntry(row);
  }

  @override
  Future<void> writeCache(RecipeCacheEntry entry) async {
    await _db.into(_db.recipeCache).insertOnConflictUpdate(
          RecipeCacheCompanion.insert(
            id: _cacheId,
            fingerprint: entry.fingerprint,
            recipesJson: RecipeCacheEntry.encodeRecipes(entry.recipes),
            generatedAt: entry.generatedAt,
          ),
        );
  }
}
