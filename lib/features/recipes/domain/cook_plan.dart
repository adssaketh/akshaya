import '../../../core/util/quantity.dart';
import '../../pantry/domain/consumption_type.dart';
import '../../pantry/domain/entities.dart';
import '../../pantry/domain/default_categories.dart';
import '../../pantry/domain/failures.dart';
import '../../pantry/domain/item_kind.dart';
import '../../pantry/domain/pantry_repository.dart';
import '../../pantry/domain/shelf_life.dart';
import '../../pantry/domain/storage_location.dart';
import '../../pantry/domain/unit.dart';
import 'recipe_matcher.dart';
import 'recipe_models.dart';
import 'recipe_pantry.dart';

/// How sure the app is about the amount of one pantry item a recipe uses.
enum CookLineState {
  /// The recipe's amount is in stock.
  ready,

  /// Less is in stock than the recipe needs; the line proposes what is there.
  short,

  /// The recipe gives no amount, or one that cannot be converted (2 tomatoes
  /// against a pantry that counts in kg): the person fills it in.
  needsAmount,
}

/// One pantry item a recipe would use, for the "I cooked this" confirmation.
final class CookLine {
  const CookLine({
    required this.ingredient,
    required this.line,
    required this.unit,
    required this.state,
    this.quantity,
  });

  final RecipeIngredient ingredient;

  /// The pantry item, with what can be cooked with.
  final PantryLine line;

  /// The amount to take from the pantry, in [unit]. Null when it needs the
  /// person's input.
  final double? quantity;
  final Unit unit;
  final CookLineState state;

  /// Whether the line starts ticked.
  bool get startsChecked => state != CookLineState.needsAmount;
}

/// What cooking a recipe would take from the pantry.
final class CookPlan {
  const CookPlan({required this.lines, required this.notInPantry});

  /// Ingredients matched to pantry items that have stock.
  final List<CookLine> lines;

  /// Ingredients that have nothing to take from (missing, out of stock or
  /// expired). Water and salt are left out.
  final List<RecipeIngredient> notInPantry;
}

/// Turns a recipe's matches into a plan. Pure Dart.
abstract final class CookPlanner {
  static CookPlan plan(List<IngredientMatch> matches) {
    final List<CookLine> lines = <CookLine>[];
    final List<RecipeIngredient> others = <RecipeIngredient>[];
    for (final IngredientMatch m in matches) {
      if (m.availability == IngredientAvailability.assumed) {
        continue;
      }
      final PantryLine? line = m.line;
      if (line == null || !line.hasStock) {
        others.add(m.ingredient);
        continue;
      }
      final double? quantity = m.ingredient.quantity;
      final Unit? unit = m.ingredient.unit;
      if (quantity != null && unit != null && unit.isCompatibleWith(line.unit)) {
        final double inStock = roundQty(line.unit.convertTo(line.usable, unit));
        final bool enough = quantity <= inStock + kQtyEpsilon;
        lines.add(
          CookLine(
            ingredient: m.ingredient,
            line: line,
            quantity: enough ? roundQty(quantity) : inStock,
            unit: unit,
            state: enough ? CookLineState.ready : CookLineState.short,
          ),
        );
      } else {
        lines.add(
          CookLine(
            ingredient: m.ingredient,
            line: line,
            unit: line.unit,
            state: CookLineState.needsAmount,
          ),
        );
      }
    }
    return CookPlan(lines: lines, notInPantry: others);
  }
}

/// One confirmed deduction.
final class CookRequest {
  const CookRequest({
    required this.itemId,
    required this.itemName,
    required this.quantity,
    required this.unit,
  });

  final String itemId;
  final String itemName;
  final double quantity;
  final Unit unit;
}

/// Food left over from cooking, to be stored as a Cooked pantry item.
final class LeftoverPlan {
  const LeftoverPlan({required this.portions, required this.location});

  /// Positive number of portions.
  final double portions;
  final StorageLocation location;
}

/// The Cooked item and batch made for leftovers, so they can be undone.
final class LeftoverOutcome {
  const LeftoverOutcome({
    required this.itemId,
    required this.batchId,
    required this.createdItem,
  });

  final String itemId;
  final String batchId;

  /// True when the item did not exist before and is removed again on undo.
  final bool createdItem;
}

/// What cooking changed, so it can be undone.
final class CookOutcome {
  const CookOutcome({
    required this.results,
    required this.failures,
    this.leftover,
  });

  /// The leftovers that were stored, if any.
  final LeftoverOutcome? leftover;

  /// One entry per item that was used.
  final List<UseResult> results;

  /// "Tomato: Only 300 g left." for each item that could not be used.
  final List<String> failures;

  int get usedCount => results.length;
}

/// Takes the confirmed amounts out of the pantry, logging them as "cooked in
/// recipe". One item that cannot be used (not enough left) never stops the
/// others.
abstract final class CookExecutor {
  ///
  /// With a [leftover] plan the leftovers are stored as a Cooked item once the
  /// ingredients are taken out, named after [recipeTitle] and dated [today].
  static Future<CookOutcome> run(
    PantryRepository pantry,
    List<CookRequest> requests, {
    LeftoverPlan? leftover,
    String recipeTitle = '',
    DateTime? today,
  }) async {
    final List<UseResult> results = <UseResult>[];
    final List<String> failures = <String>[];
    for (final CookRequest request in requests) {
      try {
        results.add(
          await pantry.useStock(
            itemId: request.itemId,
            quantity: request.quantity,
            unit: request.unit,
            type: ConsumptionType.cookedInRecipe,
          ),
        );
      } on PantryFailure catch (failure) {
        failures.add('${request.itemName}: ${failure.message}');
      } on Object {
        failures.add('${request.itemName}: Something went wrong.');
      }
    }
    LeftoverOutcome? stored;
    if (leftover != null && today != null) {
      try {
        stored = await saveLeftover(
          pantry,
          title: recipeTitle,
          plan: leftover,
          today: today,
        );
      } on PantryFailure catch (failure) {
        failures.add('Leftovers: ${failure.message}');
      } on Object {
        failures.add('Leftovers: Something went wrong.');
      }
    }
    return CookOutcome(results: results, failures: failures, leftover: stored);
  }

  /// Stores [plan] as a Cooked batch dated [today] with the shelf life of its
  /// location. Adds to the existing Cooked item of that name if there is one;
  /// a Stocked item that already has the recipe's name is left alone.
  static Future<LeftoverOutcome> saveLeftover(
    PantryRepository pantry, {
    required String title,
    required LeftoverPlan plan,
    required DateTime today,
  }) async {
    final String name = title.trim().isEmpty ? 'Leftovers' : title.trim();
    Item? item = await pantry.findItemByName(name);
    bool created = false;
    if (item == null || item.kind != ItemKind.cooked) {
      final String alt = '$name (leftover)';
      final Item? other = item == null ? null : await pantry.findItemByName(alt);
      if (other != null && other.kind == ItemKind.cooked) {
        item = other;
      } else {
        item = await pantry.addItem(
          ItemDraft(
            name: item == null ? name : alt,
            categoryId: kDefaultCategoryId,
            defaultUnit: Unit.portion,
            kind: ItemKind.cooked,
            defaultStorageLocation: plan.location,
          ),
        );
        created = true;
      }
    }
    final StockBatch batch = await pantry.addBatch(
      BatchDraft(
        itemId: item.id,
        quantityBought: plan.portions,
        unit: Unit.portion,
        purchaseDate: today,
        storageLocation: plan.location,
        expiryDate: ShelfLife.expiryFor(
          kind: ItemKind.cooked,
          location: plan.location,
          madeOn: today,
          own: item.shelfLifeDays,
          usualLocation: item.defaultStorageLocation,
        ),
      ),
    );
    return LeftoverOutcome(
      itemId: item.id,
      batchId: batch.id,
      createdItem: created,
    );
  }

  /// Puts back everything [outcome] took, last first.
  static Future<void> undo(
    PantryRepository pantry,
    CookOutcome outcome,
  ) async {
    final LeftoverOutcome? leftover = outcome.leftover;
    if (leftover != null) {
      await pantry.deleteBatch(leftover.batchId);
      if (leftover.createdItem) {
        await pantry.deleteItem(leftover.itemId);
      }
    }
    for (final UseResult result in outcome.results.reversed) {
      await pantry.undoUse(result);
    }
  }
}
