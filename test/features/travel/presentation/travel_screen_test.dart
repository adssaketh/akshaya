import 'package:akshaya/core/design/design.dart';
import 'package:akshaya/core/time/clock.dart';
import 'package:akshaya/features/travel/domain/trip_models.dart';
import 'package:akshaya/features/travel/presentation/travel_screen.dart';
import 'package:akshaya/features/travel/presentation/trip_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fake_trip_repository.dart';

Future<FakeTripRepository> pumpScreen(
  WidgetTester tester, {
  List<Trip> trips = const <Trip>[],
}) async {
  final FakeTripRepository repo = FakeTripRepository(trips: trips);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        tripRepositoryProvider.overrideWithValue(repo),
        clockProvider.overrideWithValue(() => DateTime(2026, 11, 4, 10)),
      ],
      child: MaterialApp(
        theme: AkshayaTheme.light(),
        home: const TravelScreen(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  return repo;
}

void main() {
  testWidgets('shows an invitation when there are no trips', (tester) async {
    await pumpScreen(tester);
    expect(find.text('No trips yet'), findsOneWidget);
    expect(find.text('Add trip'), findsWidgets);
  });

  testWidgets('lists upcoming and past trips with their state', (tester) async {
    await pumpScreen(
      tester,
      trips: <Trip>[
        Trip(
          id: 'a',
          name: 'Goa',
          start: DateTime(2026, 11, 6),
          end: DateTime(2026, 11, 10),
          pauseRecurring: true,
          pauseAlerts: true,
          essentials: const <EssentialLine>[],
          essentialsAdded: false,
        ),
        Trip(
          id: 'b',
          name: 'Hampi',
          start: DateTime(2026, 10, 1),
          end: DateTime(2026, 10, 3),
          pauseRecurring: true,
          pauseAlerts: true,
          essentials: const <EssentialLine>[],
          essentialsAdded: true,
        ),
      ],
    );
    expect(find.text('Goa'), findsOneWidget);
    expect(find.text('Starts in 2 days'), findsOneWidget);
    expect(find.text('Hampi'), findsOneWidget);
    expect(find.text('Back home'), findsOneWidget);
  });

  test('phase labels', () {
    final Trip trip = Trip(
      id: 'a',
      name: '',
      start: DateTime(2026, 11, 6),
      end: DateTime(2026, 11, 10),
      pauseRecurring: true,
      pauseAlerts: true,
      essentials: const <EssentialLine>[],
      essentialsAdded: false,
    );
    expect(tripPhaseLabel(trip, DateTime(2026, 11, 5)), 'Starts tomorrow');
    expect(tripPhaseLabel(trip, DateTime(2026, 11, 8)), 'Away, back in 2 days');
    expect(tripPhaseLabel(trip, DateTime(2026, 11, 9)), 'Away, back tomorrow');
    expect(tripPhaseLabel(trip, DateTime(2026, 11, 10)), 'Back home');
    expect(trip.label, 'Trip');
  });
}
