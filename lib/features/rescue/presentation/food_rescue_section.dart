import 'package:akshaya/core/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../pantry/domain/entities.dart';
import '../../pantry/presentation/pantry_actions.dart';
import '../../pantry/presentation/pantry_icons.dart';
import '../../pantry/presentation/providers.dart';
import '../domain/food_rescue.dart';
import 'providers.dart';
import 'rescue_actions.dart';

/// How many cards of one group the Home section shows before "See all".
const int kRescuePerGroup = 3;

/// "Expires today", "Expiring in the next 3 days", "Expiring tomorrow".
String rescueGroupTitle(RescueGroup group, int warningDays) {
  if (group == RescueGroup.soon) {
    return warningDays == 1
        ? 'Expiring tomorrow'
        : 'Expiring in the next $warningDays days';
  }
  return group.label;
}

/// The Home section: what to use, cook, freeze or write off today.
class FoodRescueSection extends ConsumerWidget {
  const FoodRescueSection({super.key, required this.onShowRecipes});

  /// Opens the Recipes tab ("Cook something").
  final VoidCallback onShowRecipes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<RescueEntry> entries = ref.watch(foodRescueProvider);
    final int warningDays = ref.watch(expiryWarningDaysProvider);
    final bool hasMore = RescueGroup.values.any(
      (RescueGroup g) =>
          FoodRescue.inGroup(entries, g).length > kRescuePerGroup,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SectionHeader(
          title: 'Food rescue',
          actionLabel: hasMore ? 'See all ${entries.length}' : null,
          onAction: hasMore
              ? () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (BuildContext _) =>
                          FoodRescueScreen(onShowRecipes: onShowRecipes),
                    ),
                  )
              : null,
        ),
        if (entries.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Text(
              'Nothing is expiring soon.',
              style: context.akText.bodyMedium!.copyWith(
                color: context.akColors.textSecondary,
              ),
            ),
          )
        else
          RescueGroups(
            entries: entries,
            warningDays: warningDays,
            perGroup: kRescuePerGroup,
            onShowRecipes: onShowRecipes,
          ),
      ],
    );
  }
}

/// Every Food rescue entry, not only the first few of each group.
class FoodRescueScreen extends ConsumerWidget {
  const FoodRescueScreen({super.key, required this.onShowRecipes});

  final VoidCallback onShowRecipes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<RescueEntry> entries = ref.watch(foodRescueProvider);
    final int warningDays = ref.watch(expiryWarningDaysProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Food rescue')),
      body: entries.isEmpty
          ? const EmptyState(
              icon: Icons.check_circle_outline_rounded,
              title: 'Nothing to rescue',
              body: 'Nothing is expiring soon, opened or left over.',
            )
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: <Widget>[
                RescueGroups(
                  entries: entries,
                  warningDays: warningDays,
                  onShowRecipes: () {
                    Navigator.of(context).pop();
                    onShowRecipes();
                  },
                ),
              ],
            ),
    );
  }
}

/// The groups of [entries], each with a title and its cards. With [perGroup],
/// only that many cards of each group are shown.
class RescueGroups extends StatelessWidget {
  const RescueGroups({
    super.key,
    required this.entries,
    required this.warningDays,
    required this.onShowRecipes,
    this.perGroup,
  });

  final List<RescueEntry> entries;
  final int warningDays;
  final int? perGroup;
  final VoidCallback onShowRecipes;

  @override
  Widget build(BuildContext context) {
    final List<Widget> children = <Widget>[];
    for (final RescueGroup group in RescueGroup.values) {
      final List<RescueEntry> inGroup = FoodRescue.inGroup(entries, group);
      if (inGroup.isEmpty) {
        continue;
      }
      children.add(
        Padding(
          padding: const EdgeInsets.only(
            top: AppSpacing.sm,
            bottom: AppSpacing.sm,
          ),
          child: Text(
            '${rescueGroupTitle(group, warningDays)} (${inGroup.length})',
            style: context.akText.labelLarge!.copyWith(
              color: context.akColors.textSecondary,
            ),
          ),
        ),
      );
      final int shown = perGroup == null || inGroup.length < perGroup!
          ? inGroup.length
          : perGroup!;
      for (final RescueEntry entry in inGroup.take(shown)) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: RescueCard(
              key: ValueKey<String>('rescue-${entry.batch.id}'),
              entry: entry,
              onShowRecipes: onShowRecipes,
            ),
          ),
        );
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}

/// One batch with its quick actions: Use, Cook something, Freeze and Mark
/// wasted. Expired food only offers Mark wasted.
class RescueCard extends ConsumerWidget {
  const RescueCard({
    super.key,
    required this.entry,
    required this.onShowRecipes,
  });

  final RescueEntry entry;
  final VoidCallback onShowRecipes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Map<String, Category> categories = ref.watch(categoriesByIdProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ItemCard(
          name: entry.item.name,
          subtitle: entry.subtitle,
          icon: categoryIcon(categories[entry.item.categoryId]?.iconKey),
          status: entry.status,
          statusLabel: entry.statusLabel,
          onTap: () => openItemDetail(context, entry.item.id),
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: <Widget>[
            if (!entry.isExpired)
              ActionChip(
                avatar: const Icon(
                  Icons.remove_circle_outline_rounded,
                  size: AppSizes.iconSm,
                ),
                label: const Text('Use'),
                onPressed: () => rescueUse(context, entry),
              ),
            if (!entry.isExpired)
              ActionChip(
                avatar: const Icon(
                  Icons.soup_kitchen_rounded,
                  size: AppSizes.iconSm,
                ),
                label: const Text('Cook something'),
                onPressed: onShowRecipes,
              ),
            if (entry.canFreeze)
              ActionChip(
                avatar: const Icon(
                  Icons.ac_unit_rounded,
                  size: AppSizes.iconSm,
                ),
                label: const Text('Freeze'),
                onPressed: () => rescueFreeze(context, ref, entry),
              ),
            ActionChip(
              avatar: const Icon(
                Icons.delete_outline_rounded,
                size: AppSizes.iconSm,
              ),
              label: const Text('Mark wasted'),
              onPressed: () => rescueWaste(context, ref, entry),
            ),
          ],
        ),
      ],
    );
  }
}
