import 'dart:io';

import 'package:akshaya/features/pantry/data/database/app_database.dart';
import 'package:akshaya/features/pantry/domain/unit.dart';
import 'package:akshaya/features/recipes/data/drift_recipe_repository.dart';
import 'package:akshaya/features/recipes/domain/recipe_models.dart';
import 'package:drift/drift.dart' show QueryRow, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../domain/recipe_test_support.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late DriftRecipeRepository repo;
  int counter = 0;

  final Recipe rice = recipeOf('Tomato Rice', const <RecipeIngredient>[
    RecipeIngredient(name: 'Rice', quantity: 0.5, unit: Unit.kg, itemId: 'i1'),
    RecipeIngredient(name: 'Tomato', quantity: 4),
  ]);

  setUp(() {
    counter = 0;
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftRecipeRepository(
      db,
      clock: () => DateTime(2026, 11, 4, 10),
      idGenerator: () => 'r-${counter++}',
    );
  });

  tearDown(() => db.close());

  test('saving keeps the whole recipe', () async {
    final SavedRecipe saved = await repo.save(rice);
    expect(saved.id, 'r-0');
    final List<SavedRecipe> list = await repo.watchSaved().first;
    expect(list.length, 1);
    final Recipe back = list.single.recipe;
    expect(back.title, 'Tomato Rice');
    expect(back.ingredients.first.unit, Unit.kg);
    expect(back.ingredients.first.itemId, 'i1');
    expect(back.ingredients.last.quantity, 4);
    expect(back.steps, <String>['Cook it.']);
    expect(back.diet, RecipeDiet.veg);
    expect(list.single.savedAt, DateTime(2026, 11, 4, 10));
  });

  test('saving the same recipe twice keeps one copy', () async {
    final SavedRecipe first = await repo.save(rice);
    final SavedRecipe second = await repo.save(
      recipeOf('tomato  rice', const <RecipeIngredient>[
        RecipeIngredient(name: 'tomato'),
        RecipeIngredient(name: 'RICE'),
      ]),
    );
    expect(second.id, first.id);
    expect((await repo.watchSaved().first).length, 1);
  });

  test('unsave hides the recipe, undo brings it back, and it can be saved again',
      () async {
    final SavedRecipe saved = await repo.save(rice);
    await repo.unsave(saved.id);
    expect(await repo.watchSaved().first, isEmpty);

    await repo.undoUnsave(saved.id);
    expect((await repo.watchSaved().first).single.id, saved.id);

    await repo.unsave(saved.id);
    final SavedRecipe again = await repo.save(rice);
    expect(again.id, isNot(saved.id));
    expect((await repo.watchSaved().first).length, 1);
  });

  test('edits are marked for sync', () async {
    final SavedRecipe saved = await repo.save(rice);
    await db.customStatement(
      "UPDATE saved_recipes SET sync_status = 'synced' WHERE id = '${saved.id}'",
    );
    await repo.unsave(saved.id);
    final List<QueryRow> rows = await db
        .customSelect(
          "SELECT sync_status FROM saved_recipes WHERE id = '${saved.id}'",
        )
        .get();
    expect(rows.single.read<String>('sync_status'), 'pending');
  });

  test('the cache is read, replaced and watched', () async {
    expect(await repo.readCache(), isNull);
    await repo.writeCache(
      RecipeCacheEntry(
        fingerprint: 'abc',
        recipes: <Recipe>[rice],
        generatedAt: DateTime(2026, 11, 4, 9),
      ),
    );
    final RecipeCacheEntry? first = await repo.readCache();
    expect(first!.fingerprint, 'abc');
    expect(first.recipes.single.title, 'Tomato Rice');

    await repo.writeCache(
      RecipeCacheEntry(
        fingerprint: 'def',
        recipes: <Recipe>[rice, rice],
        generatedAt: DateTime(2026, 11, 5, 9),
      ),
    );
    final RecipeCacheEntry? second = await repo.watchCache().first;
    expect(second!.fingerprint, 'def');
    expect(second.recipes.length, 2);
  });

  test('upgrades a version 5 database to 6', () async {
    final Directory dir = await Directory.systemTemp.createTemp('akshaya_db6');
    addTearDown(() => dir.delete(recursive: true));
    final File file = File('${dir.path}/upgrade.db');

    final AppDatabase fresh = AppDatabase(NativeDatabase(file));
    await fresh.customSelect('SELECT 1').get();
    await fresh.customStatement('DROP TRIGGER IF EXISTS sync_mark_saved_recipes');
    await fresh.customStatement('DROP TABLE saved_recipes');
    await fresh.customStatement('DROP TABLE recipe_cache');
    await fresh.customStatement('PRAGMA user_version = 5');
    await fresh.close();

    final AppDatabase upgraded = AppDatabase(NativeDatabase(file));
    addTearDown(upgraded.close);
    final DriftRecipeRepository upgradedRepo = DriftRecipeRepository(upgraded);
    final SavedRecipe saved = await upgradedRepo.save(rice);
    expect((await upgradedRepo.watchSaved().first).single.id, saved.id);

    final List<QueryRow> triggers = await upgraded
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'trigger' "
          "AND name = 'sync_mark_saved_recipes'",
        )
        .get();
    expect(triggers.length, 1);
  });
}
