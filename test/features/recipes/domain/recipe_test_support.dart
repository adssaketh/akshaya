import 'package:akshaya/features/pantry/domain/consumption_type.dart';
import 'package:akshaya/features/pantry/domain/entities.dart';
import 'package:akshaya/features/pantry/domain/failures.dart';
import 'package:akshaya/features/pantry/domain/pantry_repository.dart';
import 'package:akshaya/features/pantry/domain/stock_logic.dart';
import 'package:akshaya/features/pantry/domain/unit.dart';
import 'package:akshaya/features/recipes/domain/ai_recipe_service.dart';
import 'package:akshaya/features/recipes/domain/recipe_models.dart';
import 'package:akshaya/features/recipes/domain/recipe_pantry.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../pantry/domain/test_data.dart';

/// The pantry lines for [records] as of [kToday].
List<PantryLine> linesFor(List<ItemWithBatches> records) {
  return RecipePantry.build(
    <ItemStock>[
      for (final ItemWithBatches r in records)
        StockLogic.summarize(r, today: kToday, warningDays: 3),
    ],
    today: kToday,
  );
}

ItemWithBatches stocked(
  String id,
  String name, {
  double qty = 1,
  Unit unit = Unit.kg,
  DateTime? expiry,
  List<String> aliases = const <String>[],
}) {
  return ItemWithBatches(
    item: makeItem(id: id, name: name, unit: unit, aliases: aliases),
    batches: <StockBatch>[
      makeBatch(
        id: 'b-$id',
        itemId: id,
        bought: qty,
        unit: unit,
        expiry: expiry,
      ),
    ],
  );
}

Recipe recipeOf(
  String title,
  List<RecipeIngredient> ingredients, {
  RecipeDiet diet = RecipeDiet.veg,
}) {
  return Recipe(
    title: title,
    timeMinutes: 30,
    servings: 2,
    diet: diet,
    ingredients: ingredients,
    steps: const <String>['Cook it.'],
  );
}

const String kGoodRecipesJson = '''
{"recipes":[
 {"title":"Tomato Rice","time_minutes":25,"servings":2,"diet":"veg",
  "cuisine":"South Indian",
  "ingredients":[
   {"name":"Rice","quantity":0.5,"unit":"kg","status":"in_pantry"},
   {"name":"Tomato","quantity":4,"unit":"pcs","status":"missing"}],
  "steps":["Cook the rice.","Add tomatoes."],
  "uses_expiring":["Tomato"]},
 {"title":"Egg Curry","time_minutes":30,"servings":2,"diet":"egg",
  "ingredients":[{"name":"Egg","quantity":4}],
  "steps":["Boil eggs."]}
]}''';

class FakeRecipeBackend implements RecipeBackend {
  FakeRecipeBackend(this.script);

  final List<Object> script;
  int calls = 0;
  String? lastPrompt;

  @override
  Future<String> generateRecipesJson(String prompt) async {
    lastPrompt = prompt;
    final Object step = script[calls < script.length ? calls : script.length - 1];
    calls++;
    if (step is String) {
      return step;
    }
    throw step;
  }
}

class RecordingPantry extends Fake implements PantryRepository {
  final List<({String itemId, double quantity, Unit unit, ConsumptionType type})>
      used = <({String itemId, double quantity, Unit unit, ConsumptionType type})>[];
  final List<UseResult> undone = <UseResult>[];
  final Set<String> failing = <String>{};

  @override
  Future<UseResult> useStock({
    required String itemId,
    required double quantity,
    required Unit unit,
    ConsumptionType type = ConsumptionType.used,
  }) async {
    if (failing.contains(itemId)) {
      throw InsufficientStockFailure(available: 0.1, availableLabel: '100 g');
    }
    used.add((itemId: itemId, quantity: quantity, unit: unit, type: type));
    return UseResult(
      itemId: itemId,
      quantity: quantity,
      unit: unit,
      type: type,
      applied: const <AppliedDeduction>[],
    );
  }

  @override
  Future<void> undoUse(UseResult result) async => undone.add(result);
}

