import 'package:akshaya/core/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/clock.dart';
import '../../../core/ui/feedback.dart';
import '../../../core/util/date_only.dart';
import '../domain/trip_models.dart';
import '../domain/trip_repository.dart';
import 'trip_detail_screen.dart';
import 'trip_form_screen.dart';
import 'trip_providers.dart';

/// Opens Travel mode: the list of trips. [onShowRecipes], when given, lets the
/// trip pages offer "Cook something".
Future<void> openTravelMode(
  BuildContext context, {
  VoidCallback? onShowRecipes,
}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (BuildContext _) => TravelScreen(onShowRecipes: onShowRecipes),
    ),
  );
}

/// "Starts tomorrow", "Away, back in 3 days", "Back home".
String tripPhaseLabel(Trip trip, DateTime today) {
  final DateTime day = dateOnly(today);
  switch (trip.phaseOn(day)) {
    case TripPhase.upcoming:
      final int days = daysBetween(day, trip.start);
      return days == 1 ? 'Starts tomorrow' : 'Starts in $days days';
    case TripPhase.away:
      final int days = daysBetween(day, trip.end);
      return days == 1 ? 'Away, back tomorrow' : 'Away, back in $days days';
    case TripPhase.back:
      return 'Back home';
  }
}

/// All trips, with Add trip.
class TravelScreen extends ConsumerWidget {
  const TravelScreen({super.key, this.onShowRecipes});

  final VoidCallback? onShowRecipes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Trip>> trips = ref.watch(tripsProvider);
    final DateTime today = ref.watch(todayProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Travel mode')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'travel-add-trip',
        onPressed: () => openTripForm(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add trip'),
      ),
      body: trips.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace stack) => const EmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Could not load your trips',
          body: 'Please try again in a moment.',
        ),
        data: (List<Trip> list) {
          if (list.isEmpty) {
            return EmptyState(
              icon: Icons.luggage_rounded,
              title: 'No trips yet',
              body: 'Tell Akshaya when you are away. It will warn you about '
                  'food that will go off, pause alerts and repeating items, '
                  'and remind you to restock before you return.',
              actionLabel: 'Add trip',
              onAction: () => openTripForm(context),
            );
          }
          final List<Trip> current = <Trip>[
            for (final Trip t in list)
              if (t.phaseOn(today) != TripPhase.back) t,
          ];
          final List<Trip> past = <Trip>[
            for (final Trip t in list.reversed)
              if (t.phaseOn(today) == TripPhase.back) t,
          ];
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.xxl * 3,
            ),
            children: <Widget>[
              if (current.isNotEmpty) ...<Widget>[
                const SectionHeader(title: 'Upcoming and now'),
                const SizedBox(height: AppSpacing.sm),
                for (final Trip t in current)
                  _TripTile(trip: t, today: today, onShowRecipes: onShowRecipes),
              ],
              if (past.isNotEmpty) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                const SectionHeader(title: 'Past trips'),
                const SizedBox(height: AppSpacing.sm),
                for (final Trip t in past)
                  _TripTile(trip: t, today: today, onShowRecipes: onShowRecipes),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _TripTile extends ConsumerWidget {
  const _TripTile({
    required this.trip,
    required this.today,
    required this.onShowRecipes,
  });

  final Trip trip;
  final DateTime today;
  final VoidCallback? onShowRecipes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AkshayaColors colors = context.akColors;
    final TripPhase phase = trip.phaseOn(today);
    return Dismissible(
      key: ValueKey<String>('trip-${trip.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.lg),
        child: Icon(Icons.delete_outline_rounded, color: colors.expired.foreground),
      ),
      onDismissed: (DismissDirection _) async {
        final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
        final TripRepository repo = ref.read(tripRepositoryProvider);
        await repo.delete(trip.id);
        showUndoSnackBar(
          messenger,
          message: 'Deleted ${trip.label}',
          onUndo: () => repo.undoDelete(trip.id),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Material(
          color: colors.surface,
          borderRadius: AppRadius.cardBorder,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => openTripDetail(
              context,
              trip.id,
              onShowRecipes: onShowRecipes,
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: <Widget>[
                  Container(
                    width: AppSizes.avatar,
                    height: AppSizes.avatar,
                    decoration: BoxDecoration(
                      color: colors.surfaceAlt,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      phase == TripPhase.away
                          ? Icons.flight_takeoff_rounded
                          : Icons.luggage_rounded,
                      size: AppSizes.iconMd,
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(trip.label, style: context.akText.titleMedium),
                        Text(
                          '${trip.dateRange} · ${trip.nights} '
                          '${trip.nights == 1 ? 'night' : 'nights'}',
                          style: context.akText.bodySmall!.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                        Text(
                          tripPhaseLabel(trip, today),
                          style: context.akText.labelMedium!.copyWith(
                            color: colors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: colors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
