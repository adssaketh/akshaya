import 'package:akshaya/core/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/clock.dart';
import '../../pantry/domain/entities.dart';
import '../../pantry/domain/stock_logic.dart';
import '../../insights/presentation/providers.dart';
import '../../recipes/domain/recipe_models.dart';
import '../../recipes/presentation/providers.dart';
import '../domain/report_builder.dart';
import '../domain/report_models.dart';
import 'providers.dart';

/// "1850" -> "1,850".
String groupThousands(int value) {
  return value.toString().replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'),
        (Match _) => ',',
      );
}

/// The Home report card: what was used today, this week or this month, a rough
/// energy figure, whether the plate looked balanced, and small changes to try.
class ReportCard extends ConsumerWidget {
  const ReportCard({super.key, required this.stocks});

  final List<ItemStock> stocks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AkshayaColors colors = context.akColors;
    final TextTheme text = context.akText;
    final ReportPeriod period = ref.watch(reportPeriodProvider);
    final RecipePreferences prefs = ref.watch(recipePreferencesProvider);
    final DateTime today = ref.watch(todayProvider);
    final AsyncValue<List<ConsumptionEntry>> history =
        ref.watch(allHistoryProvider);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadius.cardBorder,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(Icons.restaurant_rounded, color: colors.primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Semantics(
                        header: true,
                        child: Text('Eating report', style: text.titleMedium),
                      ),
                      Text(
                        'for ${prefs.people} '
                        '${prefs.people == 1 ? 'person' : 'people'}',
                        style: text.bodySmall!
                            .copyWith(color: colors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            // Chips, not a segmented button: they wrap onto a second line on a
            // small screen or with large text instead of overflowing.
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: <Widget>[
                for (final ReportPeriod p in ReportPeriod.values)
                  ChoiceChip(
                    label: Text(p.label),
                    selected: p == period,
                    onSelected: (bool _) =>
                        ref.read(reportPeriodProvider.notifier).select(p),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            history.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (Object _, StackTrace __) => Text(
                'The report could not be worked out. Please try again later.',
                style: text.bodyMedium,
              ),
              data: (List<ConsumptionEntry> entries) {
                final ConsumptionReport report = buildConsumptionReport(
                  period: period,
                  today: today,
                  history: entries,
                  itemsById: <String, Item>{
                    for (final ItemStock s in stocks) s.item.id: s.item,
                  },
                  people: prefs.people,
                  vegetarian: prefs.diet == RecipeDiet.veg,
                  stocks: stocks,
                );
                return ReportBody(report: report);
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// The inside of the card, for one finished [ConsumptionReport].
class ReportBody extends StatelessWidget {
  const ReportBody({super.key, required this.report});

  final ConsumptionReport report;

  static const int _shownLines = 5;

  @override
  Widget build(BuildContext context) {
    final AkshayaColors colors = context.akColors;
    final TextTheme text = context.akText;
    final TextStyle muted =
        text.bodySmall!.copyWith(color: colors.textSecondary);
    final bool isToday = report.period == ReportPeriod.today;

    if (report.isEmpty) {
      return Text(
        isToday
            ? 'Nothing used today yet. When you use an item or cook a recipe '
                'it shows up here.'
            : 'Nothing used in the last ${report.period.days} days. When you '
                'use an item or cook a recipe it shows up here.',
        style: text.bodyMedium,
      );
    }

    final double? perPerson = report.kcalPerPersonPerDay;
    final List<ConsumedLine> shown =
        report.lines.take(_shownLines).toList(growable: false);
    final int more = report.lines.length - shown.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (perPerson != null) ...<Widget>[
          Text(
            '≈ ${groupThousands((perPerson / 10).round() * 10)} kcal',
            style: text.headlineSmall,
          ),
          Text(
            isToday
                ? 'per person today (estimate)'
                : 'per person a day, on average (estimate)',
            style: muted,
          ),
        ] else
          Text(
            'Calories could not be worked out for these items.',
            style: text.bodyMedium,
          ),
        if (!isToday)
          Text(
            '${report.loggedDays} of ${report.period.days} days had food '
            'marked as used.',
            style: muted,
          ),
        const SizedBox(height: AppSpacing.md),
        _VerdictRow(report: report),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            for (final PlateGroup g in PlateGroup.values)
              _GroupChip(
                group: g,
                present: (report.coverage[g] ?? 0) >= 0.5,
                judged: report.verdict != BalanceVerdict.notEnoughData,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Text('What was used', style: text.labelMedium),
        const SizedBox(height: AppSpacing.xs),
        for (final ConsumedLine line in shown)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    '${line.name} · ${line.quantityLabel}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodyMedium,
                  ),
                ),
                Text(
                  line.kcal == null
                      ? 'not counted'
                      : '${line.estimatedFromGroup ? '~' : ''}'
                          '${groupThousands(line.kcal!.round())} kcal',
                  style: muted,
                ),
              ],
            ),
          ),
        if (more > 0) Text('and $more more', style: muted),
        if (report.tips.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          Text('Try this', style: text.labelMedium),
          const SizedBox(height: AppSpacing.xs),
          for (final String tip in report.tips)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Text('• $tip', style: text.bodyMedium),
            ),
        ],
        for (final PantrySuggestion s in report.suggestions)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Text(
              'In your pantry for ${s.group.label.toLowerCase()}: '
              '${s.items.join(', ')}.',
              style: text.bodyMedium!.copyWith(color: colors.primary),
            ),
          ),
        for (final String note in report.notes)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(note, style: muted),
          ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Worked out from what you marked as used or cooked. It cannot see '
          'meals eaten out or food you did not log, and calories are rough '
          'averages for raw food. A guide, not medical advice.',
          style: muted,
        ),
      ],
    );
  }
}

class _VerdictRow extends StatelessWidget {
  const _VerdictRow({required this.report});

  final ConsumptionReport report;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = context.akText;
    switch (report.verdict) {
      case BalanceVerdict.balanced:
        return const Align(
          alignment: Alignment.centerLeft,
          child: StatusChip(kind: StatusKind.fresh, label: 'Balanced'),
        );
      case BalanceVerdict.partly:
        return const Align(
          alignment: Alignment.centerLeft,
          child: StatusChip(kind: StatusKind.expiring, label: 'Partly balanced'),
        );
      case BalanceVerdict.notBalanced:
        return const Align(
          alignment: Alignment.centerLeft,
          child: StatusChip(kind: StatusKind.expired, label: 'Not balanced yet'),
        );
      case BalanceVerdict.notEnoughData:
        return Text(
          report.period == ReportPeriod.today
              ? 'Too little marked as used to judge the balance yet.'
              : 'Too few days logged to judge the balance yet.',
          style: text.bodyMedium,
        );
    }
  }
}

class _GroupChip extends StatelessWidget {
  const _GroupChip({
    required this.group,
    required this.present,
    required this.judged,
  });

  final PlateGroup group;
  final bool present;
  final bool judged;

  @override
  Widget build(BuildContext context) {
    final AkshayaColors colors = context.akColors;
    final StatusColors good = colors.forStatus(StatusKind.fresh);
    final Color foreground = present ? good.foreground : colors.textSecondary;
    final Color background = present ? good.background : colors.surfaceAlt;
    final IconData icon = present
        ? Icons.check_circle_rounded
        : (judged ? Icons.remove_circle_outline_rounded : Icons.circle_outlined);
    return Semantics(
      label: '${group.label}: ${present ? 'included' : 'not included'}',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: background,
          shape: const StadiumBorder(),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: AppSizes.iconXs, color: foreground),
              const SizedBox(width: AppSpacing.xs),
              Text(
                group.label,
                style: context.akText.labelSmall!.copyWith(color: foreground),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
