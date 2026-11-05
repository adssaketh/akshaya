import 'dart:async';

import 'package:akshaya/core/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/feedback.dart';
import '../../commands/domain/command_models.dart';
import '../../commands/presentation/voice_mic_button.dart';
import '../../count/presentation/count_flow.dart';
import '../../forecast/domain/consumption_forecast.dart';
import '../../forecast/presentation/providers.dart';
import '../domain/entities.dart';
import '../domain/item_kind.dart';
import '../domain/pantry_query.dart';
import '../domain/stock_logic.dart';
import 'pantry_actions.dart';
import 'pantry_icons.dart';
import 'providers.dart';
import 'use_stock_sheet.dart';

/// The pantry: every item with its remaining quantity, nearest expiry and a
/// status chip. Search, group, sort and filter by status.
class PantryScreen extends ConsumerStatefulWidget {
  const PantryScreen({super.key});

  @override
  ConsumerState<PantryScreen> createState() => _PantryScreenState();
}

class _PantryScreenState extends ConsumerState<PantryScreen> {
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _clearFilters() {
    _search.clear();
    ref.read(pantryQueryProvider.notifier).clearFilters();
  }

  @override
  Widget build(BuildContext context) {
    final PantryQuery query = ref.watch(pantryQueryProvider);
    final PantryQueryNotifier notifier =
        ref.read(pantryQueryProvider.notifier);
    final AsyncValue<List<ItemStock>> stocks = ref.watch(pantryStocksProvider);
    final AsyncValue<List<PantrySection>> sections =
        ref.watch(pantrySectionsProvider);

    return Scaffold(
      floatingActionButton: PopIn(
          child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          FloatingActionButton.small(
            heroTag: 'pantry-cooked-fab',
            tooltip: 'Add cooked or homemade food',
            onPressed: () => showQuickAddMadeAtHome(context),
            child: const Icon(Icons.soup_kitchen_rounded),
          ),
          const SizedBox(height: AppSpacing.md),
          FloatingActionButton.small(
            heroTag: 'pantry-scan-fab',
            tooltip: 'Scan barcode',
            onPressed: () => openScanToAdd(context, ref),
            child: const Icon(Icons.qr_code_scanner_rounded),
          ),
          const SizedBox(height: AppSpacing.md),
          FloatingActionButton.extended(
            heroTag: 'pantry-add-fab',
            onPressed: () => openAddItem(context),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add item'),
          ),
        ],
      )),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            AkshayaHeader(
              actions: <Widget>[
                IconButton(
                  tooltip: 'Count mode',
                  constraints: const BoxConstraints(
                    minWidth: AppSizes.touchTarget,
                    minHeight: AppSizes.touchTarget,
                  ),
                  icon: const Icon(Icons.fact_check_outlined),
                  onPressed: () => unawaited(openCountMode(context)),
                ),
                const VoiceMicButton(commandContext: CommandContext.pantry),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: TextField(
                controller: _search,
                onChanged: notifier.setText,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search items, brands or other names',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: query.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            _search.clear();
                            notifier.setText('');
                          },
                        ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: SegmentedButton<PantryGroup>(
                      showSelectedIcon: false,
                      segments: <ButtonSegment<PantryGroup>>[
                        for (final PantryGroup g in PantryGroup.values)
                          ButtonSegment<PantryGroup>(
                            value: g,
                            label: Text(g.label),
                          ),
                      ],
                      selected: <PantryGroup>{query.group},
                      onSelectionChanged: (Set<PantryGroup> selection) =>
                          notifier.setGroup(selection.first),
                    ),
                  ),
                  PopupMenuButton<PantrySort>(
                    tooltip: 'Sort by',
                    icon: const Icon(Icons.sort_rounded),
                    initialValue: query.sort,
                    onSelected: notifier.setSort,
                    itemBuilder: (BuildContext _) =>
                        <PopupMenuEntry<PantrySort>>[
                      for (final PantrySort s in PantrySort.values)
                        PopupMenuItem<PantrySort>(
                          value: s,
                          child: Text('Sort by ${s.label.toLowerCase()}'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Row(
                children: <Widget>[
                  ChoiceChip(
                    label: const Text('All'),
                    selected: query.statusFilter == null,
                    onSelected: (bool _) => notifier.setStatus(null),
                  ),
                  for (final StatusKind kind in StatusKind.values) ...<Widget>[
                    const SizedBox(width: AppSpacing.sm),
                    ChoiceChip(
                      label: Text(kind.label),
                      selected: query.statusFilter == kind,
                      onSelected: (bool _) => notifier.setStatus(
                        query.statusFilter == kind ? null : kind,
                      ),
                    ),
                  ],
                  for (final ItemKind kind in const <ItemKind>[
                    ItemKind.cooked,
                    ItemKind.homemade,
                  ]) ...<Widget>[
                    const SizedBox(width: AppSpacing.sm),
                    ChoiceChip(
                      label: Text(kind.label),
                      selected: query.kindFilter == kind,
                      onSelected: (bool _) => notifier.setKind(
                        query.kindFilter == kind ? null : kind,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: stocks.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (Object error, StackTrace stackTrace) => EmptyState(
                  icon: Icons.error_outline_rounded,
                  title: 'Could not load your pantry',
                  body: failureMessage(error),
                  actionLabel: 'Try again',
                  onAction: () => ref.invalidate(itemsStreamProvider),
                ),
                data: (List<ItemStock> all) {
                  if (all.isEmpty) {
                    return EmptyState(
                      icon: Icons.inventory_2_rounded,
                      title: 'Your pantry is empty',
                      body: 'Add what you have at home to track quantities '
                          'and expiry dates.',
                      actionLabel: 'Add item',
                      onAction: () => openAddItem(context),
                    );
                  }
                  final List<PantrySection> list =
                      sections.value ?? const <PantrySection>[];
                  if (list.isEmpty) {
                    return EmptyState(
                      icon: Icons.search_rounded,
                      title: 'No matches',
                      body: 'Try a different search or clear the filters.',
                      actionLabel: 'Clear filters',
                      onAction: _clearFilters,
                    );
                  }
                  return _PantryList(sections: list);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PantryList extends ConsumerWidget {
  const _PantryList({required this.sections});

  final List<PantrySection> sections;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Map<String, Category> categories = ref.watch(categoriesByIdProvider);
    final List<Object> rows = <Object>[
      for (final PantrySection s in sections) ...<Object>[s, ...s.items],
    ];
    final List<Key> keys = <Key>[
      for (final Object row in rows)
        if (row is PantrySection)
          ValueKey<String>('section-${row.title}')
        else
          ValueKey<String>('row-${(row as ItemStock).item.id}'),
    ];
    final Map<Key, int> indexByKey = <Key, int>{
      for (final (int i, Key k) in keys.indexed) k: i,
    };

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSizes.fab + AppSpacing.xxl,
      ),
      itemCount: rows.length,
      // Rows keep their identity when the list is searched, filtered or
      // re-sorted, so surviving rows are reused (no rebuild, no replayed
      // entrance) and only genuinely new rows animate in.
      findChildIndexCallback: (Key key) => indexByKey[key],
      itemBuilder: (BuildContext context, int index) {
        final Object row = rows[index];
        if (row is PantrySection) {
          return Padding(
            key: keys[index],
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: SectionHeader(title: '${row.title} (${row.items.length})'),
          );
        }
        final ItemStock stock = row as ItemStock;
        return Padding(
          key: keys[index],
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: _PantryRow(
            stock: stock,
            icon: categoryIcon(categories[stock.item.categoryId]?.iconKey),
            revealIndex: index,
          ),
        );
      },
    );
  }
}

class _PantryRow extends ConsumerWidget {
  const _PantryRow({
    required this.stock,
    required this.icon,
    this.revealIndex,
  });

  final ItemStock stock;
  final IconData icon;
  final int? revealIndex;

  /// The usual line, plus "runs out in ~6 days" when the item is predicted to
  /// run out soon.
  String _subtitle(ItemForecast? forecast) {
    if (forecast == null || !forecast.isSoon) {
      return stock.summaryLine;
    }
    return '${stock.summaryLine} · ${forecast.label.toLowerCase()}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AkshayaColors colors = context.akColors;
    final ItemForecast? forecast = ref.watch(forecastProvider(stock.item.id));

    return Dismissible(
      key: ValueKey<String>('pantry-${stock.item.id}'),
      background: _SwipeBackground(
        alignment: Alignment.centerLeft,
        icon: Icons.remove_circle_outline_rounded,
        label: 'Use',
        background: colors.surfaceAlt,
        foreground: colors.primary,
      ),
      secondaryBackground: _SwipeBackground(
        alignment: Alignment.centerRight,
        icon: Icons.delete_outline_rounded,
        label: 'Delete',
        background: colors.expired.background,
        foreground: colors.expired.foreground,
      ),
      confirmDismiss: (DismissDirection direction) async {
        if (direction == DismissDirection.startToEnd) {
          await showUseStockSheet(context, stock);
        } else {
          await deleteItemWithUndo(context, ref, stock.item);
        }
        // The row is never dismissed by the swipe itself: the list updates
        // from the database instead.
        return false;
      },
      child: GestureDetector(
        onLongPress: () => showItemActionsSheet(context, ref, stock),
        child: ItemCard(
          name: stock.item.name,
          subtitle: _subtitle(forecast),
          icon: icon,
          status: stock.status,
          statusLabel: stock.statusLabel,
          onTap: () => openItemDetail(context, stock.item.id),
          revealIndex: revealIndex,
        ),
      ),
    );
  }
}

class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground({
    required this.alignment,
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
  });

  final Alignment alignment;
  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadius.cardBorder,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Align(
          alignment: alignment,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, color: foreground),
              const SizedBox(width: AppSpacing.sm),
              Text(
                label,
                style: context.akText.labelLarge!.copyWith(color: foreground),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
