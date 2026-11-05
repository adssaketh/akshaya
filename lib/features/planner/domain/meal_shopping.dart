import '../../../core/util/date_only.dart';
import '../../../core/util/quantity.dart';
import '../../pantry/domain/unit.dart';
import '../../recipes/domain/recipe_matcher.dart';
import '../../recipes/domain/recipe_models.dart';
import '../../recipes/domain/recipe_shopping.dart';
import '../../shopping/domain/shopping_entities.dart';
import 'meal_plan_models.dart';

/// What "Generate shopping list" worked out.
final class MealShoppingResult {
  const MealShoppingResult({
    required this.drafts,
    required this.mealsCounted,
    required this.mealsWithoutIngredients,
    required this.alreadyOnList,
  });

  /// What to add: only what the pantry cannot cover, each marked "for a
  /// recipe".
  final List<ShoppingEntryDraft> drafts;

  /// Meals with a recipe that were totalled.
  final int mealsCounted;

  /// Upcoming meals that have no ingredient list (free text, leftovers).
  final int mealsWithoutIngredients;

  /// Missing items left out because they are already on the list.
  final int alreadyOnList;
}

/// Works out the shopping list for a week of planned meals. Pure Dart.
abstract final class MealShoppingPlanner {
  /// Totals the ingredients of every upcoming, uncooked recipe meal in
  /// [entries] (from [from] on), subtracts what the pantry holds (through
  /// [matcher]) and returns drafts for what is missing or short. Items that
  /// are already unchecked on the target list ([existing]) are left out, so
  /// pressing the button twice does not double the list.
  static MealShoppingResult plan({
    required List<MealPlanEntry> entries,
    required RecipeMatcher matcher,
    required String listId,
    required List<ShoppingEntry> existing,
    required DateTime from,
  }) {
    final DateTime start = dateOnly(from);
    final List<Recipe> recipes = <Recipe>[];
    int withoutIngredients = 0;
    for (final MealPlanEntry entry in entries) {
      if (entry.isCooked || entry.date.isBefore(start)) {
        continue;
      }
      final Recipe? recipe = entry.recipe;
      if (recipe == null) {
        withoutIngredients++;
      } else {
        recipes.add(recipe);
      }
    }

    final List<RecipeIngredient> total = totalIngredients(recipes);
    if (total.isEmpty) {
      return MealShoppingResult(
        drafts: const <ShoppingEntryDraft>[],
        mealsCounted: recipes.length,
        mealsWithoutIngredients: withoutIngredients,
        alreadyOnList: 0,
      );
    }

    final Recipe combined = Recipe(
      title: 'the meal plan',
      timeMinutes: 1,
      servings: 1,
      diet: RecipeDiet.veg,
      ingredients: total,
      steps: const <String>['Cook the planned meals.'],
    );
    final List<IngredientMatch> matches = matcher.matchAll(combined);
    final List<ShoppingEntryDraft> wanted = RecipeShoppingPlanner.drafts(
      recipe: combined,
      matches: matches,
      listId: listId,
    );

    final Set<String> itemIds = <String>{};
    final Set<String> names = <String>{};
    for (final ShoppingEntry e in existing) {
      if (e.listId != listId || e.isChecked) {
        continue;
      }
      if (e.itemId != null) {
        itemIds.add(e.itemId!);
      }
      names.add(_key(e.name));
    }
    final List<ShoppingEntryDraft> fresh = <ShoppingEntryDraft>[];
    int skipped = 0;
    for (final ShoppingEntryDraft draft in wanted) {
      final bool onList = (draft.itemId != null && itemIds.contains(draft.itemId)) ||
          names.contains(_key(draft.name));
      if (onList) {
        skipped++;
      } else {
        fresh.add(draft);
      }
    }
    return MealShoppingResult(
      drafts: fresh,
      mealsCounted: recipes.length,
      mealsWithoutIngredients: withoutIngredients,
      alreadyOnList: skipped,
    );
  }

  /// One line per ingredient across [recipes]: amounts of the same ingredient
  /// are added (g and kg, ml and L convert; unit-less counts add), amounts
  /// that cannot be added stay separate lines, and an ingredient with no
  /// amount anywhere stays without one.
  static List<RecipeIngredient> totalIngredients(List<Recipe> recipes) {
    final List<_Total> totals = <_Total>[];
    for (final Recipe recipe in recipes) {
      for (final RecipeIngredient ingredient in recipe.ingredients) {
        final String key = _key(ingredient.name);
        _Total? target;
        for (final _Total t in totals) {
          if (t.key == key && t.accepts(ingredient)) {
            target = t;
            break;
          }
        }
        if (target == null) {
          totals.add(_Total(key, ingredient));
        } else {
          target.add(ingredient);
        }
      }
    }
    return <RecipeIngredient>[for (final _Total t in totals) t.toIngredient()];
  }

  /// Lower case, no brackets, single spaces: "Onion (red)" and "onion" are
  /// the same ingredient.
  static String _key(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'\([^)]*\)'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}

/// A running total of one ingredient.
final class _Total {
  _Total(this.key, RecipeIngredient first)
      : name = first.name,
        itemId = first.itemId,
        unit = first.unit,
        quantity = first.quantity;

  final String key;
  final String name;
  final String? itemId;
  Unit? unit;
  double? quantity;

  /// Whether [other]'s amount can be added to this total.
  bool accepts(RecipeIngredient other) {
    if (other.quantity == null || quantity == null) {
      // Nothing to add (or nothing yet): it can always join.
      return true;
    }
    final Unit? mine = unit;
    final Unit? theirs = other.unit;
    if (mine == null || theirs == null) {
      return mine == null && theirs == null;
    }
    return theirs.isCompatibleWith(mine);
  }

  void add(RecipeIngredient other) {
    final double? amount = other.quantity;
    if (amount == null) {
      return;
    }
    if (quantity == null) {
      quantity = amount;
      unit = other.unit;
      return;
    }
    final Unit? mine = unit;
    final Unit? theirs = other.unit;
    final double converted =
        (mine != null && theirs != null) ? theirs.convertTo(amount, mine) : amount;
    quantity = roundQty(quantity! + converted);
  }

  RecipeIngredient toIngredient() {
    return RecipeIngredient(
      name: name,
      quantity: quantity,
      unit: quantity == null ? null : unit,
      itemId: itemId,
    );
  }
}
