import 'package:akshaya/core/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/clock.dart';
import '../../../core/util/date_only.dart';
import '../../../core/util/money.dart';
import '../../insights/presentation/providers.dart';
import '../../pantry/domain/consumption_type.dart';
import '../../pantry/domain/entities.dart';
import '../../pantry/domain/stock_logic.dart';
import '../../pantry/presentation/pantry_actions.dart';
import '../../pantry/presentation/providers.dart';
import '../../takeaway/domain/takeaway_models.dart';
import '../../takeaway/presentation/providers.dart';
import '../../takeaway/presentation/takeaway_screen.dart';

/// Opens the usage history of the whole app.
Future<void> openUsageHistory(BuildContext context) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (BuildContext _) => const UsageHistoryScreen(),
    ),
  );
}

/// What the filter chips show.
enum HistoryFilter {
  all('All'),
  used('Used'),
  wasted('Wasted'),
  givenAway('Given away'),
  takeaway('Takeaway');

  const HistoryFilter(this.label);

  final String label;

  bool allows(ConsumptionType type) {
    switch (this) {
      case HistoryFilter.all:
        return true;
      case HistoryFilter.used:
        return type == ConsumptionType.used ||
            type == ConsumptionType.cookedInRecipe;
      case HistoryFilter.wasted:
        return type == ConsumptionType.wasted ||
            type == ConsumptionType.expired;
      case HistoryFilter.givenAway:
        return type == ConsumptionType.givenAway;
      case HistoryFilter.takeaway:
        return false;
    }
  }

  bool get showsTakeaways =>
      this == HistoryFilter.all || this == HistoryFilter.takeaway;
}

/// One line of the history: a pantry entry or a takeaway.
final class HistoryRecord {
  const HistoryRecord._({
    required this.day,
    required this.sortKey,
    this.entry,
    this.meal,
  });

  factory HistoryRecord.fromEntry(ConsumptionEntry entry) {
    return HistoryRecord._(
      day: dateOnly(entry.date),
      sortKey: entry.date,
      entry: entry,
    );
  }

  factory HistoryRecord.fromMeal(TakeawayMeal meal) {
    return HistoryRecord._(
      day: dateOnly(meal.eatenOn),
      // Inside a day, takeaways sit by their meal.
      sortKey: DateTime(
        meal.eatenOn.year,
        meal.eatenOn.month,
        meal.eatenOn.day,
        8 + meal.meal.index * 4,
      ),
      meal: meal,
    );
  }

  final DateTime day;
  final DateTime sortKey;
  final ConsumptionEntry? entry;
  final TakeawayMeal? meal;
}

/// Every pantry entry and takeaway allowed by [filter], newest first.
List<HistoryRecord> buildHistory({
  required List<ConsumptionEntry> entries,
  required List<TakeawayMeal> meals,
  required HistoryFilter filter,
}) {
  final List<HistoryRecord> out = <HistoryRecord>[
    for (final ConsumptionEntry e in entries)
      if (filter.allows(e.type)) HistoryRecord.fromEntry(e),
    if (filter.showsTakeaways)
      for (final TakeawayMeal m in meals) HistoryRecord.fromMeal(m),
  ];
  out.sort(
    (HistoryRecord a, HistoryRecord b) => b.sortKey.compareTo(a.sortKey),
  );
  return out;
}

IconData _iconFor(ConsumptionType type) {
  switch (type) {
    case ConsumptionType.used:
      return Icons.restaurant_rounded;
    case ConsumptionType.cookedInRecipe:
      return Icons.soup_kitchen_rounded;
    case ConsumptionType.wasted:
      return Icons.delete_outline_rounded;
    case ConsumptionType.expired:
      return Icons.event_busy_rounded;
    case ConsumptionType.givenAway:
      return Icons.volunteer_activism_rounded;
    case ConsumptionType.adjustment:
      return Icons.tune_rounded;
  }
}

String _dayLabel(DateTime day, DateTime today) {
  final int ago = daysBetween(day, today);
  if (ago == 0) {
    return 'Today';
  }
  if (ago == 1) {
    return 'Yesterday';
  }
  return formatDate(day);
}

/// Everything that left the pantry (used, cooked, wasted, expired, given
/// away) and every takeaway, by day.
class UsageHistoryScreen extends ConsumerStatefulWidget {
  const UsageHistoryScreen({super.key});

  @override
  ConsumerState<UsageHistoryScreen> createState() => _UsageHistoryScreenState();
}

class _UsageHistoryScreenState extends ConsumerState<UsageHistoryScreen> {
  HistoryFilter _filter = HistoryFilter.all;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<ConsumptionEntry>> history = ref.watch(
      allHistoryProvider,
    );
    final List<TakeawayMeal> meals =
        ref.watch(takeawaysProvider).value ?? const <TakeawayMeal>[];
    final List<ItemStock> stocks =
        ref.watch(pantryStocksProvider).value ?? const <ItemStock>[];
    final Map<String, String> names = <String, String>{
      for (final ItemStock s in stocks) s.item.id: s.item.name,
    };
    final DateTime today = dateOnly(ref.watch(todayProvider));

    return Scaffold(
      appBar: AppBar(title: const Text('Usage history')),
      body: history.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object _, StackTrace __) => const EmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Could not load the history',
          body: 'Please try again in a moment.',
        ),
        data: (List<ConsumptionEntry> entries) {
          final List<HistoryRecord> records = buildHistory(
            entries: entries,
            meals: meals,
            filter: _filter,
          );
          return Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  AppSpacing.xs,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    children: <Widget>[
                      for (final HistoryFilter f in HistoryFilter.values)
                        ChoiceChip(
                          label: Text(f.label),
                          selected: f == _filter,
                          onSelected: (bool _) => setState(() => _filter = f),
                        ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: records.isEmpty
                    ? const EmptyState(
                        icon: Icons.history_rounded,
                        title: 'Nothing here yet',
                        body:
                            'Items you use, waste or give away, and takeaway '
                            'food you add, show up here.',
                      )
                    : _HistoryList(
                        records: records,
                        names: names,
                        today: today,
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HistoryList extends StatelessWidget {
  const _HistoryList({
    required this.records,
    required this.names,
    required this.today,
  });

  final List<HistoryRecord> records;
  final Map<String, String> names;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final AkshayaColors colors = context.akColors;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xs,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      itemCount: records.length,
      itemBuilder: (BuildContext context, int i) {
        final HistoryRecord record = records[i];
        final bool newDay = i == 0 || records[i - 1].day != record.day;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (newDay) SectionHeader(title: _dayLabel(record.day, today)),
            _HistoryRow(record: record, names: names, colors: colors),
          ],
        );
      },
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    required this.record,
    required this.names,
    required this.colors,
  });

  final HistoryRecord record;
  final Map<String, String> names;
  final AkshayaColors colors;

  @override
  Widget build(BuildContext context) {
    final ConsumptionEntry? entry = record.entry;
    final TakeawayMeal? meal = record.meal;
    final IconData icon;
    final String title;
    final String subtitle;
    final VoidCallback onTap;
    if (entry != null) {
      icon = _iconFor(entry.type);
      title = names[entry.itemId] ?? 'Removed item';
      subtitle = '${entry.type.label} ${entry.amountLabel}';
      onTap = names.containsKey(entry.itemId)
          ? () => openItemDetail(context, entry.itemId)
          : () {};
    } else {
      final TakeawayMeal m = meal!;
      icon = Icons.takeout_dining_rounded;
      title = m.name;
      subtitle = <String>[
        'Takeaway',
        m.meal.label,
        m.portionsLabel,
        if (m.price != null) formatMoney(m.price!),
      ].join(' · ');
      onTap = () => showTakeawayDetail(context, m.id);
    }
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: colors.primary),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle),
      onTap: onTap,
    );
  }
}
