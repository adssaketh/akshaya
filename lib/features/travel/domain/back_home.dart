import '../../../core/util/date_only.dart';
import '../../pantry/domain/entities.dart';
import '../../pantry/domain/pantry_repository.dart';
import '../../shopping/domain/shopping_entities.dart';
import '../../shopping/domain/shopping_enums.dart';
import '../../shopping/domain/shopping_repository.dart';
import 'trip_models.dart';
import 'trip_repository.dart';

/// The "Back home" checklist: the essentials that go on the shopping list the
/// day before the household returns. Pure rules plus one function that does
/// the work from the repositories (the app and the background check both use
/// it).
abstract final class BackHome {
  /// How many days after the return day the checklist can still be added (for
  /// a phone that was off or not opened).
  static const int graceDays = 3;

  /// Whether [trip]'s essentials should be added on [today]: from the day
  /// before the return, once, and only if the trip has any.
  static bool isDue(Trip trip, DateTime today) {
    if (trip.essentialsAdded || trip.essentials.isEmpty) {
      return false;
    }
    final DateTime day = dateOnly(today);
    return !day.isBefore(trip.essentialsDay) &&
        !day.isAfter(addDays(trip.end, graceDays));
  }

  /// The essentials that are not already on a shopping list waiting to be
  /// bought (unticked and due), so nothing is doubled.
  static List<EssentialLine> missingFrom(
    Trip trip,
    List<ShoppingEntry> entries,
    DateTime today,
  ) {
    final Set<String> waiting = <String>{
      for (final ShoppingEntry e in entries)
        if (!e.isChecked && e.isDueOn(today)) e.name.trim().toLowerCase(),
    };
    return <EssentialLine>[
      for (final EssentialLine line in trip.essentials)
        if (!waiting.contains(line.name.trim().toLowerCase())) line,
    ];
  }
}

/// Puts the essentials of every trip that is due on [today] on the first
/// shopping list and marks those trips done. Returns how many entries were
/// added.
///
/// A line is linked to a pantry item when one has that name; if the unit
/// does not fit that item, it is added as plain text instead. One line that
/// cannot be added never stops the others.
Future<int> addBackHomeEssentials({
  required TripRepository trips,
  required ShoppingRepository shopping,
  required PantryRepository pantry,
  required DateTime today,
}) async {
  int added = 0;
  for (final Trip trip in await trips.readAll()) {
    if (BackHome.isDue(trip, today)) {
      added += await addEssentialsFor(
        trips: trips,
        shopping: shopping,
        pantry: pantry,
        trip: trip,
        today: today,
      );
    }
  }
  return added;
}

/// Puts the essentials of one [trip] on the first shopping list right now
/// (skipping what is already waiting there) and marks the trip done. Returns
/// how many entries were added.
Future<int> addEssentialsFor({
  required TripRepository trips,
  required ShoppingRepository shopping,
  required PantryRepository pantry,
  required Trip trip,
  required DateTime today,
}) async {
  final List<ShoppingList> lists = await shopping.watchLists().first;
  final String listId = lists.isEmpty ? kDefaultListId : lists.first.id;
  final List<ShoppingEntry> entries = await shopping.watchEntries().first;
  int added = 0;
  for (final EssentialLine line
      in BackHome.missingFrom(trip, entries, dateOnly(today))) {
    added += await _addLine(shopping, pantry, listId, trip, line);
  }
  await trips.markEssentialsAdded(trip.id);
  return added;
}

Future<int> _addLine(
  ShoppingRepository shopping,
  PantryRepository pantry,
  String listId,
  Trip trip,
  EssentialLine line,
) async {
  final String note = 'Back home from ${trip.label}';
  Item? item;
  try {
    item = await pantry.findItemByName(line.name);
  } on Object {
    item = null;
  }
  if (item != null && item.defaultUnit.isCompatibleWith(line.unit)) {
    try {
      await shopping.addEntry(
        ShoppingEntryDraft(
          listId: listId,
          itemId: item.id,
          name: item.name,
          quantity: line.quantity,
          unit: line.unit,
          addedReason: AddedReason.manual,
          notes: note,
        ),
      );
      return 1;
    } on Object {
      // Fall through to a plain-text entry.
    }
  }
  try {
    await shopping.addEntry(
      ShoppingEntryDraft(
        listId: listId,
        name: line.name,
        quantity: line.quantity,
        unit: line.unit,
        addedReason: AddedReason.manual,
        notes: note,
      ),
    );
    return 1;
  } on Object {
    return 0;
  }
}
