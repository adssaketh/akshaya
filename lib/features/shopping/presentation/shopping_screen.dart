import 'package:akshaya/core/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/clock.dart';
import '../../../core/ui/feedback.dart';
import '../../../core/util/date_only.dart';
import '../../pantry/domain/entities.dart';
import '../../pantry/presentation/pantry_icons.dart';
import '../../pantry/presentation/providers.dart';
import '../../commands/domain/command_models.dart';
import '../../commands/presentation/voice_mic_button.dart';
import '../../forecast/domain/repeat_learning.dart';
import '../../forecast/presentation/forecast_actions.dart';
import '../../forecast/presentation/providers.dart';
import '../../forecast/presentation/what_to_buy_screen.dart';
import '../domain/shopping_entities.dart';
import '../domain/shopping_enums.dart';
import '../domain/shopping_repository.dart';
import '../domain/shopping_suggestions.dart';
import '../domain/shopping_view.dart';
import '../../travel/presentation/trip_providers.dart';
import 'providers.dart';
import 'shopping_actions.dart';

/// The Shopping tab: named lists, entries grouped by category, check-off,
/// restock suggestions and "Done shopping".
class ShoppingScreen extends ConsumerWidget {
  const ShoppingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<ShoppingList>> lists =
        ref.watch(shoppingListsProvider);
    final ShoppingList? selected = ref.watch(selectedListProvider);
    final AsyncValue<ShoppingListView> view = ref.watch(shoppingViewProvider);
    final List<ShoppingEntry> basket =
        view.value?.basket ?? const <ShoppingEntry>[];

    return Scaffold(
      floatingActionButton: selected == null
          ? null
          : AkshayaFabCluster(
              // Every tab keeps its own FAB alive; unique tags avoid Hero
              // clashes when a screen is pushed.
              heroTag: 'shopping-add-fab',
              label: 'Add item',
              onPressed: () => openEntryForm(context, listId: selected.id),
            ),
      bottomNavigationBar: (selected == null || basket.isEmpty)
          ? null
          : Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: FilledButton.icon(
                onPressed: () => openCheckout(
                  context,
                  list: selected,
                  entries: basket,
                ),
                icon: const Icon(Icons.check_rounded),
                label: Text('Done shopping (${basket.length})'),
              ),
            ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            AkshayaHeader(
              actions: <Widget>[
                HeaderAction(
                  tooltip: 'What should I buy?',
                  icon: Icons.auto_graph_rounded,
                  onPressed: () => openWhatToBuy(context),
                ),
                const VoiceMicButton(commandContext: CommandContext.shopping),
              ],
            ),
            if (selected != null) _ListBar(selected: selected),
            Expanded(
              child: lists.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (Object error, StackTrace stackTrace) => EmptyState(
                  icon: Icons.error_outline_rounded,
                  title: 'Could not load your lists',
                  body: failureMessage(error),
                  actionLabel: 'Try again',
                  onAction: () => ref.invalidate(shoppingListsProvider),
                ),
                data: (List<ShoppingList> _) {
                  if (selected == null) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return view.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (Object error, StackTrace stackTrace) => EmptyState(
                      icon: Icons.error_outline_rounded,
                      title: 'Could not load this list',
                      body: failureMessage(error),
                      actionLabel: 'Try again',
                      onAction: () => ref.invalidate(shoppingEntriesProvider),
                    ),
                    data: (ShoppingListView data) =>
                        _ListBody(list: selected, view: data),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _ListAction { rename, share, delete }

/// List chips plus the menu for the selected list.
class _ListBar extends ConsumerWidget {
  const _ListBar({required this.selected});

  final ShoppingList selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<ShoppingList> lists =
        ref.watch(shoppingListsProvider).value ?? const <ShoppingList>[];
    final Map<String, int> counts = ref.watch(toBuyCountsProvider);

    return ChipRow(
      trailing: PopupMenuButton<_ListAction>(
          tooltip: 'List options',
          onSelected: (_ListAction action) async {
            switch (action) {
              case _ListAction.rename:
                await renameListFlow(context, ref, selected);
              case _ListAction.share:
                final ShoppingListView? view =
                    ref.read(shoppingViewProvider).value;
                if (view != null) {
                  await shareList(context, ref, list: selected, view: view);
                }
              case _ListAction.delete:
                await deleteListFlow(context, ref, selected);
            }
          },
          itemBuilder: (BuildContext _) => <PopupMenuEntry<_ListAction>>[
            const PopupMenuItem<_ListAction>(
              value: _ListAction.share,
              child: Text('Share as text'),
            ),
            const PopupMenuItem<_ListAction>(
              value: _ListAction.rename,
              child: Text('Rename list'),
            ),
            PopupMenuItem<_ListAction>(
              value: _ListAction.delete,
              enabled: lists.length > 1,
              child: const Text('Delete list'),
            ),
          ],
      ),
      children: <Widget>[
        for (final ShoppingList list in lists)
          ChoiceChip(
            label: Text(
              (counts[list.id] ?? 0) > 0
                  ? '${list.name} · ${counts[list.id]}'
                  : list.name,
            ),
            selected: list.id == selected.id,
            onSelected: (bool _) =>
                ref.read(selectedListIdProvider.notifier).select(list.id),
          ),
        ActionChip(
          avatar: const Icon(Icons.add_rounded, size: AppSizes.iconSm),
          label: const Text('New list'),
          onPressed: () => createListFlow(context, ref),
        ),
      ],
    );
  }
}

/// Suggestions, entries by category, the basket and repeating entries.
class _ListBody extends ConsumerWidget {
  const _ListBody({required this.list, required this.view});

  final ShoppingList list;
  final ShoppingListView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<ShoppingSuggestion> suggestions =
        ref.watch(suggestionsProvider);
    final List<ScheduleSuggestion> schedules = <ScheduleSuggestion>[
      for (final ScheduleSuggestion s in ref.watch(scheduleSuggestionsProvider))
        if (s.entry.listId == list.id) s,
    ];
    final DateTime today = ref.watch(todayProvider);

    int rowIndex = 0;
    final List<Widget> children = <Widget>[
      if (schedules.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: _ScheduleSuggestionsCard(suggestions: schedules),
        ),
      if (suggestions.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: _SuggestionsCard(listId: list.id, suggestions: suggestions),
        ),
      if (view.isEmpty)
        EmptyState(
          icon: Icons.shopping_basket_rounded,
          title: 'Nothing to buy',
          body: 'Add what you need. Akshaya also suggests items here when '
              'your pantry runs low. Use the Add item button below.',
        ),
      for (final ShoppingSection section in view.sections) ...<Widget>[
        SectionHeader(title: '${section.title} (${section.entries.length})'),
        for (final ShoppingEntry entry in section.entries)
          _EntryRow(entry: entry, today: today, index: rowIndex++),
      ],
      if (view.basket.isNotEmpty) ...<Widget>[
        SectionHeader(title: 'In basket (${view.basket.length})'),
        for (final ShoppingEntry entry in view.basket)
          _EntryRow(entry: entry, today: today, index: rowIndex++),
      ],
      if (view.upcoming.isNotEmpty)
        _UpcomingSection(entries: view.upcoming, today: today),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSizes.fab + AppSpacing.xxl,
      ),
      children: children,
    );
  }
}

class _EntryRow extends ConsumerWidget {
  const _EntryRow({
    required this.entry,
    required this.today,
    required this.index,
  });

  final ShoppingEntry entry;
  final DateTime today;

  /// Position in the list, for the staggered entrance.
  final int index;

  /// Repeating entries waiting for their next date (or held back by a trip)
  /// cannot be ticked.
  bool _waiting(DateTime? pausedUntil) =>
      !entry.isDueOn(today, pausedUntil: pausedUntil);

  String _subtitle(DateTime? pausedUntil) {
    final List<String> parts = <String>[entry.quantityLabel];
    final DateTime? due = entry.comesBackOn(today, pausedUntil: pausedUntil);
    if (_waiting(pausedUntil) && due != null) {
      parts.add('Back ${formatDateShort(due)}');
    }
    if (entry.recurrence.repeats) {
      parts.add(entry.repeatLabel);
    }
    final String? note = entry.notes;
    if (note != null && note.trim().isNotEmpty) {
      parts.add(note.trim());
    }
    return parts.join(' · ');
  }

  Widget? _trailing(BuildContext context) {
    final AkshayaColors colors = context.akColors;
    final List<Widget> parts = <Widget>[
      if (entry.priority == ShoppingPriority.high)
        Icon(
          Icons.priority_high_rounded,
          size: AppSizes.iconMd,
          color: colors.expired.foreground,
          semanticLabel: 'Urgent',
        ),
      if (entry.addedReason == AddedReason.lowStock)
        const StatusChip(kind: StatusKind.lowStock),
      if (entry.addedReason == AddedReason.expired)
        const StatusChip(kind: StatusKind.expired),
    ];
    if (parts.isEmpty) {
      return null;
    }
    return Row(mainAxisSize: MainAxisSize.min, children: parts);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AkshayaColors colors = context.akColors;
    final ShoppingRepository repo = ref.read(shoppingRepositoryProvider);
    final DateTime? pausedUntil = ref.watch(recurringResumeProvider);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Dismissible(
        key: ValueKey<String>('entry-${entry.id}'),
        direction: DismissDirection.endToStart,
        background: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.expired.background,
            borderRadius: AppRadius.cardBorder,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    Icons.delete_outline_rounded,
                    color: colors.expired.foreground,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Remove',
                    style: context.akText.labelLarge!.copyWith(
                      color: colors.expired.foreground,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        confirmDismiss: (DismissDirection direction) async {
          await deleteEntryWithUndo(context, ref, entry);
          // The row is never dismissed by the swipe itself: the list updates
          // from the database instead.
          return false;
        },
        child: ChecklistCard(
          revealIndex: index,
          title: entry.name,
          checked: entry.isChecked,
          subtitle: _subtitle(pausedUntil),
          trailing: _trailing(context),
          onChanged: _waiting(pausedUntil)
              ? null
              : (bool checked) async {
                  final ScaffoldMessengerState messenger =
                      ScaffoldMessenger.of(context);
                  try {
                    await repo.setChecked(entry.id, checked: checked);
                  } on Object catch (error) {
                    showMessage(messenger, failureMessage(error));
                  }
                },
          onTap: () => openEntryForm(
            context,
            listId: entry.listId,
            entry: entry,
          ),
        ),
      ),
    );
  }
}

/// Repeating entries that are not due yet, collapsed by default.
class _UpcomingSection extends StatelessWidget {
  const _UpcomingSection({required this.entries, required this.today});

  final List<ShoppingEntry> entries;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: EdgeInsets.zero,
      shape: const Border(),
      collapsedShape: const Border(),
      title: Text(
        'Repeats later (${entries.length})',
        style: context.akText.titleMedium,
      ),
      children: <Widget>[
        for (final ShoppingEntry entry in entries)
          _EntryRow(entry: entry, today: today, index: 99),
      ],
    );
  }
}

/// "Repeat schedules to update": repeating entries whose item is really bought
/// at a different interval. Nothing changes until the person taps.
class _ScheduleSuggestionsCard extends ConsumerWidget {
  const _ScheduleSuggestionsCard({required this.suggestions});

  final List<ScheduleSuggestion> suggestions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AkshayaColors colors = context.akColors;

    return Material(
      color: colors.surfaceAlt,
      borderRadius: AppRadius.cardBorder,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Semantics(
              header: true,
              child: Text(
                'Repeat schedules to update (${suggestions.length})',
                style: context.akText.titleMedium,
              ),
            ),
            Text(
              'Based on how often you actually buy these.',
              style: context.akText.bodySmall!.copyWith(
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final ScheduleSuggestion s in suggestions)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '${s.entry.name}: you buy it ${s.learnedLabel}, but it '
                      'repeats ${s.entry.repeatLabel.toLowerCase()}.',
                      style: context.akText.bodyMedium,
                    ),
                    Wrap(
                      spacing: AppSpacing.sm,
                      children: <Widget>[
                        TextButton(
                          onPressed: () =>
                              applyScheduleSuggestion(context, ref, s),
                          child: Text('Use ${s.learnedLabel}'),
                        ),
                        TextButton(
                          onPressed: () =>
                              dismissScheduleSuggestion(context, ref, s),
                          child: const Text('Keep mine'),
                        ),
                      ],
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

/// "Suggested for you": pantry items running low, out or expired. Nothing is
/// added until the person taps.
class _SuggestionsCard extends ConsumerStatefulWidget {
  const _SuggestionsCard({required this.listId, required this.suggestions});

  final String listId;
  final List<ShoppingSuggestion> suggestions;

  @override
  ConsumerState<_SuggestionsCard> createState() => _SuggestionsCardState();
}

class _SuggestionsCardState extends ConsumerState<_SuggestionsCard> {
  static const int _collapsedCount = 3;
  bool _showAll = false;

  StatusKind _kind(SuggestionReason reason) {
    switch (reason) {
      case SuggestionReason.outOfStock:
        return StatusKind.outOfStock;
      case SuggestionReason.expired:
        return StatusKind.expired;
      case SuggestionReason.lowStock:
        return StatusKind.lowStock;
    }
  }

  @override
  Widget build(BuildContext context) {
    final AkshayaColors colors = context.akColors;
    final Map<String, Category> categories = ref.watch(categoriesByIdProvider);
    final List<ShoppingSuggestion> all = widget.suggestions;
    final List<ShoppingSuggestion> shown =
        _showAll ? all : all.take(_collapsedCount).toList();
    final int hidden = all.length - shown.length;

    return Material(
      color: colors.surfaceAlt,
      borderRadius: AppRadius.cardBorder,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      'Suggested for you (${all.length})',
                      style: context.akText.titleMedium,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => addSuggestions(
                    context,
                    ref,
                    listId: widget.listId,
                    suggestions: all,
                  ),
                  child: const Text('Add all'),
                ),
              ],
            ),
            Text(
              'From your pantry. Nothing is added until you tap.',
              style: context.akText.bodySmall!.copyWith(
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final ShoppingSuggestion s in shown)
              Row(
                children: <Widget>[
                  Container(
                    width: AppSizes.avatar,
                    height: AppSizes.avatar,
                    decoration: BoxDecoration(
                      color: colors.surface,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      categoryIcon(categories[s.item.categoryId]?.iconKey),
                      size: AppSizes.iconMd,
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.sm,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            s.item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.akText.titleSmall,
                          ),
                          Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.xs,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: <Widget>[
                              StatusChip(kind: _kind(s.reason)),
                              Text(
                                '${s.detail} · buy ${s.quantityLabel}',
                                style: context.akText.bodySmall!.copyWith(
                                  color: colors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Add ${s.item.name} to the list',
                    icon: const Icon(Icons.add_circle_outline_rounded),
                    onPressed: () => addSuggestions(
                      context,
                      ref,
                      listId: widget.listId,
                      suggestions: <ShoppingSuggestion>[s],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Dismiss ${s.item.name}',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => ref
                        .read(dismissedSuggestionsProvider.notifier)
                        .dismiss(s.item.id),
                  ),
                ],
              ),
            if (hidden > 0)
              TextButton(
                onPressed: () => setState(() => _showAll = true),
                child: Text('Show $hidden more'),
              )
            else if (_showAll && all.length > _collapsedCount)
              TextButton(
                onPressed: () => setState(() => _showAll = false),
                child: const Text('Show fewer'),
              ),
          ],
        ),
      ),
    );
  }
}
