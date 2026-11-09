import 'dart:async';
import 'dart:io';

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
import 'pantry_view_settings.dart';
import 'pantry_view_sheet.dart';
import 'providers.dart';
import 'use_stock_sheet.dart';

/// The pantry: every item with its remaining quantity, nearest expiry and a
/// status chip. Search, group, sort and filter by status; the list can be
/// drawn as a list, grid, gallery or compact rows (View options button).
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
    final PantryViewSettings view = ref.watch(pantryViewProvider);

    return Scaffold(
      floatingActionButton: AkshayaFabCluster(
        heroTag: 'pantry-add-fab',
        label: 'Add item',
        onPressed: () => openAddItem(context),
        minis: <MiniFab>[
          MiniFab(
            heroTag: 'pantry-cooked-fab',
            tooltip: 'Add cooked or homemade food',
            icon: Icons.soup_kitchen_rounded,
            onPressed: () => showQuickAddMadeAtHome(context),
          ),
          MiniFab(
            heroTag: 'pantry-scan-fab',
            tooltip: 'Scan barcode',
            icon: Icons.qr_code_scanner_rounded,
            onPressed: () => openScanToAdd(context, ref),
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            AkshayaHeader(
              actions: <Widget>[
                HeaderAction(
                  tooltip: 'Count mode',
                  icon: Icons.fact_check_outlined,
                  onPressed: () => unawaited(openCountMode(context)),
                ),
                const VoiceMicButton(commandContext: CommandContext.pantry),
              ],
            ),
            ToolbarRow(
              child: AkshayaSearchField(
                controller: _search,
                hint: 'Search items, brands or other names',
                onChanged: notifier.setText,
              ),
            ),
            ToolbarRow(
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: AkshayaSegmented<PantryGroup>(
                      segments: <AkshayaSegment<PantryGroup>>[
                        for (final PantryGroup g in PantryGroup.values)
                          AkshayaSegment<PantryGroup>(
                            value: g,
                            label: g.label,
                          ),
                      ],
                      selected: query.group,
                      onChanged: notifier.setGroup,
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
                  IconButton(
                    tooltip: 'View options',
                    icon: const Icon(Icons.tune_rounded),
                    onPressed: () => unawaited(showPantryViewSheet(context)),
                  ),
                ],
              ),
            ),
            ChipRow(
              children: <Widget>[
                ChoiceChip(
                  label: const Text('All'),
                  selected: query.statusFilter == null,
                  onSelected: (bool _) => notifier.setStatus(null),
                ),
                for (final StatusKind kind in StatusKind.values)
                  ChoiceChip(
                    label: Text(kind.label),
                    selected: query.statusFilter == kind,
                    onSelected: (bool _) => notifier.setStatus(
                      query.statusFilter == kind ? null : kind,
                    ),
                  ),
                for (final ItemKind kind in const <ItemKind>[
                  ItemKind.cooked,
                  ItemKind.homemade,
                ])
                  ChoiceChip(
                    label: Text(kind.label),
                    selected: query.kindFilter == kind,
                    onSelected: (bool _) => notifier.setKind(
                      query.kindFilter == kind ? null : kind,
                    ),
                  ),
              ],
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
                          'and expiry dates. Use the Add item button below.',
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
                  return _PantryList(sections: list, view: view);
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
  const _PantryList({required this.sections, required this.view});

  final List<PantrySection> sections;
  final PantryViewSettings view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final EdgeInsets padding = EdgeInsets.fromLTRB(
      AppSpacing.lg,
      AppSpacing.sm,
      AppSpacing.lg,
      AppSizes.fab + AppSpacing.xxl + context.navClearance,
    );
    final Map<String, Category> categories = ref.watch(categoriesByIdProvider);

    if (view.mode == PantryViewMode.grid ||
        view.mode == PantryViewMode.gallery) {
      return _PantryTiles(
        sections: sections,
        view: view,
        categories: categories,
        padding: padding,
      );
    }

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
    final bool compact = view.mode == PantryViewMode.compact;

    // Zoom in List and Compact: the text in every row grows or shrinks.
    final MediaQueryData media = MediaQuery.of(context);
    final double base = media.textScaler.scale(1);

    return MediaQuery(
      data: media.copyWith(
        textScaler: TextScaler.linear(base * view.textFactor),
      ),
      child: ListView.builder(
        padding: padding,
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
              child:
                  SectionHeader(title: '${row.title} (${row.items.length})'),
            );
          }
          final ItemStock stock = row as ItemStock;
          return Padding(
            key: keys[index],
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: PantryRow(
              stock: stock,
              icon: categoryIcon(categories[stock.item.categoryId]?.iconKey),
              revealIndex: index,
              compact: compact,
            ),
          );
        },
      ),
    );
  }
}

/// Grid and Gallery: sections with a header, then tiles in rows.
class _PantryTiles extends StatelessWidget {
  const _PantryTiles({
    required this.sections,
    required this.view,
    required this.categories,
    required this.padding,
  });

  final List<PantrySection> sections;
  final PantryViewSettings view;
  final Map<String, Category> categories;
  final EdgeInsets padding;

  /// Tile height for each number of tiles per row (before text scaling).
  double _extent(BuildContext context) {
    final bool gallery = view.mode == PantryViewMode.gallery;
    final int cols = view.columns;
    final double base;
    if (gallery) {
      base = cols >= 3 ? 150 : (cols == 2 ? 200 : 260);
    } else {
      base = cols >= 4 ? 128 : (cols == 3 ? 138 : (cols == 2 ? 168 : 104));
    }
    final double text =
        MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6);
    return base * text;
  }

  @override
  Widget build(BuildContext context) {
    final bool gallery = view.mode == PantryViewMode.gallery;
    final int cols = view.columns;
    return CustomScrollView(
      slivers: <Widget>[
        for (final PantrySection s in sections) ...<Widget>[
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              padding.left,
              AppSpacing.sm,
              padding.right,
              0,
            ),
            sliver: SliverToBoxAdapter(
              child: SectionHeader(title: '${s.title} (${s.items.length})'),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              padding.left,
              AppSpacing.sm,
              padding.right,
              0,
            ),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                mainAxisSpacing: AppSpacing.sm,
                crossAxisSpacing: AppSpacing.sm,
                mainAxisExtent: _extent(context),
              ),
              delegate: SliverChildBuilderDelegate(
                (BuildContext context, int i) {
                  final ItemStock stock = s.items[i];
                  return _PantryTile(
                    key: ValueKey<String>('tile-${stock.item.id}'),
                    stock: stock,
                    icon: categoryIcon(
                      categories[stock.item.categoryId]?.iconKey,
                    ),
                    gallery: gallery,
                    columns: cols,
                  );
                },
                childCount: s.items.length,
              ),
            ),
          ),
        ],
        SliverToBoxAdapter(child: SizedBox(height: padding.bottom)),
      ],
    );
  }
}

/// One tile in Grid or Gallery view: tap for details, long-press for actions.
class _PantryTile extends ConsumerWidget {
  const _PantryTile({
    super.key,
    required this.stock,
    required this.icon,
    required this.gallery,
    required this.columns,
  });

  final ItemStock stock;
  final IconData icon;
  final bool gallery;
  final int columns;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AkshayaColors colors = context.akColors;
    final bool roomy = columns <= 2;
    final String? path = stock.item.imagePath;

    final Widget picture = gallery
        ? ColoredBox(
            color: colors.surfaceAlt,
            child: path == null
                ? Center(
                    child: Icon(icon, size: 40, color: colors.primary),
                  )
                : Image.file(
                    File(path),
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    cacheWidth: 480,
                    errorBuilder:
                        (BuildContext _, Object __, StackTrace? ___) => Center(
                      child: Icon(icon, size: 40, color: colors.primary),
                    ),
                  ),
          )
        : Container(
            width: AppSizes.avatar,
            height: AppSizes.avatar,
            decoration: BoxDecoration(
              color: colors.surfaceAlt,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: AppSizes.iconMd, color: colors.primary),
          );

    final Widget text = Padding(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment:
            gallery ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: <Widget>[
          Text(
            stock.item.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: gallery ? TextAlign.start : TextAlign.center,
            style: columns >= 3
                ? context.akText.labelLarge
                : context.akText.titleSmall,
          ),
          if (roomy)
            Text(
              stock.summaryLine,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: gallery ? TextAlign.start : TextAlign.center,
              style: context.akText.bodySmall!.copyWith(
                color: colors.textSecondary,
              ),
            ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: StatusChip(kind: stock.status, label: stock.statusLabel),
          ),
        ],
      ),
    );

    return Material(
      color: colors.surface,
      borderRadius: AppRadius.cardBorder,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openItemDetail(context, stock.item.id),
        onLongPress: () => showItemActionsSheet(context, ref, stock),
        child: gallery
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Expanded(child: picture),
                  text,
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  picture,
                  text,
                ],
              ),
      ),
    );
  }
}

/// One pantry item: tap for details, swipe to use or delete, long-press for
/// every action (including Move).
class PantryRow extends ConsumerWidget {
  const PantryRow({
    super.key,
    required this.stock,
    required this.icon,
    this.revealIndex,
    this.compact = false,
  });

  final ItemStock stock;
  final IconData icon;
  final int? revealIndex;

  /// One dense line per item (Compact view).
  final bool compact;

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
        child: compact
            ? _CompactCard(
                name: stock.item.name,
                subtitle: _subtitle(forecast),
                icon: icon,
                status: stock.status,
                statusLabel: stock.statusLabel,
                onTap: () => openItemDetail(context, stock.item.id),
              )
            : ItemCard(
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

/// A dense one-line row: small icon, name with the quantity beside it, chip.
class _CompactCard extends StatelessWidget {
  const _CompactCard({
    required this.name,
    required this.subtitle,
    required this.icon,
    required this.status,
    required this.statusLabel,
    required this.onTap,
  });

  final String name;
  final String subtitle;
  final IconData icon;
  final StatusKind status;
  final String? statusLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AkshayaColors colors = context.akColors;
    return Material(
      color: colors.surface,
      borderRadius: AppRadius.cardBorder,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: <Widget>[
              Icon(icon, size: AppSizes.iconMd, color: colors.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: <InlineSpan>[
                      TextSpan(text: name, style: context.akText.titleSmall),
                      TextSpan(
                        text: '  $subtitle',
                        style: context.akText.bodySmall!.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              StatusChip(kind: status, label: statusLabel),
            ],
          ),
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
