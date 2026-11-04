import 'consumption_type.dart';
import 'entities.dart';
import 'unit.dart';

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

  /// Case-insensitive exact match on the canonical name.
  Future<Item?> findItemByName(String name);

  Future<Item?> findItemByBarcode(String barcode);

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
  /// it as [type].
  Future<UseResult> useStock({
    required String itemId,
    required double quantity,
    required Unit unit,
    ConsumptionType type = ConsumptionType.used,
  });

  /// Writes off everything left in one batch as [type] (wasted or expired).
  Future<UseResult> discardBatch({
    required String batchId,
    required ConsumptionType type,
  });

  /// Reverses a [useStock] or [discardBatch].
  Future<void> undoUse(UseResult result);

  /// Adds the ten sample items (skipping names that exist). Returns how many
  /// were added.
  Future<int> insertSampleData();
}
