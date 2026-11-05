import 'dart:async';

import 'package:akshaya/features/travel/domain/trip_models.dart';
import 'package:akshaya/features/travel/domain/trip_repository.dart';

/// In-memory trip repository for widget and domain tests. The stream emits
/// again on every change, like the database.
class FakeTripRepository implements TripRepository {
  FakeTripRepository({List<Trip> trips = const <Trip>[]})
      : _trips = List<Trip>.of(trips);

  final List<Trip> _trips;
  final StreamController<void> _changes = StreamController<void>.broadcast();
  final List<String> deletedIds = <String>[];
  final List<String> undeletedIds = <String>[];
  final List<String> essentialsAddedFor = <String>[];
  int _next = 1;

  List<Trip> get trips => List<Trip>.unmodifiable(_trips);

  void _emit() => _changes.add(null);

  List<Trip> _sorted() {
    final List<Trip> copy = List<Trip>.of(_trips)
      ..sort((Trip a, Trip b) => a.start.compareTo(b.start));
    return copy;
  }

  @override
  Stream<List<Trip>> watchAll() async* {
    yield _sorted();
    yield* _changes.stream.map((_) => _sorted());
  }

  @override
  Future<List<Trip>> readAll() async => _sorted();

  @override
  Future<Trip> add(TripDraft draft) async {
    final Trip trip = Trip(
      id: 'trip-${_next++}',
      name: draft.name.trim(),
      start: draft.start,
      end: draft.end,
      pauseRecurring: draft.pauseRecurring,
      pauseAlerts: draft.pauseAlerts,
      essentials: draft.essentials,
      essentialsAdded: false,
    );
    _trips.add(trip);
    _emit();
    return trip;
  }

  @override
  Future<void> update(Trip trip) async {
    final int i = _trips.indexWhere((Trip t) => t.id == trip.id);
    if (i >= 0) {
      _trips[i] = trip;
      _emit();
    }
  }

  @override
  Future<void> markEssentialsAdded(String id) async {
    final int i = _trips.indexWhere((Trip t) => t.id == id);
    if (i >= 0) {
      _trips[i] = _trips[i].copyWith(essentialsAdded: true);
      essentialsAddedFor.add(id);
      _emit();
    }
  }

  @override
  Future<void> delete(String id) async {
    deletedIds.add(id);
    _trips.removeWhere((Trip t) => t.id == id);
    _emit();
  }

  @override
  Future<void> undoDelete(String id) async {
    undeletedIds.add(id);
  }
}
