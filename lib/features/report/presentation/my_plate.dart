import 'dart:math' as math;

import 'package:akshaya/core/design/design.dart';
import 'package:flutter/material.dart';

import 'report_format.dart';

/// The parts of the plate, in the order they are listed.
enum PlateKind {
  vegetables('Vegetables'),
  fruit('Fruit'),
  grains('Grains'),
  protein('Dal and eggs'),
  milk('Milk and curd');

  const PlateKind(this.label);

  final String label;
}

/// One part of the plate: how much of a food group was used against what the
/// guide asks for in a day.
final class PlateSlice {
  const PlateSlice({
    required this.kind,
    required this.used,
    required this.target,
    required this.unit,
  });

  final PlateKind kind;
  final double used;
  final double target;

  /// "g" or "ml".
  final String unit;

  /// Used divided by the guide (can pass 1).
  double get fraction => target <= 0 ? 0 : used / target;

  /// How full the part is, 0 to 1. Passing the guide counts as full.
  double get reached => fraction.clamp(0, 1).toDouble();

  int get percent => (fraction * 100).round();
}

/// Where each part of the plate sits, in degrees clockwise from the right
/// edge (start, sweep). Half the plate is vegetables and fruit, a quarter
/// grains, a quarter dal and eggs, as in a "My Plate" picture.
const Map<PlateKind, (double, double)> kPlateAngles =
    <PlateKind, (double, double)>{
      PlateKind.vegetables: (126, 144),
      PlateKind.fruit: (90, 36),
      PlateKind.grains: (270, 90),
      PlateKind.protein: (0, 90),
    };

/// The food area as a share of the plate's radius (the rest is the rim).
const double kWellFraction = 0.80;

/// The radius, as a share of the food area, that gives a part a filled AREA
/// equal to [reached]: half full looks half full.
double fillRadius(double reached) => math.sqrt(reached.clamp(0, 1).toDouble());

/// Which part of the plate a point is on, or null for the rim, the hub gap
/// and the table. [size] is the square the plate is drawn in.
PlateKind? plateKindAt(Offset point, Size size) {
  final Offset c = size.center(Offset.zero);
  final Offset d = point - c;
  final double wellRadius = size.shortestSide / 2 * kWellFraction;
  // Not the rim, and not the hub in the middle.
  if (d.distance > wellRadius || d.distance < size.shortestSide * 0.12) {
    return null;
  }
  double degrees = math.atan2(d.dy, d.dx) * 180 / math.pi;
  if (degrees < 0) {
    degrees += 360;
  }
  for (final MapEntry<PlateKind, (double, double)> e in kPlateAngles.entries) {
    final double start = e.value.$1;
    final double end = start + e.value.$2;
    if (degrees >= start && degrees < end) {
      return e.key;
    }
    if (end > 360 && degrees < end - 360) {
      return e.key;
    }
  }
  return null;
}

/// One bit of food on the plate.
final class PlateItem {
  const PlateItem({
    required this.angle,
    required this.radius,
    required this.size,
    required this.turn,
    required this.tone,
  });

  /// 0 to 1 across the part's angle.
  final double angle;

  /// 0 to 1 out from the centre, over the food area.
  final double radius;

  /// Relative size.
  final double size;
  final double turn;
  final int tone;
}

const Map<PlateKind, int> _itemCounts = <PlateKind, int>{
  PlateKind.grains: 170,
  PlateKind.protein: 100,
  PlateKind.vegetables: 90,
  PlateKind.fruit: 36,
};

final Map<PlateKind, List<PlateItem>> _itemCache =
    <PlateKind, List<PlateItem>>{};

/// The bits of food for a part, always in the same places (the plate must not
/// shuffle when it redraws). Spread evenly over the part's area.
List<PlateItem> plateItems(PlateKind kind) {
  return _itemCache.putIfAbsent(kind, () {
    final int count = _itemCounts[kind] ?? 0;
    final math.Random random = math.Random(kind.index * 9973 + 17);
    return <PlateItem>[
      for (int i = 0; i < count; i++)
        PlateItem(
          angle: 0.06 + 0.88 * random.nextDouble(),
          radius: 0.03 + 0.94 * math.sqrt(random.nextDouble()),
          size: 0.75 + 0.5 * random.nextDouble(),
          turn: random.nextDouble() * math.pi,
          tone: random.nextInt(4),
        ),
    ]..sort((PlateItem a, PlateItem b) => a.radius.compareTo(b.radius));
  });
}

const Map<PlateKind, Color> _baseColor = <PlateKind, Color>{
  PlateKind.grains: PlateColors.baseGrains,
  PlateKind.protein: PlateColors.baseProtein,
  PlateKind.vegetables: PlateColors.baseVegetables,
  PlateKind.fruit: PlateColors.baseFruit,
};

const Map<PlateKind, List<Color>> _tones = <PlateKind, List<Color>>{
  PlateKind.grains: <Color>[
    PlateColors.grain1,
    PlateColors.grain2,
    PlateColors.grain3,
    PlateColors.grain4,
  ],
  PlateKind.protein: <Color>[
    PlateColors.dal1,
    PlateColors.dal2,
    PlateColors.dal3,
    PlateColors.baseProtein,
  ],
  PlateKind.vegetables: <Color>[
    PlateColors.veg1,
    PlateColors.veg2,
    PlateColors.veg3,
    PlateColors.carrot,
  ],
  PlateKind.fruit: <Color>[
    PlateColors.fruit1,
    PlateColors.fruit2,
    PlateColors.fruit3,
    PlateColors.fruit4,
  ],
};

/// A picture of the day's plate: a porcelain plate with vegetables and fruit
/// on one half, grains on a quarter and dal or eggs on a quarter, and a bowl
/// of milk or curd beside it. Each part fills with food as more of that group
/// is used, in step with the guide. It slides in, fills with a staggered
/// motion, refills when the numbers change, and a tap on a part shows its
/// amounts.
class MyPlate extends StatefulWidget {
  const MyPlate({super.key, required this.slices});

  /// One entry per [PlateKind].
  final List<PlateSlice> slices;

  @override
  State<MyPlate> createState() => _MyPlateState();
}

class _MyPlateState extends State<MyPlate> with TickerProviderStateMixin {
  late final AnimationController _fill = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );
  late List<double> _from;
  late List<double> _to;
  PlateKind? _selected;
  bool _started = false;

  List<double> _reached(List<PlateSlice> s) => <double>[
    for (final PlateSlice p in s) p.reached,
  ];

  @override
  void initState() {
    super.initState();
    _from = List<double>.filled(widget.slices.length, 0);
    _to = _reached(widget.slices);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) {
      return;
    }
    _started = true;
    if (AppMotion.of(context)) {
      _intro.forward();
      _fill.forward();
    } else {
      _intro.value = 1;
      _fill.value = 1;
    }
  }

  @override
  void didUpdateWidget(MyPlate oldWidget) {
    super.didUpdateWidget(oldWidget);
    final List<double> next = _reached(widget.slices);
    bool changed = next.length != _to.length;
    for (int i = 0; !changed && i < next.length; i++) {
      changed = (next[i] - _to[i]).abs() > 0.0005;
    }
    if (!changed) {
      return;
    }
    _from = _shown();
    _to = next;
    if (AppMotion.of(context)) {
      _fill.forward(from: 0);
    } else {
      _from = _to;
      _fill.value = 1;
    }
  }

  /// What the plate shows right now (for tests): how full each part is.
  @visibleForTesting
  List<double> get debugShown => _shown();

  /// How full each part looks right now.
  List<double> _shown() {
    final double t = _fill.value;
    return <double>[
      for (int i = 0; i < _to.length; i++)
        _from[i] +
            (_to[i] - _from[i]) *
                Interval(
                  i * 0.10,
                  math.min(1, 0.62 + i * 0.10),
                  curve: Curves.easeOutCubic,
                ).transform(t),
    ];
  }

  @override
  void dispose() {
    _fill.dispose();
    _intro.dispose();
    super.dispose();
  }

  PlateSlice _slice(PlateKind k) =>
      widget.slices.firstWhere((PlateSlice s) => s.kind == k);

  void _select(PlateKind? kind) {
    setState(() => _selected = kind == _selected ? null : kind);
  }

  String _summary() {
    return 'Plate. ${widget.slices.map((PlateSlice s) => '${s.kind.label} ${s.percent} percent of the guide').join(', ')}.';
  }

  @override
  Widget build(BuildContext context) {
    final AkshayaColors colors = context.akColors;
    final TextTheme text = context.akText;
    final PlateSlice? picked = _selected == null ? null : _slice(_selected!);
    final double overall = widget.slices.isEmpty
        ? 0
        : widget.slices.fold<double>(
                0,
                (double a, PlateSlice s) => a + s.reached,
              ) /
              widget.slices.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Semantics(
          label: _summary(),
          container: true,
          child: ExcludeSemantics(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints box) {
                final double width = box.maxWidth;
                final double plate = math.min(width * 0.78, 300);
                final double bowl = math.min(width * 0.30, 110);
                return SizedBox(
                  height: plate,
                  child: AnimatedBuilder(
                    animation: Listenable.merge(<Listenable>[_fill, _intro]),
                    builder: (BuildContext context, Widget? _) {
                      final double intro = Curves.easeOutBack.transform(
                        _intro.value,
                      );
                      return Opacity(
                        opacity: _intro.value.clamp(0, 1).toDouble(),
                        child: Transform.scale(
                          scale: 0.88 + 0.12 * intro,
                          child: Stack(
                            children: <Widget>[
                              Positioned(
                                left: 0,
                                top: 0,
                                width: plate,
                                height: plate,
                                child: _PlateView(
                                  size: plate,
                                  slices: widget.slices,
                                  shown: _shown(),
                                  selected: _selected,
                                  overall: overall,
                                  onTap: _select,
                                ),
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                width: bowl,
                                height: bowl + 28,
                                child: _BowlView(
                                  size: bowl,
                                  slice: _slice(PlateKind.milk),
                                  shown: _shown()[PlateKind.milk.index],
                                  selected: _selected == PlateKind.milk,
                                  onTap: () => _select(PlateKind.milk),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: <Widget>[
            for (final PlateSlice s in widget.slices)
              ChoiceChip(
                visualDensity: VisualDensity.compact,
                avatar: DecoratedBox(
                  decoration: BoxDecoration(
                    color: _legendColor(s.kind),
                    shape: BoxShape.circle,
                  ),
                  child: const SizedBox(width: 12, height: 12),
                ),
                label: Text('${s.kind.label} ${s.percent}%'),
                selected: _selected == s.kind,
                onSelected: (bool _) => _select(s.kind),
              ),
          ],
        ),
        AnimatedSize(
          duration: AppMotion.of(context)
              ? const Duration(milliseconds: 220)
              : Duration.zero,
          curve: Curves.easeOutCubic,
          alignment: Alignment.topLeft,
          child: AnimatedSwitcher(
            duration: AppMotion.of(context)
                ? const Duration(milliseconds: 220)
                : Duration.zero,
            switchInCurve: Curves.easeOutCubic,
            child: Padding(
              key: ValueKey<PlateKind?>(_selected),
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                picked == null
                    ? 'Tap a part of the plate to see its amounts.'
                    : '${picked.kind.label}: '
                          '${groupThousands(picked.used.round())} ${picked.unit} '
                          'of about ${groupThousands(picked.target.round())} '
                          '${picked.unit} (${picked.percent}%)',
                style: text.bodyMedium!.copyWith(
                  color: picked == null ? colors.textSecondary : null,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  static Color _legendColor(PlateKind k) {
    switch (k) {
      case PlateKind.milk:
        return PlateColors.milkLegend;
      case PlateKind.vegetables:
      case PlateKind.fruit:
      case PlateKind.grains:
      case PlateKind.protein:
        return _baseColor[k]!;
    }
  }
}

class _PlateView extends StatelessWidget {
  const _PlateView({
    required this.size,
    required this.slices,
    required this.shown,
    required this.selected,
    required this.overall,
    required this.onTap,
  });

  final double size;
  final List<PlateSlice> slices;
  final List<double> shown;
  final PlateKind? selected;
  final double overall;
  final ValueChanged<PlateKind?> onTap;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = context.akText;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (TapUpDetails d) =>
          onTap(plateKindAt(d.localPosition, Size.square(size))),
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _PlatePainter(shown: shown, selected: selected),
              ),
            ),
          ),
          for (final PlateSlice s in slices)
            if (kPlateAngles.containsKey(s.kind))
              _PartLabel(slice: s, size: size),
          Align(
            child: SizedBox(
              width: size * 0.24,
              height: size * 0.24,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: PlateColors.wellLight,
                  border: Border.all(color: PlateColors.hairline),
                  boxShadow: const <BoxShadow>[
                    BoxShadow(
                      color: PlateColors.hubShadow,
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            '${(overall * 100).round()}%',
                            style: text.titleSmall!.copyWith(
                              color: PlateColors.ink,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'of the plate',
                            style: text.labelSmall!.copyWith(
                              color: PlateColors.inkSoft,
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A small tag on a part of the plate: its name and how full it is.
class _PartLabel extends StatelessWidget {
  const _PartLabel({required this.slice, required this.size});

  final PlateSlice slice;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (double start, double sweep) = kPlateAngles[slice.kind]!;
    final double mid = (start + sweep / 2) * math.pi / 180;
    // Out near the rim of the food area, clear of the hub.
    final double k = kWellFraction * 0.66;
    return Align(
      alignment: Alignment(math.cos(mid) * k, math.sin(mid) * k),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: size * 0.30),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: PlateColors.labelFill,
            borderRadius: BorderRadius.circular(10),
            boxShadow: const <BoxShadow>[
              BoxShadow(color: PlateColors.labelShadow, blurRadius: 3),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '${slice.kind == PlateKind.protein ? 'Dal' : slice.kind.label} '
                '${slice.percent}%',
                maxLines: 1,
                style: context.akText.labelSmall!.copyWith(
                  color: PlateColors.ink,
                  fontWeight: FontWeight.w700,
                  fontSize: 10.5,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlatePainter extends CustomPainter {
  _PlatePainter({required this.shown, required this.selected});

  /// How full each part is (0 to 1), in [PlateKind] order.
  final List<double> shown;
  final PlateKind? selected;

  @override
  void paint(Canvas canvas, Size size) {
    final double r = size.shortestSide / 2;
    final Offset c = size.center(Offset.zero);
    final double rim = r * 0.96;
    final double well = r * kWellFraction;

    // Shadow on the table.
    canvas.drawShadow(
      Path()..addOval(Rect.fromCircle(center: c, radius: rim)),
      PlateColors.shadow,
      7,
      true,
    );
    // Porcelain rim.
    canvas.drawCircle(
      c,
      rim,
      Paint()
        ..shader = const RadialGradient(
          colors: <Color>[
            PlateColors.porcelainLight,
            PlateColors.porcelainEdge,
          ],
          stops: <double>[0.72, 1],
        ).createShader(Rect.fromCircle(center: c, radius: rim)),
    );
    final Paint hairline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas
      ..drawCircle(c, rim, hairline..color = PlateColors.hairline)
      ..drawCircle(c, r * 0.90, hairline..color = PlateColors.hairlineSoft);
    // The dip where the food sits.
    canvas.drawCircle(
      c,
      well,
      Paint()
        ..shader = const RadialGradient(
          colors: <Color>[PlateColors.wellLight, PlateColors.wellDark],
        ).createShader(Rect.fromCircle(center: c, radius: well)),
    );
    canvas.drawCircle(
      c,
      well,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..color = PlateColors.wellEdge,
    );

    // Food, part by part.
    for (final PlateKind kind in kPlateAngles.keys) {
      final double reached = kind.index < shown.length ? shown[kind.index] : 0;
      if (reached <= 0.001) {
        continue;
      }
      _paintFood(canvas, c, well, kind, reached);
    }

    // Dividers between the parts.
    final Paint divider = Paint()
      ..color = PlateColors.divider
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;
    for (final (double start, double _) in kPlateAngles.values) {
      final double a = start * math.pi / 180;
      canvas.drawLine(c, c + Offset(math.cos(a), math.sin(a)) * well, divider);
    }

    // The chosen part, outlined.
    final PlateKind? pick = selected;
    if (pick != null && kPlateAngles.containsKey(pick)) {
      final (double start, double sweep) = kPlateAngles[pick]!;
      canvas.drawPath(
        _sector(c, well, start, sweep),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.2
          ..strokeJoin = StrokeJoin.round
          ..color = PlateColors.pick,
      );
    }

    // A soft gleam on the rim.
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r * 0.93),
      -2.75,
      0.9,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.045
        ..strokeCap = StrokeCap.round
        ..color = PlateColors.gleam,
    );
  }

  static Path _sector(Offset c, double radius, double start, double sweep) {
    return Path()
      ..moveTo(c.dx, c.dy)
      ..arcTo(
        Rect.fromCircle(center: c, radius: radius),
        start * math.pi / 180,
        sweep * math.pi / 180,
        false,
      )
      ..close();
  }

  void _paintFood(
    Canvas canvas,
    Offset c,
    double well,
    PlateKind kind,
    double reached,
  ) {
    final (double start, double sweep) = kPlateAngles[kind]!;
    final double fillR = fillRadius(reached);
    final Path area = _sector(c, well * fillR, start, sweep);
    canvas
      ..save()
      ..clipPath(area)
      ..drawPath(
        area,
        Paint()..color = _baseColor[kind]!.withValues(alpha: 0.6),
      );

    final List<Color> tones = _tones[kind]!;
    final Paint paint = Paint();
    final double unit = well / 17;
    for (final PlateItem it in plateItems(kind)) {
      // Each bit pops in as the food reaches it.
      final double pop = ((fillR - it.radius) / 0.10).clamp(0, 1).toDouble();
      if (pop <= 0) {
        continue;
      }
      final double a = (start + sweep * it.angle) * math.pi / 180;
      final Offset at =
          c + Offset(math.cos(a), math.sin(a)) * (well * it.radius);
      final double s = unit * it.size * pop;
      paint.color = tones[it.tone];
      switch (kind) {
        case PlateKind.grains:
          canvas
            ..save()
            ..translate(at.dx, at.dy)
            ..rotate(it.turn)
            ..drawOval(
              Rect.fromCenter(
                center: Offset.zero,
                width: s * 1.35,
                height: s * 0.55,
              ),
              paint,
            )
            ..restore();
        case PlateKind.protein:
          canvas
            ..drawCircle(at, s * 0.62, paint)
            ..drawCircle(
              at + Offset(-s * 0.16, -s * 0.16),
              s * 0.2,
              Paint()..color = PlateColors.shine,
            );
        case PlateKind.vegetables:
          if (it.tone == 3) {
            canvas.drawCircle(at, s * 0.52, paint);
          } else {
            canvas
              ..save()
              ..translate(at.dx, at.dy)
              ..rotate(it.turn)
              ..drawOval(
                Rect.fromCenter(
                  center: Offset.zero,
                  width: s * 1.5,
                  height: s * 0.8,
                ),
                paint,
              )
              ..drawLine(
                Offset(-s * 0.6, 0),
                Offset(s * 0.6, 0),
                Paint()
                  ..color = PlateColors.leafVein
                  ..strokeWidth = s * 0.1,
              )
              ..restore();
          }
        case PlateKind.fruit:
          canvas
            ..drawCircle(at, s * 0.8, paint)
            ..drawCircle(
              at,
              s * 0.8,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = s * 0.14
                ..color = PlateColors.fruitRing,
            );
        case PlateKind.milk:
          break;
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PlatePainter old) {
    if (old.selected != selected || old.shown.length != shown.length) {
      return true;
    }
    for (int i = 0; i < shown.length; i++) {
      if (old.shown[i] != shown[i]) {
        return true;
      }
    }
    return false;
  }
}

class _BowlView extends StatelessWidget {
  const _BowlView({
    required this.size,
    required this.slice,
    required this.shown,
    required this.selected,
    required this.onTap,
  });

  final double size;
  final PlateSlice slice;
  final double shown;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          SizedBox(
            width: size,
            height: size,
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _BowlPainter(shown: shown, selected: selected),
              ),
            ),
          ),
          const SizedBox(height: 2),
          SizedBox(
            height: 26,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'Milk ${slice.percent}%',
                maxLines: 1,
                style: context.akText.labelSmall!.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BowlPainter extends CustomPainter {
  _BowlPainter({required this.shown, required this.selected});

  final double shown;
  final bool selected;

  @override
  void paint(Canvas canvas, Size size) {
    final double r = size.shortestSide / 2;
    final Offset c = size.center(Offset.zero);
    canvas.drawShadow(
      Path()..addOval(Rect.fromCircle(center: c, radius: r * 0.96)),
      PlateColors.shadow,
      6,
      true,
    );
    canvas.drawCircle(
      c,
      r * 0.96,
      Paint()
        ..shader = const RadialGradient(
          colors: <Color>[PlateColors.porcelainLight, PlateColors.bowlEdge],
          stops: <double>[0.6, 1],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    final double inner = r * 0.74;
    canvas.drawCircle(c, inner, Paint()..color = PlateColors.bowlWell);
    final double level = inner * fillRadius(shown);
    if (level > 0.5) {
      canvas
        ..drawCircle(
          c,
          level,
          Paint()
            ..shader = const RadialGradient(
              colors: <Color>[PlateColors.porcelainLight, PlateColors.curdEdge],
            ).createShader(Rect.fromCircle(center: c, radius: level)),
        )
        // A little swirl on the curd.
        ..drawArc(
          Rect.fromCircle(center: c, radius: level * 0.55),
          0.6,
          3.4,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1, level * 0.08)
            ..strokeCap = StrokeCap.round
            ..color = PlateColors.hairline,
        );
    }
    canvas.drawCircle(
      c,
      inner,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = PlateColors.hairline,
    );
    if (selected) {
      canvas.drawCircle(
        c,
        r * 0.98,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = PlateColors.pick,
      );
    }
  }

  @override
  bool shouldRepaint(_BowlPainter old) =>
      old.shown != shown || old.selected != selected;
}
