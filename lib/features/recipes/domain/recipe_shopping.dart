import '../../../core/util/quantity.dart';
import '../../pantry/domain/unit.dart';
import '../../shopping/domain/shopping_entities.dart';
import '../../shopping/domain/shopping_enums.dart';
import 'recipe_matcher.dart';
import 'recipe_models.dart';
import 'recipe_pantry.dart';

/// Works out what to put on the shopping list for a recipe. Pure Dart.
abstract final class RecipeShoppingPlanner {
  static const int maxNoteLength = 120;

  /// One entry per missing or short ingredient (water and salt are never
  /// added). An ingredient that matches a pantry item that is out of stock
  /// points at that item; one that is short asks for the shortfall; anything
  /// else becomes a free-text entry. Everything is marked "for a recipe".
  static List<ShoppingEntryDraft> drafts({
    required Recipe recipe,
    required List<IngredientMatch> matches,
    required String listId,
  }) {
    final String note = _note(recipe.title);
    final List<ShoppingEntryDraft> out = <ShoppingEntryDraft>[];
    for (final IngredientMatch m in matches) {
      switch (m.availability) {
        case IngredientAvailability.inPantry:
        case IngredientAvailability.assumed:
          continue;
        case IngredientAvailability.short:
          final PantryLine? line = m.line;
          final double? gap = m.shortfall;
          if (line == null || gap == null || isZeroQty(gap)) {
            continue;
          }
          out.add(
            ShoppingEntryDraft(
              listId: listId,
              itemId: line.itemId,
              name: line.name,
              quantity: gap,
              unit: line.unit,
              addedReason: AddedReason.recipe,
              notes: note,
            ),
          );
        case IngredientAvailability.missing:
          out.add(_missing(m, listId, note));
      }
    }
    return out;
  }

  static ShoppingEntryDraft _missing(
    IngredientMatch m,
    String listId,
    String note,
  ) {
    final RecipeIngredient ingredient = m.ingredient;
    final PantryLine? line = m.line;
    final double? quantity = ingredient.quantity;
    final Unit? unit = ingredient.unit;
    if (line != null) {
      // A pantry item that ran out: the entry must use a unit that converts
      // to the item's, or "Done shopping" could not add it back.
      if (quantity != null && unit != null && unit.isCompatibleWith(line.unit)) {
        return ShoppingEntryDraft(
          listId: listId,
          itemId: line.itemId,
          name: line.name,
          quantity: quantity,
          unit: unit,
          addedReason: AddedReason.recipe,
          notes: note,
        );
      }
      return ShoppingEntryDraft(
        listId: listId,
        itemId: line.itemId,
        name: line.name,
        quantity: 1,
        unit: line.unit,
        addedReason: AddedReason.recipe,
        notes: note,
      );
    }
    return ShoppingEntryDraft(
      listId: listId,
      name: ingredient.name,
      quantity: quantity ?? 1,
      unit: quantity == null ? Unit.pcs : (unit ?? Unit.pcs),
      addedReason: AddedReason.recipe,
      notes: note,
    );
  }

  static String _note(String title) {
    final String text = 'For $title';
    return text.length > maxNoteLength
        ? text.substring(0, maxNoteLength)
        : text;
  }
}
