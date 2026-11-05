import 'package:akshaya/core/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/clock.dart';
import '../../../core/ui/feedback.dart';
import '../../../core/util/date_only.dart';
import '../../../core/util/money.dart';
import '../domain/consumption_type.dart';
import '../domain/entities.dart';
import '../domain/item_kind.dart';
import '../domain/pantry_repository.dart';
import '../domain/stock_logic.dart';
import 'pantry_actions.dart';
import 'pantry_icons.dart';
import 'providers.dart';
import 'use_stock_sheet.dart';

/// One item: summary, every batch, usage history and price history.
class ItemDetailScreen extends ConsumerWidget {
  const ItemDetailScreen({super.key, required this.itemId});

  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<ItemStock?> async = ref.watch(itemStockProvider(itemId));

    return async.when(
      loading: () => Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (Object error, StackTrace stackTrace) => Scaffold(
        appBar: AppBar(),
        body: EmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Could not load this item',
          body: failureMessage(error),
          actionLabel: 'Try again',
          onAction: () => ref.invalidate(itemsStreamProvider),
        ),
      ),
      data: (ItemStock? stock) {
        if (stock == null) {
          return Scaffold(
            appBar: AppBar(),
            body: EmptyState(
              icon: Icons.inventory_2_rounded,
              title: 'Item not found',
              body: 'It may have been deleted.',
              actionLabel: 'Go back',
              onAction: () => Navigator.of(context).pop(),
            ),
          );
        }
        return _ItemDetailBody(stock: stock);
      },
    );
  }
}

class _ItemDetailBody extends ConsumerWidget {
  const _ItemDetailBody({required this.stock});

  final ItemStock stock;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Item item = stock.item;
    final AkshayaColors colors = context.akColors;
    final Map<String, Category> categories =
        ref.watch(categoriesByIdProvider);
    final Category? category = categories[item.categoryId];
    final DateTime today = ref.watch(todayProvider);
    final int warningDays = ref.watch(expiryWarningDaysProvider);
    final DateTime? nearest = stock.nearestExpiry;

    final List<StockBatch> batches = List<StockBatch>.of(stock.batches)
      ..sort((StockBatch a, StockBatch b) {
        final bool aEmpty = stock.inStock.every((StockBatch s) => s.id != a.id);
        final bool bEmpty = stock.inStock.every((StockBatch s) => s.id != b.id);
        if (aEmpty != bEmpty) {
          return aEmpty ? 1 : -1;
        }
        return b.purchaseDate.compareTo(a.purchaseDate);
      });

    final List<StockBatch> priced = batches
        .where((StockBatch b) => b.price != null)
        .toList()
      ..sort(
        (StockBatch a, StockBatch b) => b.purchaseDate.compareTo(a.purchaseDate),
      );

    final String subtitle = <String>[
      if (item.kind.isMadeAtHome) item.kind.label,
      if (category != null) category.name,
      if (item.brand != null) item.brand!,
    ].join(' · ');

    return Scaffold(
      appBar: AppBar(
        title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: <Widget>[
          IconButton(
            tooltip: 'Edit item',
            icon: const Icon(Icons.edit_rounded),
            onPressed: () => openEditItem(context, item),
          ),
          IconButton(
            tooltip: 'Delete item',
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () async {
              final bool deleted = await deleteItemWithUndo(context, ref, item);
              if (deleted && context.mounted) {
                Navigator.of(context).pop();
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        children: <Widget>[
          Row(
            children: <Widget>[
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.surfaceAlt,
                  shape: BoxShape.circle,
                ),
                child: SizedBox(
                  width: AppSizes.avatar,
                  height: AppSizes.avatar,
                  child: Icon(
                    categoryIcon(category?.iconKey),
                    size: AppSizes.iconMd,
                    color: colors.primary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  subtitle.isEmpty ? 'Uncategorised' : subtitle,
                  style: context.akText.bodyMedium!.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ),
              StatusChip(kind: stock.status, label: stock.statusLabel),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(stock.remainingLabel, style: context.akText.headlineMedium),
          Text(
            'left in stock',
            style: context.akText.bodySmall!.copyWith(
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (nearest != null)
            Text(
              'Nearest expiry: ${formatDate(nearest)}',
              style: context.akText.bodyMedium,
            ),
          if (item.lowStockThreshold != null)
            Text(
              'Low-stock level: ${item.defaultUnit.format(item.lowStockThreshold!)}',
              style: context.akText.bodyMedium,
            ),
          if (item.aliases.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                'Also called: ${item.aliases.join(', ')}',
                style: context.akText.bodyMedium!.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ),
          if (item.notes != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(item.notes!, style: context.akText.bodyMedium),
            ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: <Widget>[
              Expanded(
                child: FilledButton.icon(
                  onPressed: stock.inStock.isEmpty
                      ? null
                      : () => showUseStockSheet(context, stock),
                  icon: const Icon(Icons.remove_circle_outline_rounded),
                  label: const Text('Use'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => openAddItem(context, existing: item),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add stock'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          const SectionHeader(title: 'Batches'),
          if (batches.isEmpty)
            Text(
              'No stock yet. Tap Add stock to record a purchase.',
              style: context.akText.bodyMedium!.copyWith(
                color: colors.textSecondary,
              ),
            )
          else
            for (final StockBatch batch in batches)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _BatchCard(
                  item: item,
                  batch: batch,
                  today: today,
                  warningDays: warningDays,
                ),
              ),
          const SizedBox(height: AppSpacing.md),
          const SectionHeader(title: 'Usage history'),
          _UsageHistory(itemId: item.id),
          const SizedBox(height: AppSpacing.md),
          const SectionHeader(title: 'Price history'),
          if (priced.isEmpty)
            Text(
              'No prices recorded yet.',
              style: context.akText.bodyMedium!.copyWith(
                color: colors.textSecondary,
              ),
            )
          else
            for (final StockBatch batch in priced)
              _PriceRow(item: item, batch: batch),
        ],
      ),
    );
  }
}

enum _BatchAction { edit, wasted, expired, delete }

class _BatchCard extends ConsumerWidget {
  const _BatchCard({
    required this.item,
    required this.batch,
    required this.today,
    required this.warningDays,
  });

  final Item item;
  final StockBatch batch;
  final DateTime today;
  final int warningDays;

  Future<void> _onAction(
    BuildContext context,
    WidgetRef ref,
    _BatchAction action,
  ) async {
    final PantryRepository repo = ref.read(pantryRepositoryProvider);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    try {
      switch (action) {
        case _BatchAction.edit:
          openEditBatch(context, item, batch);
        case _BatchAction.wasted:
        case _BatchAction.expired:
          final ConsumptionType type = action == _BatchAction.wasted
              ? ConsumptionType.wasted
              : ConsumptionType.expired;
          final UseResult result = await repo.discardBatch(
            batchId: batch.id,
            type: type,
          );
          showUndoSnackBar(
            messenger,
            message:
                '${type.label} ${result.unit.format(result.quantity)} of ${item.name}',
            onUndo: () => repo.undoUse(result),
          );
        case _BatchAction.delete:
          await repo.deleteBatch(batch.id);
          showUndoSnackBar(
            messenger,
            message: 'Deleted batch of ${item.name}',
            onUndo: () => repo.undoDeleteBatch(batch.id),
          );
      }
    } on Object catch (error) {
      showMessage(messenger, failureMessage(error));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AkshayaColors colors = context.akColors;
    final ({StatusKind kind, String? label}) status = StockLogic.batchStatus(
      batch,
      today: today,
      warningDays: warningDays,
    );
    final DateTime? expiry = batch.effectiveExpiry;
    final bool hasStock = batch.quantityRemaining > 0;

    final String madeVerb = item.kind == ItemKind.cooked ? 'Cooked' : 'Made';
    final List<String> lines = <String>[
      if (item.kind.isMadeAtHome)
        '$madeVerb ${formatDate(batch.purchaseDate)}'
      else
        'Bought ${formatDate(batch.purchaseDate)}'
            '${batch.store != null ? ' · ${batch.store}' : ''}',
      'Kept in ${batch.storageLocation.label}'
          '${batch.containerLabel != null ? ' · ${batch.containerLabel}' : ''}',
      if (batch.checkBy != null) 'Check by ${formatDate(batch.checkBy!)}',
      if (expiry != null) 'Expires ${formatDate(expiry)}',
      if (batch.openedDate != null)
        'Opened ${formatDate(batch.openedDate!)}'
            '${batch.useWithinDaysAfterOpening != null ? ', use within ${batch.useWithinDaysAfterOpening} days' : ''}',
      if (batch.price != null) 'Paid ${formatMoney(batch.price!)}',
    ];

    return Material(
      color: colors.surface,
      borderRadius: AppRadius.cardBorder,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '${batch.unit.format(batch.quantityRemaining)} left of '
                    '${batch.unit.format(batch.quantityBought)}',
                    style: context.akText.titleSmall,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  for (final String line in lines)
                    Text(
                      line,
                      style: context.akText.bodySmall!.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  const SizedBox(height: AppSpacing.sm),
                  StatusChip(kind: status.kind, label: status.label),
                ],
              ),
            ),
            PopupMenuButton<_BatchAction>(
              tooltip: 'Batch actions',
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (_BatchAction action) =>
                  _onAction(context, ref, action),
              itemBuilder: (BuildContext _) => <PopupMenuEntry<_BatchAction>>[
                const PopupMenuItem<_BatchAction>(
                  value: _BatchAction.edit,
                  child: Text('Edit'),
                ),
                if (hasStock)
                  const PopupMenuItem<_BatchAction>(
                    value: _BatchAction.wasted,
                    child: Text('Mark as wasted'),
                  ),
                if (hasStock)
                  const PopupMenuItem<_BatchAction>(
                    value: _BatchAction.expired,
                    child: Text('Mark as expired'),
                  ),
                const PopupMenuItem<_BatchAction>(
                  value: _BatchAction.delete,
                  child: Text('Delete'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _UsageHistory extends ConsumerWidget {
  const _UsageHistory({required this.itemId});

  final String itemId;

  static const int _maxRows = 20;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AkshayaColors colors = context.akColors;
    final AsyncValue<List<ConsumptionEntry>> history =
        ref.watch(historyProvider(itemId));

    return history.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (Object error, StackTrace stackTrace) => Text(
        failureMessage(error),
        style: context.akText.bodyMedium,
      ),
      data: (List<ConsumptionEntry> entries) {
        if (entries.isEmpty) {
          return Text(
            'Nothing used yet.',
            style: context.akText.bodyMedium!.copyWith(
              color: colors.textSecondary,
            ),
          );
        }
        return Column(
          children: <Widget>[
            for (final ConsumptionEntry e in entries.take(_maxRows))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        '${e.type.label} ${e.unit.format(e.quantityUsed)}',
                        style: context.akText.bodyMedium,
                      ),
                    ),
                    Text(
                      formatDate(e.date),
                      style: context.akText.bodySmall!.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({required this.item, required this.batch});

  final Item item;
  final StockBatch batch;

  @override
  Widget build(BuildContext context) {
    final AkshayaColors colors = context.akColors;
    final double? total = batch.price;
    final double? perUnit = batch.unitPrice(item.defaultUnit);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              '${formatDate(batch.purchaseDate)}'
              '${batch.store != null ? ' · ${batch.store}' : ''}',
              style: context.akText.bodyMedium,
            ),
          ),
          Text(
            total == null
                ? ''
                : '${formatMoney(total)}'
                    '${perUnit != null ? ' (${formatMoney(perUnit)}/${item.defaultUnit.symbol})' : ''}',
            style: context.akText.bodySmall!.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
