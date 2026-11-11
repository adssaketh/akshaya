import 'package:akshaya/core/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/share/share_service.dart';
import '../../../core/time/clock.dart';
import '../../ai/domain/ai_gate.dart';
import '../../ai/domain/ai_settings.dart';
import '../../ai/presentation/providers.dart';
import '../../recipes/domain/recipe_models.dart';
import '../../recipes/presentation/providers.dart';
import '../../settings/presentation/providers.dart';
import '../domain/dgi_guide.dart';
import '../domain/meal_ideas.dart';
import '../domain/nutrition_table.dart';
import '../domain/report_ai.dart';
import '../domain/report_bundle.dart';
import '../domain/report_models.dart';
import '../domain/report_share.dart';
import 'my_plate.dart';
import '../../takeaway/presentation/takeaway_screen.dart';
import 'providers.dart';
import 'report_charts.dart';
import 'report_format.dart';
import 'report_widgets.dart';

/// Opens the Food report page.
void openFoodReport(BuildContext context) {
  Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (BuildContext _) => const FoodReportScreen(),
    ),
  );
}

/// The detailed Food report: charts, nutrients, balance, comparison, meal
/// ideas from the pantry, and an optional AI review. Everything except the AI
/// review is worked out on the phone.
class FoodReportScreen extends ConsumerWidget {
  const FoodReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<ReportBundle> bundle = ref.watch(reportBundleProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Food report'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Takeaway food',
            icon: const Icon(Icons.takeout_dining_rounded),
            onPressed: () => openTakeaway(context),
          ),
          IconButton(
            tooltip: 'Share this report',
            icon: const Icon(Icons.ios_share_rounded),
            onPressed: bundle.hasValue
                ? () => _share(context, ref, bundle.requireValue.report)
                : null,
          ),
        ],
      ),
      body: bundle.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object _, StackTrace __) => const EmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Could not load the report',
          body: 'Please try again in a moment.',
        ),
        data: (ReportBundle b) => _ReportList(bundle: b),
      ),
    );
  }

  Future<void> _share(
    BuildContext context,
    WidgetRef ref,
    ConsumptionReport report,
  ) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(shareServiceProvider)
          .shareText(buildShareText(report), subject: 'Food report');
    } on Object {
      messenger.showSnackBar(
        const SnackBar(content: Text('Sharing is not available right now.')),
      );
    }
  }
}

class _ReportList extends ConsumerWidget {
  const _ReportList({required this.bundle});

  final ReportBundle bundle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ConsumptionReport report = bundle.report;
    final int target = ref.watch(kcalTargetProvider);
    final ReportPeriod period = ref.watch(reportPeriodProvider);
    int i = 0;
    Widget reveal(Widget child) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Reveal(index: i++, child: child),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      children: <Widget>[
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
        reveal(_HeroCard(bundle: bundle, target: target)),
        if (!bundle.comparison.isEmpty) reveal(_CompareRow(bundle: bundle)),
        if (report.isEmpty)
          reveal(_EmptyReport(period: period))
        else ...<Widget>[
          reveal(
            _Section(
              icon: Icons.bar_chart_rounded,
              title: 'Calories each day',
              subtitle: 'Per person, estimated. Tap a bar for the day.',
              child: CaloriesBarChart(points: report.daily, target: target),
            ),
          ),
          if (report.energyByGroup.isNotEmpty)
            reveal(
              _Section(
                icon: Icons.donut_large_rounded,
                title: 'Where the energy came from',
                child: EnergyDonut(energy: report.energyByGroup),
              ),
            ),
          if (report.nutrients != null)
            reveal(
              _Section(
                icon: Icons.science_outlined,
                title: 'Protein, carbs, fat and fibre',
                subtitle: 'Per person per day, estimated',
                child: _NutrientsBody(report: report, target: target),
              ),
            ),
          reveal(
            _Section(
              icon: Icons.rice_bowl_outlined,
              title: 'Against the My Plate guide',
              subtitle: 'Per person per day, from the amounts you used',
              child: _PlateBody(report: report, target: target),
            ),
          ),
          reveal(
            _Section(
              icon: Icons.restaurant_menu_rounded,
              title: 'Your plate',
              subtitle: 'Share of logged days each group appeared on',
              child: _CoverageBody(report: report),
            ),
          ),
          reveal(
            _Section(
              icon: Icons.format_list_bulleted_rounded,
              title: 'What was used',
              subtitle: 'The amounts you marked as used, and what is in them',
              child: _TopFoods(lines: report.lines),
            ),
          ),
          if (report.tips.isNotEmpty ||
              report.suggestions.isNotEmpty ||
              report.notes.isNotEmpty)
            reveal(
              _Section(
                icon: Icons.tips_and_updates_outlined,
                title: 'Try this',
                child: _TipsBody(report: report),
              ),
            ),
        ],
        reveal(
          _Section(
            icon: Icons.soup_kitchen_outlined,
            title: 'Cook from your pantry',
            subtitle:
                'Offline ideas that use what you have. Assumes salt, '
                'oil and basic spices at home.',
            child: _IdeasBody(ideas: bundle.ideas),
          ),
        ),
        if (!report.isEmpty) reveal(_AiSection(bundle: bundle)),
        reveal(const _AboutSection()),
      ],
    );
  }
}

/// A rounded card with an icon, a title and an optional line under it.
class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.child,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final AkshayaColors colors = context.akColors;
    final TextTheme text = context.akText;
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
                Icon(icon, color: colors.primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(title, style: text.titleMedium),
                  ),
                ),
              ],
            ),
            if (subtitle != null) ...<Widget>[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                style: text.bodySmall!.copyWith(color: colors.textSecondary),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            child,
          ],
        ),
      ),
    );
  }
}

class _HeroCard extends ConsumerWidget {
  const _HeroCard({required this.bundle, required this.target});

  final ReportBundle bundle;
  final int target;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AkshayaColors colors = context.akColors;
    final TextTheme text = context.akText;
    final ConsumptionReport report = bundle.report;
    final RecipePreferences prefs = ref.watch(recipePreferencesProvider);
    final double? kcal = report.kcalPerPersonPerDay;
    final bool today = report.period == ReportPeriod.today;

    final Widget ring = GaugeRing(
      value: kcal ?? 0,
      target: target.toDouble(),
      centerTop: kcal == null ? '–' : groupThousands((kcal / 10).round() * 10),
      centerBottom: 'kcal',
    );

    final Widget details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          today ? 'per person today' : 'per person a day, on average',
          style: text.bodyMedium,
        ),
        Text(
          'estimate · for ${prefs.people} '
          '${prefs.people == 1 ? 'person' : 'people'}',
          style: text.bodySmall!.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.sm),
        VerdictRow(report: report),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: <Widget>[
            if (!today)
              _InfoPill(
                icon: Icons.event_available_rounded,
                text: '${report.loggedDays} of ${report.period.days} days',
              ),
            if (bundle.streak >= 2)
              _InfoPill(
                icon: Icons.local_fire_department_rounded,
                text: '${bundle.streak}-day streak',
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            IconButton(
              tooltip: 'Lower the daily target',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.remove_circle_outline_rounded),
              onPressed: target > kMinKcalTarget
                  ? () =>
                        saveKcalTarget(ref, ref.read(kcalTargetProvider) - 100)
                  : null,
            ),
            Flexible(
              child: Text(
                'Target ${groupThousands(target)}',
                style: text.labelLarge,
                textAlign: TextAlign.center,
              ),
            ),
            IconButton(
              tooltip: 'Raise the daily target',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.add_circle_outline_rounded),
              onPressed: target < kMaxKcalTarget
                  ? () =>
                        saveKcalTarget(ref, ref.read(kcalTargetProvider) + 100)
                  : null,
            ),
          ],
        ),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: 0,
          children: <Widget>[
            for (final ReferenceAdult a in kReferenceAdults)
              ChoiceChip(
                visualDensity: VisualDensity.compact,
                label: Text('${a.label} ${groupThousands(a.kcal)}'),
                selected: target == a.kcal,
                onSelected: (bool _) => saveKcalTarget(ref, a.kcal),
              ),
          ],
        ),
        Text(
          'Reference adults from $kDgiSource: a 55 kg woman and a 65 kg man. '
          'Use the + and - for your own household.',
          style: text.bodySmall!.copyWith(color: colors.textSecondary),
        ),
      ],
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: AppRadius.cardBorder,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color.alphaBlend(
              colors.primary.withValues(alpha: 0.14),
              colors.surface,
            ),
            colors.surface,
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints box) {
            if (box.maxWidth < 330) {
              return Column(
                children: <Widget>[
                  ring,
                  const SizedBox(height: AppSpacing.md),
                  details,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                ring,
                const SizedBox(width: AppSpacing.lg),
                Expanded(child: details),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final AkshayaColors colors = context.akColors;
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: colors.surfaceAlt,
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
            Icon(icon, size: AppSizes.iconXs, color: colors.primary),
            const SizedBox(width: AppSpacing.xs),
            Flexible(child: Text(text, style: context.akText.labelSmall)),
          ],
        ),
      ),
    );
  }
}

class _CompareRow extends StatelessWidget {
  const _CompareRow({required this.bundle});

  final ReportBundle bundle;

  @override
  Widget build(BuildContext context) {
    final ReportComparison c = bundle.comparison;
    final String against = bundle.report.period == ReportPeriod.today
        ? 'yesterday'
        : 'the ${bundle.report.period.days} days before';
    final List<Widget> chips = <Widget>[
      if (c.kcalChange != null)
        _ChangeChip(label: 'Calories', change: c.kcalChange!, unit: 'kcal'),
      if (c.proteinChange != null)
        _ChangeChip(label: 'Protein', change: c.proteinChange!, unit: 'g'),
      if (c.fibreChange != null)
        _ChangeChip(label: 'Fibre', change: c.fibreChange!, unit: 'g'),
      if (c.vegFruitChange != null)
        _ChangeChip(label: 'Veg & fruit', change: c.vegFruitChange!, unit: 'g'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Compared with $against',
          style: context.akText.labelMedium!.copyWith(
            color: context.akColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: chips,
        ),
      ],
    );
  }
}

class _ChangeChip extends StatelessWidget {
  const _ChangeChip({
    required this.label,
    required this.change,
    required this.unit,
  });

  final String label;
  final double change;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final AkshayaColors colors = context.akColors;
    final int rounded = change.round();
    final bool flat = rounded == 0;
    final IconData icon = flat
        ? Icons.drag_handle_rounded
        : (rounded > 0
              ? Icons.arrow_upward_rounded
              : Icons.arrow_downward_rounded);
    final String words = flat
        ? 'about the same'
        : '${rounded > 0 ? 'up' : 'down'} ${groupThousands(rounded.abs())} $unit';
    return Semantics(
      label: '$label $words',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: colors.surface,
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
              Icon(icon, size: AppSizes.iconXs, color: colors.primary),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text('$label $words', style: context.akText.labelSmall),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyReport extends StatelessWidget {
  const _EmptyReport({required this.period});

  final ReportPeriod period;

  @override
  Widget build(BuildContext context) {
    final AkshayaColors colors = context.akColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadius.cardBorder,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: <Widget>[
            Icon(Icons.insights_rounded, color: colors.primary, size: 36),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                period == ReportPeriod.today
                    ? 'Nothing is marked as used today yet. Use an item or '
                          'cook a recipe and the charts fill in. Try 7 days '
                          'for a wider view.'
                    : 'Nothing is marked as used in the last '
                          '${period.days} days. Use an item or cook a recipe '
                          'and the charts fill in.',
                style: context.akText.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NutrientsBody extends StatelessWidget {
  const _NutrientsBody({required this.report, required this.target});

  final ConsumptionReport report;
  final int target;

  @override
  Widget build(BuildContext context) {
    final AkshayaColors colors = context.akColors;
    final TextTheme text = context.akText;
    final NutrientAverages n = report.nutrients!;
    final double? vegFruit = report.vegFruitGramsPerPersonPerDay;
    final double proteinGuide = proteinGuideFor(target);
    final double fibreGuide = fibreGuideFor(target);
    final double? sugar = report.sugarGramsPerPersonPerDay;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        MacroBar(nutrients: n),
        const SizedBox(height: AppSpacing.md),
        LabelledBar(
          label: 'Protein',
          valueText:
              '${n.protein.round()} g of about '
              '${proteinGuide.round()} g',
          fraction: n.protein / proteinGuide,
          color: colors.primary,
        ),
        LabelledBar(
          label: 'Fibre',
          valueText:
              '${n.fibre.round()} g of about '
              '${fibreGuide.round()} g',
          fraction: n.fibre / fibreGuide,
          color: foodGroupColor(colors, FoodGroup.vegetables),
          detail:
              'WHO\'s minimum for adults is ${kFibreMinimumGrams.round()} g a day.',
        ),
        if (vegFruit != null)
          LabelledBar(
            label: 'Vegetables and fruit',
            valueText:
                '${vegFruit.round()} g of '
                '${kVegFruitGoalGrams.round()} g or more',
            fraction: vegFruit / kVegFruitGoalGrams,
            color: foodGroupColor(colors, FoodGroup.fruits),
          ),
        if (sugar != null)
          LabelledBar(
            label: 'Sugar and jaggery',
            valueText:
                '${sugar.round()} g, keep under '
                '${kAddedSugarLimitGrams.round()} g',
            fraction: sugar / kAddedSugarLimitGrams,
            color: sugar > kAddedSugarLimitGrams
                ? colors.forStatus(StatusKind.expiring).foreground
                : foodGroupColor(colors, FoodGroup.sugars),
          ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Guides follow $kDgiSource for the adult chosen above (about 3.4 g '
          'of protein per 100 kcal, from its sample diets). Needs differ with '
          'age, size and activity. Not medical advice.',
          style: text.bodySmall!.copyWith(color: colors.textSecondary),
        ),
      ],
    );
  }
}

/// The parts of the picture plate: what was used of each group against the
/// guide. Dal and eggs share a quarter of the plate.
List<PlateSlice> plateSlices({
  required ConsumptionReport report,
  required List<PlateTarget> plate,
}) {
  double used(FoodGroup g) => report.amountPerPersonPerDay[g] ?? 0;
  PlateTarget? find(FoodGroup g) {
    for (final PlateTarget t in plate) {
      if (t.group == g) {
        return t;
      }
    }
    return null;
  }

  double target(FoodGroup g) => find(g)?.amount ?? 0;
  return <PlateSlice>[
    PlateSlice(
      kind: PlateKind.vegetables,
      used: used(FoodGroup.vegetables),
      target: target(FoodGroup.vegetables),
      unit: 'g',
    ),
    PlateSlice(
      kind: PlateKind.fruit,
      used: used(FoodGroup.fruits),
      target: target(FoodGroup.fruits),
      unit: 'g',
    ),
    PlateSlice(
      kind: PlateKind.grains,
      used: used(FoodGroup.cereals),
      target: target(FoodGroup.cereals),
      unit: 'g',
    ),
    PlateSlice(
      kind: PlateKind.protein,
      used:
          used(FoodGroup.pulses) +
          (find(FoodGroup.meatEggs) == null ? 0 : used(FoodGroup.meatEggs)),
      target: target(FoodGroup.pulses) + target(FoodGroup.meatEggs),
      unit: 'g',
    ),
    PlateSlice(
      kind: PlateKind.milk,
      used: used(FoodGroup.dairy),
      target: target(FoodGroup.dairy),
      unit: 'ml',
    ),
  ];
}

/// What was actually used of each food group, per person per day, next to the
/// ICMR-NIN "My Plate for the Day" amounts for the chosen adult. The amounts
/// come from the quantities marked as used, never from a per-100-g figure.
class _PlateBody extends ConsumerWidget {
  const _PlateBody({required this.report, required this.target});

  final ConsumptionReport report;
  final int target;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AkshayaColors colors = context.akColors;
    final TextTheme text = context.akText;
    final bool eggs = ref.watch(reportIncludeEggsProvider);
    final List<PlateTarget> plate = plateFor(kcal: target, eggs: eggs);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        MyPlate(
          slices: plateSlices(report: report, plate: plate),
        ),
        const SizedBox(height: AppSpacing.lg),
        for (final PlateTarget t in plate)
          Builder(
            builder: (BuildContext context) {
              final double used = t.group == FoodGroup.sugars
                  ? (report.sugarGramsPerPersonPerDay ?? 0)
                  : (report.amountPerPersonPerDay[t.group] ?? 0);
              final bool over = t.isLimit && used > t.amount;
              return LabelledBar(
                label: t.label,
                valueText:
                    '${groupThousands(used.round())} ${t.unit} of '
                    '${t.isLimit ? 'up to ' : 'about '}'
                    '${groupThousands(t.amount.round())} ${t.unit}',
                fraction: t.amount <= 0 ? 0 : used / t.amount,
                color: over
                    ? colors.forStatus(StatusKind.expiring).foreground
                    : foodGroupColor(colors, t.group),
              );
            },
          ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Raw weights, as in $kDgiSource, for the adult chosen above. Foods '
          'whose amount could not be weighed (a packet, say) are not counted '
          'here, and potato and other roots are kept apart from vegetables.',
          style: text.bodySmall!.copyWith(color: colors.textSecondary),
        ),
      ],
    );
  }
}

class _CoverageBody extends StatelessWidget {
  const _CoverageBody({required this.report});

  final ConsumptionReport report;

  static FoodGroup _colorGroup(PlateGroup g) {
    switch (g) {
      case PlateGroup.cereals:
        return FoodGroup.cereals;
      case PlateGroup.protein:
        return FoodGroup.pulses;
      case PlateGroup.vegetables:
        return FoodGroup.vegetables;
      case PlateGroup.fruits:
        return FoodGroup.fruits;
      case PlateGroup.dairy:
        return FoodGroup.dairy;
    }
  }

  @override
  Widget build(BuildContext context) {
    final AkshayaColors colors = context.akColors;
    return Column(
      children: <Widget>[
        for (final PlateGroup g in PlateGroup.values)
          LabelledBar(
            label: g.label,
            valueText: report.period == ReportPeriod.today
                ? ((report.coverage[g] ?? 0) >= 0.5 ? 'included' : 'not yet')
                : '${(100 * (report.coverage[g] ?? 0)).round()}% of days',
            fraction: report.coverage[g] ?? 0,
            color: foodGroupColor(colors, _colorGroup(g)),
            leading: Icon(
              (report.coverage[g] ?? 0) >= 0.5
                  ? Icons.check_circle_rounded
                  : Icons.remove_circle_outline_rounded,
              size: AppSizes.iconXs,
              color: (report.coverage[g] ?? 0) >= 0.5
                  ? colors.forStatus(StatusKind.fresh).foreground
                  : colors.textSecondary,
            ),
          ),
      ],
    );
  }
}

class _TopFoods extends StatefulWidget {
  const _TopFoods({required this.lines});

  final List<ConsumedLine> lines;

  @override
  State<_TopFoods> createState() => _TopFoodsState();
}

/// "21 g", "4.5 g" or "0.8 g": small amounts keep a decimal so they are not
/// shown as zero.
String _g(double grams) {
  if (grams <= 0) {
    return '0 g';
  }
  return grams < 10
      ? '${grams.toStringAsFixed(1)} g'
      : '${groupThousands(grams.round())} g';
}

class _TopFoodsState extends State<_TopFoods> {
  static const int _collapsed = 8;
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final AkshayaColors colors = context.akColors;
    final List<ConsumedLine> lines = widget.lines;
    final double most = lines.fold<double>(
      0,
      (double m, ConsumedLine l) => (l.kcal ?? 0) > m ? l.kcal! : m,
    );
    final List<ConsumedLine> shown = _all
        ? lines
        : lines.take(_collapsed).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final ConsumedLine l in shown)
          LabelledBar(
            label: l.name,
            valueText: l.kcal == null
                ? '${l.quantityLabel} · not counted'
                : '${l.quantityLabel} · '
                      '${l.estimatedFromGroup ? '~' : ''}'
                      '${groupThousands(l.kcal!.round())} kcal',
            fraction: most <= 0 || l.kcal == null ? 0 : l.kcal! / most,
            color: foodGroupColor(colors, l.group),
            detail: l.kcal == null
                ? null
                : 'Protein ${_g(l.protein)} · Carbs ${_g(l.carbs)} · '
                      'Fat ${_g(l.fat)} · Fibre ${_g(l.fibre)}',
          ),
        if (lines.length > _collapsed)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => setState(() => _all = !_all),
              child: Text(_all ? 'Show fewer' : 'Show all ${lines.length}'),
            ),
          ),
      ],
    );
  }
}

class _TipsBody extends StatelessWidget {
  const _TipsBody({required this.report});

  final ConsumptionReport report;

  @override
  Widget build(BuildContext context) {
    final AkshayaColors colors = context.akColors;
    final TextTheme text = context.akText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final String tip in report.tips)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Text('• $tip', style: text.bodyMedium),
          ),
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
          Text(
            note,
            style: text.bodySmall!.copyWith(color: colors.textSecondary),
          ),
      ],
    );
  }
}

class _IdeasBody extends ConsumerWidget {
  const _IdeasBody({required this.ideas});

  final List<MealIdea> ideas;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AkshayaColors colors = context.akColors;
    final TextTheme text = context.akText;
    final bool eggs = ref.watch(reportIncludeEggsProvider);
    final Widget diet = Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xs,
        children: <Widget>[
          ChoiceChip(
            label: const Text('Vegetarian'),
            selected: !eggs,
            onSelected: (bool _) => saveIncludeEggs(ref, false),
          ),
          ChoiceChip(
            label: const Text('With eggs'),
            selected: eggs,
            onSelected: (bool _) => saveIncludeEggs(ref, true),
          ),
        ],
      ),
    );
    if (ideas.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          diet,
          Text(
            'Add a few more foods to the pantry and ideas for meals show up '
            'here.',
            style: text.bodyMedium,
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        diet,
        for (final MealIdea idea in ideas)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surfaceAlt,
                borderRadius: BorderRadius.circular(AppRadius.control),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(idea.dish.name, style: text.titleSmall),
                        ),
                        Text(
                          '${idea.dish.minutes} min',
                          style: text.labelSmall!.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Uses ${idea.uses.join(', ')}',
                      style: text.bodySmall!.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                    if (idea.fills.isNotEmpty) ...<Widget>[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Covers ${idea.fills.map((PlateGroup g) => g.label.toLowerCase()).join(', ')}',
                        style: text.bodySmall!.copyWith(color: colors.primary),
                      ),
                    ],
                    if (idea.usesExpiring.isNotEmpty)
                      Text(
                        'Uses up ${idea.usesExpiring.join(', ')} '
                        '(expires soon)',
                        style: text.bodySmall!.copyWith(
                          color: colors
                              .forStatus(StatusKind.expiring)
                              .foreground,
                        ),
                      ),
                    if (idea.missing.isNotEmpty)
                      Text(
                        'Needs ${idea.missing.join(', ')} to make it',
                        style: text.bodySmall!.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(idea.dish.how, style: text.bodySmall),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The one online part: a short written review from Gemini, only when asked.
class _AiSection extends ConsumerWidget {
  const _AiSection({required this.bundle});

  final ReportBundle bundle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AkshayaColors colors = context.akColors;
    final TextTheme text = context.akText;
    final ReportAiState ai = ref.watch(reportAiProvider);
    final AiAvailability availability = ref.watch(aiAvailabilityProvider);
    final AiSettings settings = ref.watch(aiSettingsProvider);
    final AiUsage usage = ref.watch(aiUsageProvider);
    final DateTime today = ref.watch(todayProvider);
    ref.watch(settingsMapProvider);
    final bool eggs = ref.watch(reportIncludeEggsProvider);
    final String key = ReportAiService.signature(
      bundle.report,
      today,
      variant: eggs ? 'eggs' : 'veg',
    );
    final String? shown = ai.textKey == key
        ? ai.text
        : ref.read(reportAiProvider.notifier).saved(key);
    final bool loading = ai.status == ReportAiStatus.loading;
    final bool ready = availability.isReady;
    final int used = usage.countOn(today);

    return _Section(
      icon: Icons.auto_awesome_rounded,
      title: 'Ask AI for a deeper review',
      subtitle:
          'Online, only when you tap. Sends food names and totals only, '
          'never your name or location.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (shown != null)
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surfaceAlt,
                borderRadius: BorderRadius.circular(AppRadius.control),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: SelectableText(shown, style: text.bodyMedium),
              ),
            ),
          if (ai.status == ReportAiStatus.failed && ai.message != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                '${ai.message} Everything above still works offline.',
                style: text.bodyMedium,
              ),
            ),
          if (!ready && !loading)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                availability.message ?? 'AI is not available right now.',
                style: text.bodySmall!.copyWith(color: colors.textSecondary),
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          if (loading)
            Row(
              children: <Widget>[
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text('Asking for a review...', style: text.bodyMedium),
              ],
            )
          else
            FilledButton.tonalIcon(
              onPressed: ready
                  ? () => ref
                        .read(reportAiProvider.notifier)
                        .generate(bundle, vegetarian: !eggs)
                  : null,
              icon: const Icon(Icons.auto_awesome_rounded),
              label: Text(
                shown == null ? 'Get AI review' : 'Write a new review',
              ),
            ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Uses 1 of your ${settings.dailyCap} daily AI calls ($used used '
            'today). One try, no automatic retries.',
            style: text.bodySmall!.copyWith(color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _AboutSection extends StatelessWidget {
  const _AboutSection();

  @override
  Widget build(BuildContext context) {
    final AkshayaColors colors = context.akColors;
    final TextTheme text = context.akText;
    final TextStyle body = text.bodySmall!.copyWith(
      color: colors.textSecondary,
    );
    // A Material (not a DecoratedBox) so the tile's ripple shows.
    return Material(
      color: colors.surface,
      borderRadius: AppRadius.cardBorder,
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Icon(Icons.info_outline_rounded, color: colors.primary),
          title: Text('How this is worked out', style: text.titleMedium),
          childrenPadding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '• Only food you marked as used or cooked is counted. Waste, '
              'expiry, giveaways and count corrections are left out.',
              style: body,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '• Calories and nutrients come from a built-in table of '
              '${kFoodEnergyTable.length} foods (raw values per 100 g, with '
              'typical piece weights). Foods not in the table use a food-group '
              'average (marked ~), and packets or portions are not counted. '
              'The values are approximate and typed from general knowledge, '
              'so check them against ICMR-NIN Indian Food Composition Tables '
              'or USDA FoodData Central.',
              style: body,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '• Every amount comes from the quantity you marked as used: '
              '300 g of rice counts as three times the table\'s per-100-g '
              'values, not as 100 g. The table is for raw foods, so cooked '
              'weights and leftovers will not match it.',
              style: body,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '• A person\'s figure is the total, divided by the days that '
              'had food logged and by the number of people (set in Recipes).',
              style: body,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '• A day counts as balanced when 4 of the 5 groups (grains, '
              'protein, vegetables, fruit, dairy) appear, vegetables '
              'included. A week or month is balanced when 60% of logged days '
              'are. These are simple rules, not a medical standard.',
              style: body,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '• It cannot see meals eaten out, food that was not logged, or '
              'who ate what, and "used" is not always "eaten" (some may be '
              'left over).',
              style: body,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '• The guides come from $kDgiSource (the "My Plate for the Day" '
              'and its sample diets for a 55 kg woman and a 65 kg man), plus '
              'WHO\'s 25 g fibre minimum. They were typed in by hand, so '
              'check them against the guideline, and ask a doctor or '
              'dietitian for advice that fits you.',
              style: body,
            ),
          ],
        ),
      ),
    );
  }
}
