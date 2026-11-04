import '../../pantry/domain/unit.dart';
import 'shopping_enums.dart';

/// Id of the list every install starts with. It is a fixed id (not a random
/// UUID) so devices that sync later agree on it.
const String kDefaultListId = 'list_default';

/// Name of the starting list. People can rename it.
const String kDefaultListName = 'Shopping list';

/// A named shopping list ("Weekly", "DMart").
final class ShoppingList {
  const ShoppingList({
    required this.id,
    required this.name,
    required this.sortOrder,
  });

  final String id;
  final String name;
  final int sortOrder;
}

/// One thing to buy. Linked to a pantry item ([itemId]) or free text.
final class ShoppingEntry {
  const ShoppingEntry({
    required this.id,
    required this.listId,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.isChecked,
    required this.addedReason,
    required this.priority,
    required this.recurrence,
    required this.createdAt,
    required this.updatedAt,
    this.itemId,
    this.notes,
    this.dueOn,
  });

  final String id;
  final String listId;

  /// The pantry item this entry restocks, or null for a free-text entry.
  final String? itemId;

  /// English display name. For linked entries it is the item's name when the
  /// entry was added.
  final String name;
  final double quantity;
  final Unit unit;
  final bool isChecked;
  final AddedReason addedReason;
  final ShoppingPriority priority;
  final String? notes;
  final Recurrence recurrence;

  /// For repeating entries: the day the entry shows up again. Null (or today
  /// or earlier) means it is on the list now.
  final DateTime? dueOn;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// "2 kg".
  String get quantityLabel => unit.format(quantity);

  /// True when the entry is on the list on [today] (not waiting for its next
  /// repeat date).
  bool isDueOn(DateTime today) {
    final DateTime? due = dueOn;
    return due == null || !due.isAfter(today);
  }

  ShoppingEntry copyWith({
    String? listId,
    String? itemId,
    bool clearItemId = false,
    String? name,
    double? quantity,
    Unit? unit,
    bool? isChecked,
    AddedReason? addedReason,
    ShoppingPriority? priority,
    String? notes,
    bool clearNotes = false,
    Recurrence? recurrence,
    DateTime? dueOn,
    bool clearDueOn = false,
  }) {
    return ShoppingEntry(
      id: id,
      listId: listId ?? this.listId,
      itemId: clearItemId ? null : (itemId ?? this.itemId),
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      isChecked: isChecked ?? this.isChecked,
      addedReason: addedReason ?? this.addedReason,
      priority: priority ?? this.priority,
      notes: clearNotes ? null : (notes ?? this.notes),
      recurrence: recurrence ?? this.recurrence,
      dueOn: clearDueOn ? null : (dueOn ?? this.dueOn),
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

/// Everything needed to add an entry.
final class ShoppingEntryDraft {
  const ShoppingEntryDraft({
    required this.listId,
    required this.name,
    required this.quantity,
    required this.unit,
    this.itemId,
    this.addedReason = AddedReason.manual,
    this.priority = ShoppingPriority.normal,
    this.notes,
    this.recurrence = Recurrence.none,
  });

  final String listId;
  final String? itemId;
  final String name;
  final double quantity;
  final Unit unit;
  final AddedReason addedReason;
  final ShoppingPriority priority;
  final String? notes;
  final Recurrence recurrence;
}

/// What deleting a list changed, so it can be undone.
final class ListDeleteToken {
  const ListDeleteToken({required this.listId, required this.entryIds});

  final String listId;

  /// Entries that were deleted together with the list.
  final List<String> entryIds;
}

/// What the person told "Done shopping" about one checked entry.
final class CheckoutLine {
  const CheckoutLine({required this.entryId, this.expiryDate, this.price});

  final String entryId;
  final DateTime? expiryDate;

  /// Total paid for this entry, in rupees.
  final double? price;
}

/// What "Done shopping" changed, so it can be undone.
final class CheckoutResult {
  const CheckoutResult({
    required this.batchIds,
    required this.previousEntries,
    required this.createdItemIds,
  });

  /// Pantry batches that were created.
  final List<String> batchIds;

  /// The entries as they were before checkout (checked, not deleted).
  final List<ShoppingEntry> previousEntries;

  /// Pantry items that did not exist and were created for free-text entries.
  final List<String> createdItemIds;

  int get count => batchIds.length;
}
