import 'package:akshaya/core/design/design.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/clock.dart';
import '../../../core/util/money.dart';
import '../../forecast/domain/consumption_forecast.dart';
import '../../forecast/presentation/providers.dart';
import '../../pantry/domain/entities.dart';
import '../../pantry/presentation/providers.dart';
import '../domain/insights.dart';
import '../domain/waste_cost.dart';
import 'providers.dart';

const List<String> _monthNames = <String>[
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// "November 2026".
String formatMonth(DateTime month) =>
    '${_monthNames[month.month - 1]} ${month.year}';

/// "Nov".
String shortMonth(DateTime month) => _monthNames[month.month - 1].substring(0, 3);

/// "4 Nov".
String shortDate(DateTime day) => '${day.day} ${shortMonth(day)}';

/// Spending, waste, running-out estimates and price history.
class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<ItemWithBatches>> items =
        ref.watch(itemsStreamProvider);
    final List<ConsumptionEntry> logs =
        ref.watch(allHistoryProvider).value ?? const <ConsumptionEntry>[];
    final List<Category> categories =
        ref.watch(categoriesProvider).value ?? const <Category>[];
    final DateTime month = ref.watch(insightsMonthProvider);
    final Map<String, ItemForecast> forecasts = ref.watch(forecastsProvider);
    final int warningDays = ref.watch(expiryWarningDaysProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Insights')),
      body: items.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace stackTrace) => const EmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Could not load insights',
          body: 'Please try again in a moment.',
        ),
        data: (List<ItemWithBatches> records) {
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: <Widget>[
              _MonthBar(month: month),
              const SizedBox(height: AppSpacing.md),
              Reveal(
                index: 1,
                child: _SpendCard(
                  records: records,
                  categories: categories,
                  month: month,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Reveal(
                index: 2,
                child: _WasteCard(
                  report: Insights.wasteReport(records, logs, month),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Reveal(
                index: 3,
                child: _SavedCard(
                  saved: WasteCost.moneySaved(
                    records: records,
                    logs: logs,
                    month: month,
                    warningDays: warningDays,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Reveal(
                index: 4,
                child: _RunOutCard(
                  forecasts: ConsumptionForecast.runningOut(forecasts),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Reveal(index: 5, child: _PriceCard(records: records)),
            ],
          );
        },
      ),
    );
  }
}

class _MonthBar extends ConsumerWidget {
  const _MonthBar({required this.month});

  final DateTime month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DateTime current = monthOf(ref.watch(todayProvider));
    return Row(
      children: <Widget>[
        IconButton(
          tooltip: 'Previous month',
          onPressed: ref.read(insightsMonthProvider.notifier).previous,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Expanded(
          child: Text(
            formatMonth(month),
            textAlign: TextAlign.center,
            style: context.akText.titleMedium,
          ),
        ),
        IconButton(
          tooltip: 'Next month',
          onPressed: month.isBefore(current)
              ? ref.read(insightsMonthProvider.notifier).next
              : null,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final AkshayaColors colors = context.akColors;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadius.cardBorder,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Semantics(
            header: true,
            child: Text(title, style: context.akText.titleMedium),
          ),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

class _Muted extends StatelessWidget {
  const _Muted(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: context.akText.bodyMedium!.copyWith(
        color: context.akColors.textSecondary,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Spending
// ---------------------------------------------------------------------------

class _SpendCard extends StatelessWidget {
  const _SpendCard({
    required this.records,
    required this.categories,
    required this.month,
  });

  final List<ItemWithBatches> records;
  final List<Category> categories;
  final DateTime month;

  @override
  Widget build(BuildContext context) {
    final double total = Insights.spendInMonth(records, month);
    final List<CategorySpend> byCategory =
        Insights.spendByCategory(records, categories, month);
    final List<MonthTotal> trend = Insights.monthlySpend(records, month);
    final AkshayaColors colors = context.akColors;
    return _Card(
      title: 'Spending',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(formatMoney(total), style: context.akText.headlineMedium),
          const SizedBox(height: AppSpacing.xs),
          _Muted(
            total == 0
                ? 'No prices recorded for ${formatMonth(month)}. Add the price '
                    'when you buy something and it will show up here.'
                : 'spent in ${formatMonth(month)}',
          ),
          const SizedBox(height: AppSpacing.lg),
          Semantics(
            label: 'Spending over the last six months: ${[
              for (final MonthTotal t in trend)
                '${shortMonth(t.month)} ${formatMoney(t.amount)}',
            ].join(', ')}',
            child: ExcludeSemantics(child: _TrendChart(trend: trend)),
          ),
          if (byCategory.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            for (final CategorySpend c in byCategory)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(child: Text(c.name)),
                        Text(
                          formatMoney(c.amount),
                          style: context.akText.titleSmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    ClipRRect(
                      borderRadius: AppRadius.controlBorder,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(
                          begin: 0,
                          end: total <= 0 ? 0 : (c.amount / total).clamp(0, 1),
                        ),
                        duration: AppMotion.of(context)
                            ? AppMotion.slow
                            : Duration.zero,
                        curve: AppMotion.enter,
                        builder: (BuildContext _, double value, Widget? __) =>
                            LinearProgressIndicator(
                          value: value,
                          minHeight: AppSpacing.sm,
                          color: colors.primary,
                          backgroundColor: colors.surfaceAlt,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.trend});

  final List<MonthTotal> trend;

  @override
  Widget build(BuildContext context) {
    final AkshayaColors colors = context.akColors;
    double maxY = 0;
    for (final MonthTotal t in trend) {
      if (t.amount > maxY) {
        maxY = t.amount;
      }
    }
    if (maxY <= 0) {
      maxY = 1;
    }
    return SizedBox(
      height: 140,
      child: BarChart(
        duration: AppMotion.of(context) ? AppMotion.slow : Duration.zero,
        curve: AppMotion.enter,
        BarChartData(
          maxY: maxY * 1.15,
          alignment: BarChartAlignment.spaceAround,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(enabled: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (double value, TitleMeta meta) {
                  final int i = value.toInt();
                  if (i < 0 || i >= trend.length) {
                    return const SizedBox.shrink();
                  }
                  return SideTitleWidget(
                    meta: meta,
                    child: Text(
                      shortMonth(trend[i].month),
                      style: context.akText.labelSmall,
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: <BarChartGroupData>[
            for (int i = 0; i < trend.length; i++)
              BarChartGroupData(
                x: i,
                barRods: <BarChartRodData>[
                  BarChartRodData(
                    toY: trend[i].amount,
                    width: 18,
                    color: i == trend.length - 1 ? colors.primary : colors.outline,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(AppSpacing.sm),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Waste
// ---------------------------------------------------------------------------

class _WasteCard extends StatelessWidget {
  const _WasteCard({required this.report});

  final WasteReport report;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = context.akText;
    if (report.isEmpty) {
      return _Card(
        title: 'Waste',
        child: _Muted(
          'Nothing thrown away or expired in ${formatMonth(report.month)}. '
          'Nice.',
        ),
      );
    }
    return _Card(
      title: 'Waste',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(formatMoney(report.value), style: text.headlineMedium),
          const SizedBox(height: AppSpacing.xs),
          _Muted(
            '${report.entries} ${report.entries == 1 ? 'time' : 'times'} in '
            '${formatMonth(report.month)}: ${report.itemCount} '
            '${report.itemCount == 1 ? 'item' : 'items'} '
            '(${report.wastedCount} wasted, ${report.expiredCount} expired). '
            'Value is estimated from the prices you entered.',
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Why', style: text.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          for (final ReasonWaste r in report.byReason)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                children: <Widget>[
                  Expanded(child: Text(r.reason.label)),
                  Text(
                    '${r.count}x · ${formatMoney(r.value)}',
                    style: text.bodyMedium,
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          Text('Most wasted', style: text.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          for (final WastedItem w in report.topItems)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                children: <Widget>[
                  Expanded(child: Text(w.name)),
                  Text(
                    '${w.count}x · ${formatMoney(w.value)}',
                    style: text.bodyMedium,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Money saved
// ---------------------------------------------------------------------------

class _SavedCard extends StatelessWidget {
  const _SavedCard({required this.saved});

  final MoneySaved saved;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = context.akText;
    if (saved.isEmpty) {
      return _Card(
        title: 'Money saved',
        child: _Muted(
          'Food you use while it is expiring soon counts here. Nothing yet in '
          '${formatMonth(saved.month)}.',
        ),
      );
    }
    return _Card(
      title: 'Money saved',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(formatMoney(saved.value), style: text.headlineMedium),
          const SizedBox(height: AppSpacing.xs),
          _Muted(
            '${saved.uses} ${saved.uses == 1 ? 'use' : 'uses'} of '
            '${saved.itemCount} ${saved.itemCount == 1 ? 'item' : 'items'} '
            'in ${formatMonth(saved.month)}, used in time after they were '
            'flagged as expiring. Value is estimated from the prices you '
            'entered.',
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Biggest rescues', style: text.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          for (final SavedItem item in saved.topItems)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                children: <Widget>[
                  Expanded(child: Text(item.name)),
                  Text(
                    '${item.uses}x · ${formatMoney(item.value)}',
                    style: text.bodyMedium,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Running out
// ---------------------------------------------------------------------------

class _RunOutCard extends StatelessWidget {
  const _RunOutCard({required this.forecasts});

  final List<ItemForecast> forecasts;

  @override
  Widget build(BuildContext context) {
    final List<ItemForecast> shown = forecasts.take(8).toList();
    return _Card(
      title: 'Running out',
      child: shown.isEmpty
          ? const _Muted(
              'Still learning. After an item has been used on at least '
              '${ConsumptionForecast.minDataPoints} different days over a '
              'week or more, Akshaya shows when it will run out.',
            )
          : Column(
              children: <Widget>[
                for (final ItemForecast e in shown)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(e.item.name),
                              Text(
                                '${e.item.defaultUnit.format(e.remaining)} left',
                                style: context.akText.bodySmall!.copyWith(
                                  color: context.akColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(e.label, style: context.akText.titleSmall),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Prices
// ---------------------------------------------------------------------------

class _PriceCard extends StatefulWidget {
  const _PriceCard({required this.records});

  final List<ItemWithBatches> records;

  @override
  State<_PriceCard> createState() => _PriceCardState();
}

class _PriceCardState extends State<_PriceCard> {
  String? _itemId;

  @override
  Widget build(BuildContext context) {
    final List<ItemWithBatches> candidates =
        Insights.itemsWithPrices(widget.records);
    if (candidates.isEmpty) {
      return const _Card(
        title: 'Price history',
        child: _Muted(
          'Buy an item with a price at least twice and its price history '
          'shows up here.',
        ),
      );
    }
    ItemWithBatches selected = candidates.first;
    for (final ItemWithBatches r in candidates) {
      if (r.item.id == _itemId) {
        selected = r;
      }
    }
    final List<PricePoint> points = Insights.priceHistory(selected);
    final String unit = selected.item.defaultUnit.symbol;
    final List<({String store, double average, int purchases})> stores =
        Insights.priceByStore(points);
    return _Card(
      title: 'Price history',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          DropdownButtonFormField<String>(
            initialValue: selected.item.id,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Item'),
            items: <DropdownMenuItem<String>>[
              for (final ItemWithBatches r in candidates)
                DropdownMenuItem<String>(
                  value: r.item.id,
                  child: Text(r.item.name, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (String? id) => setState(() => _itemId = id),
          ),
          const SizedBox(height: AppSpacing.md),
          _Muted('Price per $unit'),
          const SizedBox(height: AppSpacing.sm),
          Semantics(
            label: 'Price per $unit: ${[
              for (final PricePoint p in points)
                '${shortDate(p.date)} ${formatMoney(p.unitPrice)}',
            ].join(', ')}',
            child: ExcludeSemantics(child: _PriceChart(points: points)),
          ),
          if (stores.length > 1) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Text('By store', style: context.akText.titleSmall),
            const SizedBox(height: AppSpacing.xs),
            for (final ({String store, double average, int purchases}) s in stores)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Row(
                  children: <Widget>[
                    Expanded(child: Text(s.store)),
                    Text(
                      '${formatMoney(s.average)}/$unit · ${s.purchases}x',
                      style: context.akText.bodyMedium,
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _PriceChart extends StatelessWidget {
  const _PriceChart({required this.points});

  final List<PricePoint> points;

  @override
  Widget build(BuildContext context) {
    final AkshayaColors colors = context.akColors;
    double low = points.first.unitPrice;
    double high = low;
    for (final PricePoint p in points) {
      if (p.unitPrice < low) {
        low = p.unitPrice;
      }
      if (p.unitPrice > high) {
        high = p.unitPrice;
      }
    }
    final double pad = (high - low) == 0 ? (high == 0 ? 1 : high * 0.1) : (high - low) * 0.2;
    return SizedBox(
      height: 160,
      child: LineChart(
        duration: AppMotion.of(context) ? AppMotion.slow : Duration.zero,
        curve: AppMotion.enter,
        LineChartData(
          minY: (low - pad).clamp(0, double.infinity),
          maxY: high + pad,
          minX: 0,
          maxX: (points.length - 1).toDouble(),
          lineTouchData: const LineTouchData(enabled: false),
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            drawVerticalLine: false,
            getDrawingHorizontalLine: (double value) =>
                FlLine(color: colors.outline, strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                getTitlesWidget: (double value, TitleMeta meta) {
                  if (value == meta.min || value == meta.max) {
                    return const SizedBox.shrink();
                  }
                  return SideTitleWidget(
                    meta: meta,
                    child: Text(
                      formatMoney(value),
                      style: context.akText.labelSmall,
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: 1,
                getTitlesWidget: (double value, TitleMeta meta) {
                  final int i = value.toInt();
                  final bool edge = i == 0 || i == points.length - 1;
                  if (value != i.toDouble() || i < 0 || i >= points.length || !edge) {
                    return const SizedBox.shrink();
                  }
                  return SideTitleWidget(
                    meta: meta,
                    child: Text(
                      shortDate(points[i].date),
                      style: context.akText.labelSmall,
                    ),
                  );
                },
              ),
            ),
          ),
          lineBarsData: <LineChartBarData>[
            LineChartBarData(
              spots: <FlSpot>[
                for (int i = 0; i < points.length; i++)
                  FlSpot(i.toDouble(), points[i].unitPrice),
              ],
              barWidth: 3,
              color: colors.primary,
              dotData: const FlDotData(show: true),
            ),
          ],
        ),
      ),
    );
  }
}
