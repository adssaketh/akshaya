import 'package:akshaya/core/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/clock.dart';
import '../../../core/ui/feedback.dart';
import '../../../core/util/date_only.dart';
import '../../pantry/domain/entities.dart';
import '../../pantry/presentation/pantry_actions.dart';
import '../../pantry/presentation/pantry_icons.dart';
import '../../pantry/presentation/providers.dart';
import '../../rescue/presentation/rescue_actions.dart';
import '../domain/travel_plan.dart';
import '../domain/trip_models.dart';
import '../domain/trip_repository.dart';
import 'travel_actions.dart';
import 'travel_screen.dart';
import 'trip_form_screen.dart';
import 'trip_providers.dart';

/// Opens one trip.
Future<void> openTripDetail(
  BuildContext context,
  String tripId, {
  VoidCallback? onShowRecipes,
}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (BuildContext _) =>
          TripDetailScreen(tripId: tripId, onShowRecipes: onShowRecipes),
    ),
  );
}

/// A trip: its dates, the food that will not last until the return with
/// quick actions, and the back-home checklist.
class TripDetailScreen extends ConsumerWidget {
  const TripDetailScreen({super.key, required this.tripId, this.onShowRecipes});

  final String tripId;
  final VoidCallback? onShowRecipes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Trip? trip = ref.watch(tripProvider(tripId));
    if (trip == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Trip')),
        body: const EmptyState(
          icon: Icons.luggage_rounded,
          title: 'Trip not found',
          body: 'It may have been deleted.',
        ),
      );
    }
    final AkshayaColors colors = context.akColors;
    final DateTime today = ref.watch(todayProvider);
    final List<TravelRisk> risks = ref.watch(travelRisksProvider(tripId));
    final Map<String, Category> categories = ref.watch(categoriesByIdProvider);
    final bool over = trip.phaseOn(today) == TripPhase.back;

    return Scaffold(
      appBar: AppBar(
        title: Text(trip.label),
        actions: <Widget>[
          IconButton(
            tooltip: 'Edit trip',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => openTripForm(context, trip: trip),
          ),
          IconButton(
            tooltip: 'Delete trip',
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () async {
              final ScaffoldMessengerState messenger =
                  ScaffoldMessenger.of(context);
              final NavigatorState navigator = Navigator.of(context);
              final TripRepository repo = ref.read(tripRepositoryProvider);
              await repo.delete(trip.id);
              navigator.pop();
              showUndoSnackBar(
                messenger,
                message: 'Deleted ${trip.label}',
                onUndo: () => repo.undoDelete(trip.id),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: <Widget>[
          Material(
            color: colors.surface,
            borderRadius: AppRadius.cardBorder,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(trip.dateRange, style: context.akText.titleMedium),
                  Text(
                    '${trip.nights} ${trip.nights == 1 ? 'night' : 'nights'} · '
                    '${tripPhaseLabel(trip, today)}',
                    style: context.akText.bodyMedium!.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    <String>[
                      if (trip.pauseAlerts) 'Alerts paused while away',
                      if (trip.pauseRecurring) 'Repeating items paused',
                    ].join(' · '),
                    style: context.akText.bodySmall!.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const SectionHeader(title: 'Will not last until you are back'),
          const SizedBox(height: AppSpacing.sm),
          if (over)
            Text(
              'This trip is over.',
              style: context.akText.bodyMedium!.copyWith(
                color: colors.textSecondary,
              ),
            )
          else if (risks.isEmpty)
            Text(
              'Everything with a date will keep until you are back.',
              style: context.akText.bodyMedium!.copyWith(
                color: colors.textSecondary,
              ),
            )
          else
            for (final TravelRisk risk in risks)
              Padding(
                key: ValueKey<String>('risk-${risk.batch.id}'),
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _RiskCard(
                  risk: risk,
                  icon: categoryIcon(categories[risk.item.categoryId]?.iconKey),
                  onShowRecipes: onShowRecipes,
                ),
              ),
          const SizedBox(height: AppSpacing.md),
          const SectionHeader(title: 'Back home checklist'),
          const SizedBox(height: AppSpacing.sm),
          if (trip.essentials.isEmpty)
            Text(
              'Nothing on the checklist. Edit the trip to add items.',
              style: context.akText.bodyMedium!.copyWith(
                color: colors.textSecondary,
              ),
            )
          else ...<Widget>[
            for (final EssentialLine line in trip.essentials)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: Icon(
                  trip.essentialsAdded
                      ? Icons.check_circle_rounded
                      : Icons.shopping_basket_outlined,
                  color: trip.essentialsAdded
                      ? colors.fresh.foreground
                      : colors.textSecondary,
                ),
                title: Text(line.label),
              ),
            Text(
              trip.essentialsAdded
                  ? 'Added to your shopping list.'
                  : 'Goes on your shopping list on '
                      '${formatDateShort(trip.essentialsDay)}.',
              style: context.akText.bodySmall!.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RiskCard extends ConsumerWidget {
  const _RiskCard({
    required this.risk,
    required this.icon,
    required this.onShowRecipes,
  });

  final TravelRisk risk;
  final IconData icon;
  final VoidCallback? onShowRecipes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool cook = risk.advice == TravelAdvice.cookNow;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ItemCard(
          name: risk.item.name,
          subtitle: '${risk.reason}\n${risk.subtitle}',
          icon: icon,
          status: StatusKind.expiring,
          statusLabel: risk.advice.label,
          onTap: () => openItemDetail(context, risk.item.id),
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: <Widget>[
            ActionChip(
              avatar: const Icon(
                Icons.remove_circle_outline_rounded,
                size: AppSizes.iconSm,
              ),
              label: Text(cook ? 'Use it' : 'Use'),
              onPressed: () => rescueUse(context, risk.entry),
            ),
            if (onShowRecipes != null)
              ActionChip(
                avatar: const Icon(
                  Icons.soup_kitchen_rounded,
                  size: AppSizes.iconSm,
                ),
                label: const Text('Cook something'),
                onPressed: () {
                  Navigator.of(context).popUntil((Route<void> r) => r.isFirst);
                  onShowRecipes!();
                },
              ),
            if (risk.canFreeze)
              ActionChip(
                avatar: const Icon(Icons.ac_unit_rounded, size: AppSizes.iconSm),
                label: const Text('Freeze'),
                onPressed: () => rescueFreeze(context, ref, risk.entry),
              ),
            ActionChip(
              avatar: const Icon(
                Icons.volunteer_activism_rounded,
                size: AppSizes.iconSm,
              ),
              label: const Text('Give away'),
              onPressed: () => travelGiveAway(context, ref, risk),
            ),
            ActionChip(
              avatar: const Icon(
                Icons.delete_outline_rounded,
                size: AppSizes.iconSm,
              ),
              label: const Text('Mark wasted'),
              onPressed: () => rescueWaste(context, ref, risk.entry),
            ),
          ],
        ),
      ],
    );
  }
}
