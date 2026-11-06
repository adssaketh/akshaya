import '../../commands/domain/text_normalizer.dart';
import '../../pantry/domain/entities.dart';
import '../../pantry/domain/failures.dart';
import '../../pantry/domain/pantry_repository.dart';
import 'order_models.dart';

/// What adding an order to the pantry did.
final class OrderCommitResult {
  const OrderCommitResult({
    required this.added,
    required this.createdItemIds,
    required this.batchIdsOnExistingItems,
    required this.failures,
  });

  /// Lines that were added.
  final int added;

  /// Items this import created (undo removes them with their batches).
  final List<String> createdItemIds;

  /// Batches this import added to items that already existed.
  final List<String> batchIdsOnExistingItems;

  /// Lines that could not be added, with the reason ("Rice: ...").
  final List<String> failures;
}

/// Adds the ticked lines of an order to the pantry: one new batch per line,
/// bought today, on an existing item when the name matches, otherwise on a new
/// item with the English name. Lines that fail are reported and the rest still
/// go in.
final class OrderCommitter {
  const OrderCommitter(this.pantry);

  final PantryRepository pantry;

  Future<OrderCommitResult> commit(
    List<OrderDraft> drafts, {
    required DateTime boughtOn,
    String? store,
  }) async {
    final List<String> created = <String>[];
    final List<String> batches = <String>[];
    final List<String> failures = <String>[];
    final String? storeName =
        store == null || store.trim().isEmpty ? null : store.trim();
    int added = 0;
    for (final OrderDraft draft in drafts) {
      if (!draft.include) {
        continue;
      }
      try {
        Item? item = await pantry.findItemByName(draft.name);
        bool isNew = false;
        if (item == null) {
          item = await pantry.addItem(
            ItemDraft(
              name: draft.name,
              brand: draft.brand,
              categoryId: draft.categoryId,
              defaultUnit: draft.unit,
              aliases: _aliases(draft),
              defaultStorageLocation: draft.location,
            ),
          );
          isNew = true;
          created.add(item.id);
        } else if (!draft.unit.isCompatibleWith(item.defaultUnit)) {
          throw InvalidInputFailure(
            '${item.name} is counted in ${item.defaultUnit.symbol}, '
            'not ${draft.unit.symbol}.',
          );
        }
        final StockBatch batch = await pantry.addBatch(
          BatchDraft(
            itemId: item.id,
            quantityBought: draft.quantity,
            unit: draft.unit,
            purchaseDate: boughtOn,
            expiryDate: draft.effectiveExpiry(boughtOn),
            price: draft.price,
            store: storeName,
            storageLocation: draft.location,
          ),
        );
        if (!isNew) {
          batches.add(batch.id);
        }
        added += 1;
      } on PantryFailure catch (failure) {
        failures.add('${draft.name}: ${failure.message}');
      }
    }
    return OrderCommitResult(
      added: added,
      createdItemIds: created,
      batchIdsOnExistingItems: batches,
      failures: failures,
    );
  }

  /// Takes back everything [result] added.
  Future<void> undo(OrderCommitResult result) async {
    for (final String id in result.batchIdsOnExistingItems) {
      await pantry.deleteBatch(id);
    }
    for (final String id in result.createdItemIds) {
      await pantry.deleteItem(id);
    }
  }

  /// The printed name is kept as an alias so the next order of the same
  /// product matches without guessing.
  static List<String> _aliases(OrderDraft draft) {
    final String printed = draft.sourceName.trim();
    if (printed.isEmpty || draft.notes.contains(DraftNote.nameCutOff)) {
      return const <String>[];
    }
    if (phraseTokens(printed).join(' ') == phraseTokens(draft.name).join(' ')) {
      return const <String>[];
    }
    return <String>[printed];
  }
}
