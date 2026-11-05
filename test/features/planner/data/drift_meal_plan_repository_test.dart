import 'package:akshaya/features/pantry/data/database/app_database.dart';
import 'package:akshaya/features/planner/data/drift_meal_plan_repository.dart';
import 'package:akshaya/features/planner/domain/meal_plan_models.dart';
import 'package:akshaya/features/planner/domain/meal_slot.dart';
import 'package:akshaya/features/recipes/domain/recipe_models.dart';
import 'package:drift/drift.dart' show QueryRow, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../recipes/domain/recipe_test_support.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late DriftMealPlanRepository repo;
  int counter = 0;
  final DateTime monday = DateTime(2026, 11, 2);

  setUp(() {
    counter = 0;
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftMealPlanRepository(
      db,
      clock: () => DateTime(2026, 11, 4, 10),
      idGenerator: () => 'm-${counter++}',
    );
  });

  tearDown(() => db.close());

  Recipe dal() => recipeOf('Dal', const <RecipeIngredient>[
        RecipeIngredient(name: 'Toor Dal', quantity: 1),
      ]);

  test('a recipe meal keeps its recipe and prep', () async {
    await repo.put(
      MealPlanDraft.fromRecipe(
        date: monday,
        slot: MealSlot.dinner,
        recipe: dal(),
        prep: const <PrepReminder>[PrepReminder(text: 'Soak dal')],
      ),
    );
    final MealPlanEntry back =
        (await repo.watchBetween(monday, monday).first).single;
    expect(back.title, 'Dal');
    expect(back.recipe?.ingredients.single.name, 'Toor Dal');
    expect(back.prep.single.text, 'Soak dal');
    expect(back.isCooked, isFalse);
  });

  test('one meal per slot: putting again replaces it', () async {
    final MealPlanEntry first = await repo.put(
      MealPlanDraft.text(date: monday, slot: MealSlot.lunch, text: 'Outside'),
    );
    final MealPlanEntry second = await repo.put(
      MealPlanDraft.text(date: monday, slot: MealSlot.lunch, text: 'Pesarattu'),
    );
    expect(second.id, first.id);
    final List<MealPlanEntry> all = await repo.watchFrom(monday).first;
    expect(all.single.title, 'Pesarattu');
  });

  test('watchBetween only returns the days asked for, in order', () async {
    await repo.put(MealPlanDraft.text(
        date: DateTime(2026, 11, 3), slot: MealSlot.dinner, text: 'B'));
    await repo.put(MealPlanDraft.text(
        date: DateTime(2026, 11, 3), slot: MealSlot.breakfast, text: 'A'));
    await repo.put(MealPlanDraft.text(
        date: DateTime(2026, 11, 20), slot: MealSlot.lunch, text: 'Far'));
    final List<MealPlanEntry> week =
        await repo.watchBetween(monday, DateTime(2026, 11, 8)).first;
    expect(week.map((MealPlanEntry e) => e.title), <String>['A', 'B']);
  });

  test('update marks cooked; delete and undo are soft', () async {
    final MealPlanEntry e = await repo.put(
      MealPlanDraft.text(date: monday, slot: MealSlot.lunch, text: 'Upma'),
    );
    await repo.update(e.copyWith(isCooked: true));
    expect((await repo.readFrom(monday)).single.isCooked, isTrue);
    await repo.delete(e.id);
    expect(await repo.readFrom(monday), isEmpty);
    await repo.undoDelete(e.id);
    expect((await repo.readFrom(monday)).single.title, 'Upma');
    await repo.deleteMany(<String>[e.id]);
    expect(await repo.readFrom(monday), isEmpty);
    await repo.undoDeleteMany(<String>[e.id]);
    expect(await repo.readFrom(monday), hasLength(1));
  });

  test('a write marks the row pending for sync', () async {
    final MealPlanEntry e = await repo.put(
      MealPlanDraft.text(date: monday, slot: MealSlot.lunch, text: 'Upma'),
    );
    await db.customStatement(
      "UPDATE meal_plan_entries SET sync_status = 'synced'",
    );
    await repo.update(e.copyWith(isCooked: true));
    final List<QueryRow> rows = await db
        .customSelect('SELECT sync_status FROM meal_plan_entries')
        .get();
    expect(rows.single.read<String>('sync_status'), 'pending');
  });
}
