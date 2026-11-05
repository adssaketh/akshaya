import 'recipe_models.dart';

/// Everything the recipe features need from storage. Like the pantry, the
/// local database is the source of truth and cloud sync works behind this
/// interface.
abstract interface class RecipeRepository {
  /// The recipes the person kept, newest first. Emits again on every change.
  Stream<List<SavedRecipe>> watchSaved();

  /// Keeps [recipe]. When the same recipe (same title and ingredients) is
  /// already kept, that one is returned and nothing is added.
  Future<SavedRecipe> save(Recipe recipe);

  /// Removes a kept recipe (a soft delete, so it can be undone and synced).
  Future<void> unsave(String savedId);

  Future<void> undoUnsave(String savedId);

  /// The last ideas the AI gave, or null. Emits again when they change.
  Stream<RecipeCacheEntry?> watchCache();

  Future<RecipeCacheEntry?> readCache();

  Future<void> writeCache(RecipeCacheEntry entry);
}
