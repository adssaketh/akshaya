import 'dart:async';

import 'package:akshaya/core/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/feedback.dart';
import '../../pantry/domain/entities.dart';
import '../../pantry/domain/stock_count.dart';
import '../../pantry/domain/storage_location.dart';
import '../../pantry/presentation/pantry_icons.dart';
import '../../pantry/presentation/providers.dart';
import '../domain/count_session.dart';
import '../domain/count_settings.dart';
import 'count_flow.dart';
import 'count_screen.dart';
import 'providers.dart';

/// Where to start counting: a storage location, a category or everything,
/// plus a count left half-way to resume.
class CountStartScreen extends ConsumerWidget {
  const CountStartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<ItemWithBatches>> items =
        ref.watch(itemsStreamProvider);
    final List<Category> categories =
        ref.watch(categoriesProvider).value ?? const <Category>[];
    final Map<String, Category> categoriesById =
        ref.watch(categoriesByIdProvider);
    final CountSession? saved = ref.watch(savedCountProvider);
    final CountSettings settings = ref.watch(countSettingsProvider);
    final AkshayaColors colors = context.akColors;

    return Scaffold(
      appBar: AppBar(title: const Text('Count mode')),
      body: SafeArea(
        child: items.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (Object error, StackTrace stack) => EmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Could not load the pantry',
            body: failureMessage(error),
          ),
          data: (List<ItemWithBatches> records) {
            int countOf(CountScope scope) =>
                CountPlanner.lines(records, scope).length;
            final int everything = countOf(const CountScope.all());

            return ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: <Widget>[
                Text(
                  'Check the real shelf against the app. Tap Matches, change '
                  'the quantity or mark an item finished. Differences are '
                  'logged as adjustments.',
                  style: context.akText.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  settings.lastCountedLabel,
                  style: context.akText.bodySmall!.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                if (saved != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.lg),
                  _ResumeCard(
                    label: countScopeLabel(saved.scope, categoriesById),
                    answered: saved.outcomes.length,
                    onResume: () => unawaited(_resume(context, ref, saved)),
                    onDiscard: () => unawaited(
                      ref.read(countSessionProvider.notifier).discard(),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                const SectionHeader(title: 'Count by place'),
                for (final StorageLocation location in StorageLocation.values)
                  _ScopeTile(
                    icon: locationIcon(location),
                    title: location.label,
                    count: countOf(CountScope.inLocation(location)),
                    onTap: () => unawaited(
                      _begin(
                        context,
                        ref,
                        CountScope.inLocation(location),
                        saved,
                      ),
                    ),
                  ),
                const SizedBox(height: AppSpacing.md),
                const SectionHeader(title: 'Count by category'),
                for (final Category category in categories)
                  _ScopeTile(
                    icon: categoryIcon(category.iconKey),
                    title: category.name,
                    count: countOf(CountScope.inCategory(category.id)),
                    onTap: () => unawaited(
                      _begin(
                        context,
                        ref,
                        CountScope.inCategory(category.id),
                        saved,
                      ),
                    ),
                  ),
                const SizedBox(height: AppSpacing.md),
                const SectionHeader(title: 'Everything'),
                _ScopeTile(
                  icon: Icons.inventory_2_outlined,
                  title: 'Whole pantry',
                  count: everything,
                  onTap: () => unawaited(
                    _begin(context, ref, const CountScope.all(), saved),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _resume(
    BuildContext context,
    WidgetRef ref,
    CountSession saved,
  ) {
    ref.read(countSessionProvider.notifier).resume(saved);
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext routeContext) => const CountScreen(),
      ),
    );
  }

  Future<void> _begin(
    BuildContext context,
    WidgetRef ref,
    CountScope scope,
    CountSession? saved,
  ) async {
    final NavigatorState navigator = Navigator.of(context);
    final CountSessionNotifier session =
        ref.read(countSessionProvider.notifier);
    if (saved != null && saved.outcomes.isNotEmpty) {
      final bool? replace = await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) => AlertDialog(
          title: const Text('Start a new count?'),
          content: const Text(
            'The count in progress will be forgotten. Answers already given '
            'stay saved in the pantry.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Start new'),
            ),
          ],
        ),
      );
      if (replace != true) {
        return;
      }
    }
    session.start(scope);
    await navigator.push(
      MaterialPageRoute<void>(
        builder: (BuildContext routeContext) => const CountScreen(),
      ),
    );
  }
}

class _ResumeCard extends StatelessWidget {
  const _ResumeCard({
    required this.label,
    required this.answered,
    required this.onResume,
    required this.onDiscard,
  });

  final String label;
  final int answered;
  final VoidCallback onResume;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final AkshayaColors colors = context.akColors;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surfaceAlt,
        borderRadius: AppRadius.cardBorder,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Count in progress', style: context.akText.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '$label · $answered ${answered == 1 ? 'item' : 'items'} done',
            style: context.akText.bodyMedium!.copyWith(
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              Expanded(
                child: FilledButton(
                  onPressed: onResume,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(AppSizes.touchTarget),
                  ),
                  child: const Text('Resume'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              TextButton(onPressed: onDiscard, child: const Text('Discard')),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScopeTile extends StatelessWidget {
  const _ScopeTile({
    required this.icon,
    required this.title,
    required this.count,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      minTileHeight: AppSizes.touchTarget,
      enabled: count > 0,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(count == 0 ? 'Nothing in stock' : '$count items'),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: count > 0 ? onTap : null,
    );
  }
}
