import 'shopping_entities.dart';

/// Everything the shopping features need from storage. Like the pantry, the
/// local database is the source of truth and cloud sync (Phase 6) works
/// behind this interface.
///
/// Methods throw a `PantryFailure` (see pantry/domain/failures.dart) for
/// problems the person can fix.
abstract interface class ShoppingRepository {
  /// Lists in display order. Emits again on every change.
  Stream<List<ShoppingList>> watchLists();

  /// Every active entry of every list, oldest first.
  Stream<List<ShoppingEntry>> watchEntries();

  Future<ShoppingList> addList(String name);

  Future<ShoppingList> renameList(String listId, String name);

  /// Soft-deletes the list and its entries. The last list cannot be deleted.
  Future<ListDeleteToken> deleteList(String listId);

  Future<void> undoDeleteList(ListDeleteToken token);

  /// Adds an entry. When the same thing (same item or name, compatible unit,
  /// same repeat) is already waiting unchecked on the list, its quantity is
  /// increased instead of adding a duplicate, and that entry is returned.
  Future<ShoppingEntry> addEntry(ShoppingEntryDraft draft);

  /// Adds several entries in one go. Returns how many were added or merged.
  Future<int> addEntries(List<ShoppingEntryDraft> drafts);

  /// Saves edits to name, quantity, unit, priority, notes, repeat and list.
  Future<ShoppingEntry> updateEntry(ShoppingEntry entry);

  Future<void> setChecked(String entryId, {required bool checked});

  Future<void> deleteEntry(String entryId);

  Future<void> undoDeleteEntry(String entryId);

  /// "Done shopping": turns the list's checked entries into pantry stock.
  ///
  /// Entries linked to a pantry item add a batch to it; free-text entries find
  /// the pantry item with the same name or create one (category Other). Bought
  /// entries are removed from the list, except repeating ones, which go back
  /// to unchecked and come due again on their next date. [store] is applied to
  /// every batch.
  Future<CheckoutResult> completeShopping({
    required String listId,
    required List<CheckoutLine> lines,
    String? store,
  });

  /// Reverses [completeShopping].
  Future<void> undoCompleteShopping(CheckoutResult result);
}
