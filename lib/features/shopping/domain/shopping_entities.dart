import '../../../core/util/date_only.dart';
import '../../pantry/domain/unit.dart';
import 'shopping_enums.dart';

/// The most days a custom repeat can be set to.
const int kMaxRepeatEveryDays = 365;

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
    this.repeatEveryDays,
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

  /// A custom repeat ("every 10 days"). When set it replaces the length of
  /// [recurrence], which then holds the closest built-in repeat. Null for the
  /// built-in repeats and for entries that do not repeat.
  final int? repeatEveryDays;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// "2 kg".
  String get quantityLabel => unit.format(quantity);

  /// True when the entry is on the list on [today] (not waiting for its next
  /// repeat date).
  ///
  /// With [pausedUntil] (the return day of a trip that holds repeating items
  /// back), a repeating entry is not on the list before that day.
  bool isDueOn(DateTime today, {DateTime? pausedUntil}) {
    if (_isPausedOn(today, pausedUntil)) {
      return false;
    }
    final DateTime? due = dueOn;
    return due == null || !due.isAfter(today);
  }

  /// The day the entry is back on the list when it is waiting, or null when
  /// it has no date. A repeating entry held back by a trip comes back on the
  /// return day at the earliest.
  DateTime? comesBackOn(DateTime today, {DateTime? pausedUntil}) {
    final DateTime? due = dueOn;
    if (!_isPausedOn(today, pausedUntil)) {
      return due;
    }
    if (due == null || due.isBefore(pausedUntil!)) {
      return pausedUntil;
    }
    return due;
  }

  bool _isPausedOn(DateTime today, DateTime? pausedUntil) {
    return pausedUntil != null &&
        recurrence.repeats &&
        today.isBefore(pausedUntil);
  }

  /// Days between purchases: the custom number when there is one, else the
  /// length of the built-in repeat. Null when the entry does not repeat.
  int? get intervalDays {
    if (!recurrence.repeats) {
      return null;
    }
    return repeatEveryDays ?? recurrence.approxDays;
  }

  /// "Every week", "Every 10 days" or "Does not repeat".
  String get repeatLabel {
    final int? days = repeatEveryDays;
    if (!recurrence.repeats || days == null) {
      return recurrence.label;
    }
    return days == 1 ? 'Every day' : 'Every $days days';
  }

  /// The day an entry bought on [from] is due again.
  DateTime nextDueAfter(DateTime from) {
    final int? days = repeatEveryDays;
    if (recurrence.repeats && days != null && days >= 1) {
      return addDays(from, days);
    }
    return recurrence.nextDue(from);
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
    int? repeatEveryDays,
    bool clearRepeatEveryDays = false,
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
      repeatEveryDays: clearRepeatEveryDays
          ? null
          : (repeatEveryDays ?? this.repeatEveryDays),
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
    this.repeatEveryDays,
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

  /// A custom repeat in days; only used when [recurrence] repeats.
  final int? repeatEveryDays;
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
