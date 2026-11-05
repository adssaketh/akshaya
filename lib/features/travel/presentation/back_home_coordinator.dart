import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/clock.dart';
import '../../pantry/presentation/providers.dart';
import '../../shopping/presentation/providers.dart';
import '../domain/back_home.dart';
import '../domain/trip_models.dart';
import 'trip_providers.dart';

/// Puts a trip's "Back home" essentials on the shopping list the day before
/// the return. Read once at start-up.
///
/// It looks again whenever the trips change and when a new day starts. Each
/// trip is done once (the trip remembers), and the background check does the
/// same job when the app is not open.
final Provider<void> backHomeCoordinatorProvider = Provider<void>((Ref ref) {
  bool running = false;
  bool disposed = false;

  Future<void> run() async {
    if (running || disposed) {
      return;
    }
    running = true;
    try {
      await addBackHomeEssentials(
        trips: ref.read(tripRepositoryProvider),
        shopping: ref.read(shoppingRepositoryProvider),
        pantry: ref.read(pantryRepositoryProvider),
        today: ref.read(todayProvider),
      );
    } on Object catch (error) {
      // A convenience: never let a failure here disturb the app.
      debugPrint('Could not add the back-home essentials: $error');
    } finally {
      running = false;
    }
  }

  ref.listen<AsyncValue<List<Trip>>>(
    tripsProvider,
    (AsyncValue<List<Trip>>? previous, AsyncValue<List<Trip>> next) {
      if (next.hasValue) {
        unawaited(run());
      }
    },
    fireImmediately: true,
  );
  ref.listen<DateTime>(todayProvider, (DateTime? previous, DateTime next) {
    unawaited(run());
  });
  ref.onDispose(() => disposed = true);
});
