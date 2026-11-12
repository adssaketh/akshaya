import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/util/date_only.dart';
import '../../pantry/data/database/app_database.dart';
import '../domain/trip_models.dart';
import '../domain/trip_repository.dart';
import '../../../core/util/distinct_rows.dart';

/// [TripRepository] backed by the local Drift database.
///
/// Like the other repositories, every write marks the row `pending` for sync
/// (a database trigger does this for edits) and deletes are soft.
class DriftTripRepository implements TripRepository {
  DriftTripRepository(
    this._db, {
    DateTime Function()? clock,
    String Function()? idGenerator,
    String? currentUserId,
  })  : _clock = clock ?? DateTime.now,
        _newId = idGenerator ?? _uuidV4,
        _userId = currentUserId;

  final AppDatabase _db;
  final DateTime Function() _clock;
  final String Function() _newId;
  final String? _userId;

  static String _uuidV4() => const Uuid().v4();

  Trip? _trip(TripRow row) {
    final DateTime start = dateOnly(row.startDate);
    final DateTime end = dateOnly(row.endDate);
    if (!end.isAfter(start)) {
      // Damaged data (for example from a bad import) is skipped, never shown
      // half-broken.
      return null;
    }
    return Trip(
      id: row.id,
      name: row.name,
      start: start,
      end: end,
      pauseRecurring: row.pauseRecurring,
      pauseAlerts: row.pauseAlerts,
      essentials: EssentialLine.decodeList(row.essentialsJson),
      essentialsAdded: row.essentialsAdded,
    );
  }

  @override
  Stream<List<Trip>> watchAll() {
    final SimpleSelectStatement<$TripsTable, TripRow> query =
        _db.select(_db.trips)..where((t) => t.isDeleted.equals(false));
    return query.watch().distinctRows().map((List<TripRow> rows) {
      final List<Trip> out = <Trip>[];
      for (final TripRow row in rows) {
        final Trip? trip = _trip(row);
        if (trip != null) {
          out.add(trip);
        }
      }
      out.sort((Trip a, Trip b) {
        final int byStart = a.start.compareTo(b.start);
        return byStart != 0 ? byStart : a.end.compareTo(b.end);
      });
      return out;
    });
  }

  @override
  Future<List<Trip>> readAll() => watchAll().first;

  @override
  Future<Trip> add(TripDraft draft) async {
    final String problem = validateTripDates(draft.start, draft.end) ?? '';
    if (problem.isNotEmpty) {
      throw ArgumentError(problem);
    }
    final DateTime now = _clock();
    final String id = _newId();
    final DateTime start = dateOnly(draft.start);
    final DateTime end = dateOnly(draft.end);
    await _db.into(_db.trips).insert(
          TripsCompanion.insert(
            id: id,
            createdAt: now,
            updatedAt: now,
            updatedBy: Value<String?>(_userId),
            name: Value<String>(draft.name.trim()),
            startDate: start,
            endDate: end,
            pauseRecurring: Value<bool>(draft.pauseRecurring),
            pauseAlerts: Value<bool>(draft.pauseAlerts),
            essentialsJson: Value<String?>(
              EssentialLine.encodeList(draft.essentials),
            ),
          ),
        );
    return Trip(
      id: id,
      name: draft.name.trim(),
      start: start,
      end: end,
      pauseRecurring: draft.pauseRecurring,
      pauseAlerts: draft.pauseAlerts,
      essentials: draft.essentials,
      essentialsAdded: false,
    );
  }

  @override
  Future<void> update(Trip trip) async {
    final String problem = validateTripDates(trip.start, trip.end) ?? '';
    if (problem.isNotEmpty) {
      throw ArgumentError(problem);
    }
    await (_db.update(_db.trips)..where((t) => t.id.equals(trip.id))).write(
      TripsCompanion(
        name: Value<String>(trip.name.trim()),
        startDate: Value<DateTime>(dateOnly(trip.start)),
        endDate: Value<DateTime>(dateOnly(trip.end)),
        pauseRecurring: Value<bool>(trip.pauseRecurring),
        pauseAlerts: Value<bool>(trip.pauseAlerts),
        essentialsJson: Value<String?>(
          EssentialLine.encodeList(trip.essentials),
        ),
        essentialsAdded: Value<bool>(trip.essentialsAdded),
        isDeleted: const Value<bool>(false),
        updatedAt: Value<DateTime>(_clock()),
        updatedBy: Value<String?>(_userId),
      ),
    );
  }

  @override
  Future<void> markEssentialsAdded(String id) async {
    await (_db.update(_db.trips)..where((t) => t.id.equals(id))).write(
      TripsCompanion(
        essentialsAdded: const Value<bool>(true),
        updatedAt: Value<DateTime>(_clock()),
        updatedBy: Value<String?>(_userId),
      ),
    );
  }

  @override
  Future<void> delete(String id) => _setDeleted(id, deleted: true);

  @override
  Future<void> undoDelete(String id) => _setDeleted(id, deleted: false);

  Future<void> _setDeleted(String id, {required bool deleted}) async {
    await (_db.update(_db.trips)..where((t) => t.id.equals(id))).write(
      TripsCompanion(
        isDeleted: Value<bool>(deleted),
        updatedAt: Value<DateTime>(_clock()),
        updatedBy: Value<String?>(_userId),
      ),
    );
  }
}
