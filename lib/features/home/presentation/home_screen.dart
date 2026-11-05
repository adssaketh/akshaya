import 'package:akshaya/core/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../commands/domain/command_models.dart';
import '../../commands/presentation/command_flow.dart';
import '../../commands/presentation/voice_mic_button.dart';
import '../../forecast/domain/what_to_buy.dart';
import '../../forecast/presentation/providers.dart';
import '../../forecast/presentation/what_to_buy_screen.dart';
import '../../insights/presentation/insights_screen.dart';
import '../../pantry/domain/stock_logic.dart';
import '../../pantry/presentation/pantry_actions.dart';
import '../../pantry/presentation/pantry_icons.dart';
import '../../pantry/presentation/providers.dart';
import '../../shopping/presentation/providers.dart';
import '../../pantry/domain/entities.dart';
import '../../rescue/presentation/food_rescue_section.dart';
import '../../travel/presentation/travel_screen.dart';
import '../../travel/presentation/trip_banner.dart';

/// How many "use these first" items the dashboard listed before Food rescue
/// replaced that list.
const int kUseFirstShown = 5;

/// The items to use first: expired and expiring stock, plus any cooked
/// leftovers still in the fridge, soonest first. The Home list is now the
/// Food rescue section (it works per batch and adds actions); these rules are
/// kept and tested for anything that needs a plain "use first" list.
List<ItemStock> useTheseFirst(List<ItemStock> stocks) {
  final List<ItemStock> urgent = <ItemStock>[
    for (final ItemStock s in stocks)
      if (s.status == StatusKind.expiring ||
          s.status == StatusKind.expired ||
          (s.item.isLeftover && s.inStock.isNotEmpty))
        s,
  ];
  urgent.sort((ItemStock a, ItemStock b) {
    final int byDays = (a.daysToExpiry ?? 0).compareTo(b.daysToExpiry ?? 0);
    return byDays != 0 ? byDays : a.item.name.compareTo(b.item.name);
  });
  return urgent;
}

/// The Home tab: what needs attention today and the quick actions.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({
    super.key,
    required this.onShowPantry,
    required this.onShowShopping,
    required this.onShowRecipes,
  });

  /// Opens the Pantry tab, filtered to [status] (or unfiltered when null).
  final void Function(StatusKind? status) onShowPantry;
  final VoidCallback onShowShopping;
  final VoidCallback onShowRecipes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<ItemStock>> stocks = ref.watch(pantryStocksProvider);
    final Map<String, int> toBuy = ref.watch(toBuyCountsProvider);
    final int shoppingCount =
        toBuy.values.fold<int>(0, (int sum, int n) => sum + n);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
        children: <Widget>[
          const AkshayaHeader(actions: <Widget>[VoiceMicButton()]),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: stocks.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (Object error, StackTrace stackTrace) => const EmptyState(
                icon: Icons.error_outline_rounded,
                title: 'Could not load your pantry',
                body: 'Please try again in a moment.',
              ),
              data: (List<ItemStock> list) => _Content(
                stocks: list,
                shoppingCount: shoppingCount,
                onShowPantry: onShowPantry,
                onShowShopping: onShowShopping,
                onShowRecipes: onShowRecipes,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Content extends ConsumerWidget {
  const _Content({
    required this.stocks,
    required this.shoppingCount,
    required this.onShowPantry,
    required this.onShowShopping,
    required this.onShowRecipes,
  });

  final List<ItemStock> stocks;
  final int shoppingCount;
  final void Function(StatusKind? status) onShowPantry;
  final VoidCallback onShowShopping;
  final VoidCallback onShowRecipes;

  int _count(StatusKind kind) {
    int n = 0;
    for (final ItemStock s in stocks) {
      if (s.status == kind) {
        n++;
      }
    }
    return n;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Map<String, Category> categories = ref.watch(categoriesByIdProvider);
    final List<BuyRecommendation> runningOut = ref
        .watch(buyRecommendationsProvider(WhatToBuy.defaultHorizonDays));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints box) {
            final double width = (box.maxWidth - AppSpacing.md) / 2;
            return Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: <Widget>[
                SizedBox(
                  width: width,
                  child: SummaryTile(
                    kind: StatusKind.expiring,
                    revealIndex: 0,
                    count: _count(StatusKind.expiring),
                    label: 'Expiring soon',
                    onTap: () => onShowPantry(StatusKind.expiring),
                  ),
                ),
                SizedBox(
                  width: width,
                  child: SummaryTile(
                    kind: StatusKind.expired,
                    revealIndex: 1,
                    count: _count(StatusKind.expired),
                    label: 'Expired',
                    onTap: () => onShowPantry(StatusKind.expired),
                  ),
                ),
                SizedBox(
                  width: width,
                  child: SummaryTile(
                    kind: StatusKind.lowStock,
                    revealIndex: 2,
                    count: _count(StatusKind.lowStock) +
                        _count(StatusKind.outOfStock),
                    label: 'Low or out of stock',
                    onTap: () => onShowPantry(StatusKind.lowStock),
                  ),
                ),
                SizedBox(
                  width: width,
                  child: SummaryTile(
                    kind: StatusKind.fresh,
                    revealIndex: 3,
                    count: shoppingCount,
                    label: 'On shopping lists',
                    icon: Icons.shopping_basket_rounded,
                    onTap: onShowShopping,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: SummaryTile(
                    kind: StatusKind.fresh,
                    revealIndex: 4,
                    count: stocks.length,
                    label: 'Items in pantry',
                    icon: Icons.inventory_2_rounded,
                    onTap: () => onShowPantry(null),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        _QuickActions(onShowShopping: onShowShopping),
        const SizedBox(height: AppSpacing.lg),
        TripBanner(onShowRecipes: onShowRecipes),
        if (stocks.isEmpty)
          EmptyState(
            icon: Icons.inventory_2_outlined,
            title: 'Your pantry is empty',
            body: 'Add what you have at home and Akshaya will tell you what '
                'to use first and what to buy.',
            actionLabel: 'Add item',
            onAction: () => openAddItem(context),
          )
        else ...<Widget>[
          FoodRescueSection(onShowRecipes: onShowRecipes),
          const SizedBox(height: AppSpacing.sm),
          FilledButton.icon(
            onPressed: onShowRecipes,
            icon: const Icon(Icons.soup_kitchen_rounded),
            label: const Text('Get recipe ideas'),
          ),
          if (runningOut.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            const SectionHeader(title: 'Running out soon'),
            for (final BuyRecommendation r in runningOut.take(3))
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: ItemCard(
                  revealIndex: null,
                  name: r.item.name,
                  subtitle: r.reason,
                  icon: categoryIcon(categories[r.item.categoryId]?.iconKey),
                  status: StatusKind.lowStock,
                  statusLabel: 'Buy ${r.quantityLabel}',
                  onTap: () => openItemDetail(context, r.item.id),
                ),
              ),
          ],
        ],
        const SizedBox(height: AppSpacing.lg),
        OutlinedButton.icon(
          onPressed: () => openWhatToBuy(context),
          icon: const Icon(Icons.auto_graph_rounded),
          label: const Text('What should I buy?'),
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          onPressed: () => openTravelMode(context, onShowRecipes: onShowRecipes),
          icon: const Icon(Icons.luggage_rounded),
          label: const Text('Travel mode'),
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (BuildContext _) => const InsightsScreen(),
            ),
          ),
          icon: const Icon(Icons.insights_rounded),
          label: const Text('Insights: spending, waste, prices'),
        ),
      ],
    );
  }
}

class _QuickActions extends ConsumerWidget {
  const _QuickActions({required this.onShowShopping});

  final VoidCallback onShowShopping;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _ActionButton(
            icon: Icons.mic_rounded,
            label: 'Voice',
            onTap: () => runCommandFlow(
              context,
              ref,
              commandContext: CommandContext.general,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _ActionButton(
            icon: Icons.qr_code_scanner_rounded,
            label: 'Scan',
            onTap: () => openScanToAdd(context, ref),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _ActionButton(
            icon: Icons.add_rounded,
            label: 'Add item',
            onTap: () => openAddItem(context),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _ActionButton(
            icon: Icons.shopping_basket_rounded,
            label: 'Shopping',
            onTap: onShowShopping,
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AkshayaColors colors = context.akColors;
    return Material(
      color: colors.surfaceAlt,
      borderRadius: AppRadius.cardBorder,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSizes.touchTarget + AppSpacing.lg),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.md,
              horizontal: AppSpacing.xs,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(icon, color: colors.primary),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.akText.labelMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
