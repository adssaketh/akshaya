import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/clock.dart';
import '../../pantry/domain/stock_logic.dart';
import '../../pantry/presentation/providers.dart';
import '../../rescue/presentation/providers.dart';
import '../data/drift_trip_repository.dart';
import '../domain/travel_plan.dart';
import '../domain/trip_models.dart';
import '../domain/trip_repository.dart';

// This file is imported by the shopping providers (to hold repeating entries
// back during a trip), so it must not import them. Anything that needs the
// shopping repository lives in back_home_coordinator.dart.

final Provider<TripRepository> tripRepositoryProvider =
    Provider<TripRepository>((Ref ref) {
  return DriftTripRepository(
    ref.watch(appDatabaseProvider),
    clock: ref.watch(clockProvider),
  );
});

/// Every trip, soonest leaving day first.
final StreamProvider<List<Trip>> tripsProvider =
    StreamProvider<List<Trip>>((Ref ref) {
  return ref.watch(tripRepositoryProvider).watchAll();
});

/// The day repeating shopping items come back, while a trip holds them back
/// today; null when nothing is held back.
final Provider<DateTime?> recurringResumeProvider =
    Provider<DateTime?>((Ref ref) {
  final DateTime today = ref.watch(todayProvider);
  final List<Trip> trips =
      ref.watch(tripsProvider).value ?? const <Trip>[];
  return TripSchedule.recurringResumeOn(today, trips);
});

/// The trip to feature on Home: the one away now, else the next one starting
/// within two weeks.
final Provider<Trip?> featuredTripProvider = Provider<Trip?>((Ref ref) {
  final DateTime today = ref.watch(todayProvider);
  final List<Trip> trips =
      ref.watch(tripsProvider).value ?? const <Trip>[];
  return TripSchedule.featured(today, trips);
});

/// One trip by id, or null when it does not exist (any more).
final tripProvider = Provider.family<Trip?, String>((Ref ref, String id) {
  final List<Trip> trips =
      ref.watch(tripsProvider).value ?? const <Trip>[];
  for (final Trip trip in trips) {
    if (trip.id == id) {
      return trip;
    }
  }
  return null;
});

/// The food that will not last until the trip with this id ends.
final travelRisksProvider =
    Provider.family<List<TravelRisk>, String>((Ref ref, String tripId) {
  final Trip? trip = ref.watch(tripProvider(tripId));
  if (trip == null) {
    return const <TravelRisk>[];
  }
  final List<ItemStock> stocks =
      ref.watch(pantryStocksProvider).value ?? const <ItemStock>[];
  return TravelPlanner.build(
    trip: trip,
    stocks: stocks,
    today: ref.watch(todayProvider),
    freeze: ref.watch(freezeSettingsProvider),
  );
});
