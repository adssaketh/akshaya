import 'trip_models.dart';

/// Everything travel mode needs from storage. Like the pantry, the local
/// database is the source of truth and cloud sync works behind this interface.
abstract interface class TripRepository {
  /// Every trip, soonest leaving day first. Emits again on every change.
  Stream<List<Trip>> watchAll();

  /// The same as [watchAll], once.
  Future<List<Trip>> readAll();

  Future<Trip> add(TripDraft draft);

  /// Saves changes to a trip (dates, switches, the essentials list).
  Future<void> update(Trip trip);

  /// Records that the back-home essentials were put on the shopping list.
  Future<void> markEssentialsAdded(String id);

  /// Removes a trip (a soft delete, so it can be undone and synced).
  Future<void> delete(String id);

  Future<void> undoDelete(String id);
}
