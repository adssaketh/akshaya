import 'consumption_type.dart';
import 'entities.dart';
import 'stock_count.dart';
import 'storage_location.dart';
import 'unit.dart';
import 'waste_reason.dart';

/// Everything the pantry features need from storage. The local database is
/// the single source of truth; cloud sync (Phase 6) works behind this
/// interface without changing callers.
///
/// Methods throw a `PantryFailure` (see failures.dart) for problems the person
/// can fix, such as a duplicate name or too large an amount.
abstract interface class PantryRepository {
  /// Active items with their active batches. Emits again on every change.
  Stream<List<ItemWithBatches>> watchItems();

  /// Categories in display order.
  Stream<List<Category>> watchCategories();

  /// Usage history of one item, newest first.
  Stream<List<ConsumptionEntry>> watchHistory(String itemId);

  /// Every usage entry of every item, newest first (for Insights).
  Stream<List<ConsumptionEntry>> watchAllHistory();

  /// Adds a category at the end of the list. Throws `InvalidInputFailure`
  /// for an empty or duplicate name.
  Future<Category> addCategory({required String name, required String iconKey});

  /// Changes a category's name and icon (its id never changes).
  Future<void> updateCategory({
    required String id,
    required String name,
    required String iconKey,
  });

  /// Removes a category nobody uses. Throws `InvalidInputFailure` when items
  /// still belong to it or when it is the catch-all "Other" category.
  Future<void> deleteCategory(String id);

  /// Case-insensitive exact match on the canonical name.
  Future<Item?> findItemByName(String name);

  /// The live item that answers to [barcode] (any of its barcodes, in any
  /// spelling of the same code, such as UPC-A and EAN-13), or null.
  Future<Item?> findItemByBarcode(String barcode);

  /// Makes [barcode] also identify the item [itemId]. Does nothing when it
  /// already does; throws `DuplicateBarcodeFailure` when it belongs to another
  /// item. The first barcode an item gets becomes its main barcode.
  Future<void> addBarcode(String itemId, String barcode);

  Future<Item> addItem(ItemDraft draft);

  Future<Item> updateItem(Item item);

  /// Soft-deletes the item and its batches.
  Future<DeleteToken> deleteItem(String itemId);

  Future<void> undoDeleteItem(DeleteToken token);

  Future<StockBatch> addBatch(BatchDraft draft);

  Future<StockBatch> updateBatch(StockBatch batch);

  Future<void> deleteBatch(String batchId);

  Future<void> undoDeleteBatch(String batchId);

  /// Takes [quantity] from the item's batches, first-expiring first, and logs
  /// it as [type]. [wasteReason] is stored on the log when the food is thrown
  /// away; it is ignored for any other type.
  Future<UseResult> useStock({
    required String itemId,
    required double quantity,
    required Unit unit,
    ConsumptionType type = ConsumptionType.used,
    WasteReason? wasteReason,
  });

  /// Writes off everything left in one batch as [type] (wasted or expired),
  /// with the optional [wasteReason].
  Future<UseResult> discardBatch({
    required String batchId,
    required ConsumptionType type,
    WasteReason? wasteReason,
  });

  /// Reverses a [useStock] or [discardBatch].
  Future<void> undoUse(UseResult result);

  /// Sets what the item holds to [quantity] (any unit that converts to the
  /// item's own), as found in a count or a spoken "set to" command.
  ///
  /// With [location], only batches kept there are compared and changed, and a
  /// surplus is added there. Less than expected lowers the batches first
  /// expiring first and logs an `adjustment` (or `wasted` when [asWaste]).
  /// More than expected adds a new batch (today, no expiry, no price) and logs
  /// a negative `adjustment`. An equal count writes nothing.
  ///
  /// Throws `InvalidInputFailure` for a negative or non-numeric amount and
  /// `UnitMismatchFailure` when the unit does not convert.
  Future<CountResult> setStock({
    required String itemId,
    required double quantity,
    required Unit unit,
    StorageLocation? location,
    bool asWaste = false,
  });

  /// Reverses a [setStock]. Does nothing when it changed nothing.
  Future<void> undoCount(CountResult result);
}
