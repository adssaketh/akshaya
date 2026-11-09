import 'package:akshaya/core/design/design.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../domain/nutrition_table.dart';
import '../domain/report_models.dart';
import 'report_format.dart';

/// The colour of a food group in charts. Every chart also writes the group's
/// name, so colour is never the only cue.
Color foodGroupColor(AkshayaColors c, FoodGroup group) {
  switch (group) {
    case FoodGroup.cereals:
      return c.accent;
    case FoodGroup.pulses:
      return c.primary;
    case FoodGroup.vegetables:
      return c.forStatus(StatusKind.fresh).foreground;
    case FoodGroup.tubers:
      return Color.lerp(
        c.forStatus(StatusKind.fresh).foreground,
        c.accent,
        0.5,
      )!;
    case FoodGroup.fruits:
      return c.forStatus(StatusKind.expiring).foreground;
    case FoodGroup.dairy:
      return c.forStatus(StatusKind.lowStock).foreground;
    case FoodGroup.meatEggs:
      return c.forStatus(StatusKind.expired).foreground;
    case FoodGroup.fats:
      return Color.lerp(c.primary, c.textPrimary, 0.55)!;
    case FoodGroup.sugars:
      return Color.lerp(c.accent, c.primary, 0.5)!;
    case FoodGroup.nutsSeeds:
      return c.forStatus(StatusKind.outOfStock).foreground;
    case FoodGroup.other:
      return c.textSecondary;
  }
}

const List<String> _weekdayShort = <String>[
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];
const List<String> _monthShort = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// "Tue 4 Nov".
String dayLabel(DateTime d) =>
    '${_weekdayShort[d.weekday - 1]} ${d.day} ${_monthShort[d.month - 1]}';

/// A short description of the daily bars, for screen readers.
String dailySummary(List<DailyPoint> points, int target) {
  final List<DailyPoint> logged = points
      .where((DailyPoint p) => p.logged)
      .toList();
  if (logged.isEmpty) {
    return 'No days with food marked as used.';
  }
  return '${logged.length} of ${points.length} days logged. '
      'Calories per person per day, target ${groupThousands(target)}: '
      '${logged.map((DailyPoint p) => '${dayLabel(p.day)} '
          '${groupThousands(p.kcalPerPerson.round())}').join(', ')}.';
}

/// Calories per person for each day, with the target as a dashed line.
class CaloriesBarChart extends StatelessWidget {
  const CaloriesBarChart({
    super.key,
    required this.points,
    required this.target,
    this.height = 200,
  });

  final List<DailyPoint> points;
  final int target;
  final double height;

  @override
  Widget build(BuildContext context) {
    final AkshayaColors colors = context.akColors;
    final TextTheme text = context.akText;
    final double tallest = points.fold<double>(
      0,
      (double m, DailyPoint p) => p.kcalPerPerson > m ? p.kcalPerPerson : m,
    );
    final double maxY = ((tallest > target ? tallest : target.toDouble()) * 1.2)
        .ceilToDouble();
    final double interval = (maxY / 4 / 100).ceilToDouble() * 100;
    final bool many = points.length > 10;
    final bool animate = AppMotion.of(context);

    return Semantics(
      label: dailySummary(points, target),
      child: ExcludeSemantics(
        child: SizedBox(
          height: height,
          child: BarChart(
            duration: animate ? AppMotion.slow : Duration.zero,
            curve: AppMotion.enter,
            BarChartData(
              maxY: maxY,
              alignment: BarChartAlignment.spaceAround,
              borderData: FlBorderData(show: false),
              gridData: FlGridData(
                drawVerticalLine: false,
                horizontalInterval: interval,
                getDrawingHorizontalLine: (double _) => FlLine(
                  color: colors.outline,
                  strokeWidth: 1,
                  dashArray: <int>[3, 4],
                ),
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    interval: interval,
                    getTitlesWidget: (double v, TitleMeta meta) {
                      if (v == meta.max) {
                        return const SizedBox.shrink();
                      }
                      return SideTitleWidget(
                        meta: meta,
                        child: Text(
                          groupThousands(v.round()),
                          style: text.labelSmall!.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 26,
                    getTitlesWidget: (double v, TitleMeta meta) {
                      final int i = v.toInt();
                      if (i < 0 || i >= points.length) {
                        return const SizedBox.shrink();
                      }
                      final DateTime d = points[i].day;
                      final bool show =
                          !many ||
                          i == points.length - 1 ||
                          (points.length - 1 - i) % 7 == 0;
                      if (!show) {
                        return const SizedBox.shrink();
                      }
                      return SideTitleWidget(
                        meta: meta,
                        child: Text(
                          many
                              ? '${d.day} ${_monthShort[d.month - 1]}'
                              : _weekdayShort[d.weekday - 1].substring(0, 1),
                          style: text.labelSmall!.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              extraLinesData: ExtraLinesData(
                horizontalLines: <HorizontalLine>[
                  HorizontalLine(
                    y: target.toDouble(),
                    color: colors.accent,
                    strokeWidth: 2,
                    dashArray: <int>[6, 4],
                    label: HorizontalLineLabel(
                      show: true,
                      alignment: Alignment.topLeft,
                      style: text.labelSmall!.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                      labelResolver: (HorizontalLine _) =>
                          'Target ${groupThousands(target)}',
                    ),
                  ),
                ],
              ),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (BarChartGroupData _) => colors.textPrimary,
                  getTooltipItem:
                      (
                        BarChartGroupData group,
                        int groupIndex,
                        BarChartRodData rod,
                        int rodIndex,
                      ) {
                        final DailyPoint p = points[groupIndex];
                        return BarTooltipItem(
                          p.logged
                              ? '${dayLabel(p.day)}\n'
                                    '${groupThousands(p.kcalPerPerson.round())} kcal'
                              : '${dayLabel(p.day)}\nnothing logged',
                          text.labelMedium!.copyWith(color: colors.background),
                        );
                      },
                ),
              ),
              barGroups: <BarChartGroupData>[
                for (int i = 0; i < points.length; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: <BarChartRodData>[
                      BarChartRodData(
                        toY: points[i].logged && points[i].kcalPerPerson > 0
                            ? points[i].kcalPerPerson
                            : maxY * 0.015,
                        width: many ? 5 : 22,
                        color: points[i].logged
                            ? colors.primary
                            : colors.outline,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(many ? 2 : 8),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A ring showing how much of a target has been reached, with the figure in
/// the middle.
class GaugeRing extends StatelessWidget {
  const GaugeRing({
    super.key,
    required this.value,
    required this.target,
    required this.centerTop,
    required this.centerBottom,
    this.size = 132,
  });

  final double value;
  final double target;
  final String centerTop;
  final String centerBottom;
  final double size;

  @override
  Widget build(BuildContext context) {
    final AkshayaColors colors = context.akColors;
    final TextTheme text = context.akText;
    final double reached = value.clamp(0, target).toDouble();
    final double left = (target - reached).clamp(0, target).toDouble();
    return Semantics(
      label:
          '$centerTop $centerBottom, ${(100 * value / target).round()}% '
          'of the target',
      child: ExcludeSemantics(
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              PieChart(
                duration: AppMotion.of(context)
                    ? AppMotion.slow
                    : Duration.zero,
                curve: AppMotion.enter,
                PieChartData(
                  startDegreeOffset: -90,
                  sectionsSpace: 0,
                  centerSpaceRadius: size * 0.33,
                  pieTouchData: PieTouchData(enabled: false),
                  sections: <PieChartSectionData>[
                    PieChartSectionData(
                      value: reached <= 0 ? 0.0001 : reached,
                      color: value > target * 1.15
                          ? colors.forStatus(StatusKind.expiring).foreground
                          : colors.primary,
                      radius: size * 0.13,
                      showTitle: false,
                    ),
                    PieChartSectionData(
                      value: left <= 0 ? 0.0001 : left,
                      color: colors.outline,
                      radius: size * 0.13,
                      showTitle: false,
                    ),
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(centerTop, style: text.titleLarge),
                  Text(
                    centerBottom,
                    style: text.labelSmall!.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Energy from each food group as a ring, with a legend that writes every
/// share down.
class EnergyDonut extends StatelessWidget {
  const EnergyDonut({super.key, required this.energy});

  final Map<FoodGroup, double> energy;

  @override
  Widget build(BuildContext context) {
    final AkshayaColors colors = context.akColors;
    final TextTheme text = context.akText;
    final List<MapEntry<FoodGroup, double>> parts =
        energy.entries
            .where((MapEntry<FoodGroup, double> e) => e.value > 0)
            .toList()
          ..sort(
            (MapEntry<FoodGroup, double> a, MapEntry<FoodGroup, double> b) =>
                b.value.compareTo(a.value),
          );
    final double total = parts.fold<double>(
      0,
      (double s, MapEntry<FoodGroup, double> e) => s + e.value,
    );
    if (total <= 0) {
      return const SizedBox.shrink();
    }
    final String summary = parts
        .map(
          (MapEntry<FoodGroup, double> e) =>
              '${e.key.label} ${(100 * e.value / total).round()}%',
        )
        .join(', ');

    final Widget ring = Semantics(
      label: 'Energy by food group: $summary',
      child: ExcludeSemantics(
        child: SizedBox(
          width: 150,
          height: 150,
          child: PieChart(
            duration: AppMotion.of(context) ? AppMotion.slow : Duration.zero,
            curve: AppMotion.enter,
            PieChartData(
              startDegreeOffset: -90,
              sectionsSpace: 2,
              centerSpaceRadius: 42,
              pieTouchData: PieTouchData(enabled: false),
              sections: <PieChartSectionData>[
                for (final MapEntry<FoodGroup, double> e in parts)
                  PieChartSectionData(
                    value: e.value,
                    color: foodGroupColor(colors, e.key),
                    radius: 30,
                    showTitle: false,
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    final Widget legend = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final MapEntry<FoodGroup, double> e in parts)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: <Widget>[
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: foodGroupColor(colors, e.key),
                    shape: BoxShape.circle,
                  ),
                  child: const SizedBox(width: 12, height: 12),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    e.key.label,
                    style: text.bodyMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${(100 * e.value / total).round()}%',
                  style: text.bodyMedium!.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
      ],
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints box) {
        if (box.maxWidth < 340) {
          return Column(
            children: <Widget>[ring, const SizedBox(height: 8), legend],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            ring,
            const SizedBox(width: AppSpacing.lg),
            Expanded(child: legend),
          ],
        );
      },
    );
  }
}

/// A single stacked bar for the share of energy from carbohydrate, protein
/// and fat, with the figures written under it.
class MacroBar extends StatelessWidget {
  const MacroBar({super.key, required this.nutrients});

  final NutrientAverages nutrients;

  @override
  Widget build(BuildContext context) {
    final AkshayaColors colors = context.akColors;
    final TextTheme text = context.akText;
    final Map<String, double>? shares = nutrients.energyShares;
    if (shares == null) {
      return const SizedBox.shrink();
    }
    final Map<String, (Color, double)> parts = <String, (Color, double)>{
      'Carbs': (colors.accent, nutrients.carbs),
      'Protein': (colors.primary, nutrients.protein),
      'Fat': (colors.forStatus(StatusKind.lowStock).foreground, nutrients.fat),
    };
    return Semantics(
      label:
          'Energy from ${parts.keys.map((String k) => '$k ${(100 * shares[k]!).round()}%').join(', ')}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ExcludeSemantics(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 18,
                child: Row(
                  children: <Widget>[
                    for (final MapEntry<String, (Color, double)> e
                        in parts.entries)
                      Expanded(
                        flex: (shares[e.key]! * 1000).round().clamp(1, 1000),
                        child: ColoredBox(color: e.value.$1),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.xs,
            children: <Widget>[
              for (final MapEntry<String, (Color, double)> e in parts.entries)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: e.value.$1,
                        shape: BoxShape.circle,
                      ),
                      child: const SizedBox(width: 10, height: 10),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Flexible(
                      child: Text(
                        '${e.key} ${(100 * shares[e.key]!).round()}% · '
                        '${e.value.$2.round()} g',
                        style: text.bodySmall,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A labelled horizontal bar: [fraction] (0 to 1) of the width is filled.
class LabelledBar extends StatelessWidget {
  const LabelledBar({
    super.key,
    required this.label,
    required this.valueText,
    required this.fraction,
    required this.color,
    this.leading,
    this.detail,
  });

  final String label;
  final String valueText;
  final double fraction;
  final Color color;
  final Widget? leading;

  /// A small line under the bar (for example the nutrients in the amount).
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final AkshayaColors colors = context.akColors;
    final TextTheme text = context.akText;
    final double f = fraction.clamp(0, 1).toDouble();
    return Semantics(
      label: '$label, $valueText',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                if (leading != null) ...<Widget>[
                  leading!,
                  const SizedBox(width: AppSpacing.sm),
                ],
                Expanded(
                  flex: 3,
                  child: Text(
                    label,
                    style: text.bodyMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  flex: 2,
                  child: Text(
                    valueText,
                    textAlign: TextAlign.end,
                    style: text.bodySmall!.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 8,
                child: Stack(
                  children: <Widget>[
                    Positioned.fill(
                      child: ColoredBox(color: colors.surfaceAlt),
                    ),
                    FractionallySizedBox(
                      widthFactor: f,
                      child: ColoredBox(color: color),
                    ),
                  ],
                ),
              ),
            ),
            if (detail != null)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  detail!,
                  style: text.bodySmall!.copyWith(color: colors.textSecondary),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
