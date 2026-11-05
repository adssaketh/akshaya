import 'package:akshaya/core/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/clock.dart';
import '../domain/travel_plan.dart';
import '../domain/trip_models.dart';
import 'travel_screen.dart';
import 'trip_detail_screen.dart';
import 'trip_providers.dart';

/// The Home card for the trip that is on now or starts within two weeks;
/// nothing when there is none.
class TripBanner extends ConsumerWidget {
  const TripBanner({super.key, required this.onShowRecipes});

  final VoidCallback onShowRecipes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Trip? trip = ref.watch(featuredTripProvider);
    if (trip == null) {
      return const SizedBox.shrink();
    }
    final AkshayaColors colors = context.akColors;
    final DateTime today = ref.watch(todayProvider);
    final List<TravelRisk> risks = ref.watch(travelRisksProvider(trip.id));
    final String risk = risks.isEmpty
        ? 'Nothing will go off while you are away.'
        : '${risks.length} ${risks.length == 1 ? 'item' : 'items'} will go '
            'off before you are back.';
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Material(
        color: colors.surfaceAlt,
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
                Icon(
                  trip.phaseOn(today) == TripPhase.away
                      ? Icons.flight_takeoff_rounded
                      : Icons.luggage_rounded,
                  color: colors.primary,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '${trip.label} · ${tripPhaseLabel(trip, today)}',
                        style: context.akText.titleSmall,
                      ),
                      Text(
                        risk,
                        style: context.akText.bodySmall!.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: colors.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
