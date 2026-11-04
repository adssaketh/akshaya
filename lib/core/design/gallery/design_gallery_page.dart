import 'package:flutter/material.dart';

import '../design.dart';

/// Developer showcase of every token and reusable widget. Not shipped in
/// release navigation; open it from a debug route to check the design on a
/// device in light and dark mode.
class DesignGalleryPage extends StatelessWidget {
  const DesignGalleryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.akColors;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
          children: <Widget>[
            AkshayaHeader(
              actions: <Widget>[
                IconButton(
                  tooltip: 'Notifications',
                  onPressed: () {},
                  icon: const Icon(Icons.notifications_none_rounded),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Good afternoon',
                    style: context.akText.bodySmall!.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  Text(
                    '4 items need attention',
                    style: context.akText.headlineSmall,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const Row(
                    children: <Widget>[
                      Expanded(
                        child: SummaryTile(
                          kind: StatusKind.expired,
                          count: 1,
                          label: 'Expired',
                        ),
                      ),
                      SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: SummaryTile(
                          kind: StatusKind.expiring,
                          count: 3,
                          label: 'Expiring soon',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const Row(
                    children: <Widget>[
                      Expanded(
                        child: SummaryTile(
                          kind: StatusKind.lowStock,
                          count: 2,
                          label: 'Low stock',
                        ),
                      ),
                      SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: SummaryTile(
                          kind: StatusKind.fresh,
                          count: 24,
                          label: 'Fresh',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  SectionHeader(
                    title: 'Use soon',
                    actionLabel: 'See all',
                    onAction: () {},
                  ),
                  const ItemCard(
                    name: 'Curd',
                    subtitle: 'Fridge · 1 kg left',
                    icon: Icons.water_drop_outlined,
                    status: StatusKind.expiring,
                    statusLabel: 'Tomorrow',
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const ItemCard(
                    name: 'Paneer',
                    subtitle: 'Fridge · 200 g left',
                    icon: Icons.egg_alt_outlined,
                    status: StatusKind.expired,
                    statusLabel: 'Expired 1d ago',
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const ItemCard(
                    name: 'Toor dal',
                    subtitle: 'Pantry · 300 g left',
                    icon: Icons.grain_rounded,
                    status: StatusKind.lowStock,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const ItemCard(
                    name: 'Basmati rice',
                    subtitle: 'Pantry · 4 kg left',
                    icon: Icons.grain_rounded,
                    status: StatusKind.fresh,
                    statusLabel: '7 months',
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const ItemCard(
                    name: 'Jaggery',
                    subtitle: 'Pantry · none left',
                    icon: Icons.grain_rounded,
                    status: StatusKind.outOfStock,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const SectionHeader(title: 'Controls'),
                  const TextField(
                    decoration: InputDecoration(
                      hintText: 'Search pantry',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.sm,
                    children: <Widget>[
                      FilterChip(
                        label: const Text('All'),
                        selected: true,
                        onSelected: (_) {},
                      ),
                      FilterChip(
                        label: const Text('Fridge'),
                        selected: false,
                        onSelected: (_) {},
                      ),
                      FilterChip(
                        label: const Text('Pantry'),
                        selected: false,
                        onSelected: (_) {},
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: <Widget>[
                      FilledButton(
                        onPressed: () {},
                        child: const Text('Add item'),
                      ),
                      OutlinedButton(
                        onPressed: () {},
                        child: const Text('Use'),
                      ),
                      TextButton(
                        onPressed: () {},
                        child: const Text('Cancel'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const SectionHeader(title: 'Type scale'),
                  Text('Headline medium 26', style: context.akText.headlineMedium),
                  Text('Headline small 22', style: context.akText.headlineSmall),
                  Text('Title large 20', style: context.akText.titleLarge),
                  Text('Title medium 16', style: context.akText.titleMedium),
                  Text('Title small 14', style: context.akText.titleSmall),
                  Text('Body large 16', style: context.akText.bodyLarge),
                  Text('Body medium 14', style: context.akText.bodyMedium),
                  Text('Body small 12', style: context.akText.bodySmall),
                  Text('Label large 14', style: context.akText.labelLarge),
                  const SizedBox(height: AppSpacing.lg),
                  const SizedBox(
                    height: 400,
                    child: EmptyState(
                      icon: Icons.inventory_2_outlined,
                      title: 'Start your pantry',
                      body: 'Add what you have and Akshaya tracks what runs low.',
                      actionLabel: 'Add item',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
