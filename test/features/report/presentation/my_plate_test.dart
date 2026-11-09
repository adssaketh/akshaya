import 'dart:math' as math;

import 'package:akshaya/core/design/design.dart';
import 'package:akshaya/features/report/presentation/my_plate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

PlateSlice slice(
  PlateKind k,
  double used,
  double target, [
  String unit = 'g',
]) => PlateSlice(kind: k, used: used, target: target, unit: unit);

List<PlateSlice> sample({double v = 120, double f = 25, double g = 125}) =>
    <PlateSlice>[
      slice(PlateKind.vegetables, v, 400),
      slice(PlateKind.fruit, f, 100),
      slice(PlateKind.grains, g, 250),
      slice(PlateKind.protein, 85, 85),
      slice(PlateKind.milk, 150, 300, 'ml'),
    ];

/// A point on a 200 x 200 plate, [degrees] clockwise from the right and
/// [distance] from the middle.
Offset pointAt(double degrees, double distance) {
  final double a = degrees * math.pi / 180;
  return Offset(100 + distance * math.cos(a), 100 + distance * math.sin(a));
}

void main() {
  group('how full a part looks', () {
    test('half full looks half full by area', () {
      expect(fillRadius(0), 0);
      expect(fillRadius(1), 1);
      expect(fillRadius(0.25), closeTo(0.5, 1e-9));
      for (final double r in <double>[0.1, 0.3, 0.5, 0.8]) {
        expect(fillRadius(r) * fillRadius(r), closeTo(r, 1e-9));
      }
    });

    test('never more than full, never less than empty', () {
      expect(fillRadius(3), 1);
      expect(fillRadius(-1), 0);
    });

    test('a slice is capped at full but keeps its real percent', () {
      final PlateSlice s = slice(PlateKind.grains, 375, 250);
      expect(s.reached, 1);
      expect(s.percent, 150);
      expect(slice(PlateKind.fruit, 0, 0).fraction, 0);
    });
  });

  group('which part a tap is on', () {
    const Size plate = Size.square(200);

    test('each part of the plate is found where it is drawn', () {
      expect(plateKindAt(pointAt(200, 55), plate), PlateKind.vegetables);
      expect(plateKindAt(pointAt(108, 55), plate), PlateKind.fruit);
      expect(plateKindAt(pointAt(300, 55), plate), PlateKind.grains);
      expect(plateKindAt(pointAt(45, 55), plate), PlateKind.protein);
    });

    test('half the plate is vegetables and fruit, a quarter each the rest', () {
      double sweep(PlateKind k) => kPlateAngles[k]!.$2;
      expect(sweep(PlateKind.vegetables) + sweep(PlateKind.fruit), 180);
      expect(sweep(PlateKind.grains), 90);
      expect(sweep(PlateKind.protein), 90);
    });

    test('every degree belongs to exactly one part', () {
      for (int d = 0; d < 360; d += 3) {
        final PlateKind? k = plateKindAt(
          pointAt(d.toDouble() + 0.5, 55),
          plate,
        );
        expect(k, isNotNull, reason: '$d degrees');
        expect(k, isNot(PlateKind.milk));
      }
    });

    test('the rim, the hub and the table are not a part', () {
      expect(plateKindAt(pointAt(200, 90), plate), isNull, reason: 'rim');
      expect(plateKindAt(pointAt(200, 5), plate), isNull, reason: 'hub');
      expect(plateKindAt(const Offset(100, 100), plate), isNull);
      expect(plateKindAt(const Offset(-20, 50), plate), isNull);
    });

    test('works at any size', () {
      expect(
        plateKindAt(
          const Offset(150, 150) + const Offset(-80, -10),
          const Size.square(300),
        ),
        PlateKind.vegetables,
      );
      expect(
        plateKindAt(
          const Offset(150, 150) + const Offset(-20, -5),
          const Size.square(300),
        ),
        isNull,
        reason: 'inside the hub',
      );
    });
  });

  group('the food on the plate', () {
    test('is always in the same places', () {
      final List<PlateItem> a = plateItems(PlateKind.vegetables);
      final List<PlateItem> b = plateItems(PlateKind.vegetables);
      expect(identical(a, b), isTrue);
      expect(a.first.angle, plateItems(PlateKind.vegetables).first.angle);
    });

    test('every part has some, the bowl has none', () {
      for (final PlateKind k in kPlateAngles.keys) {
        expect(plateItems(k), isNotEmpty, reason: k.name);
      }
      expect(plateItems(PlateKind.milk), isEmpty);
    });

    test('stays inside its part, and is ordered from the middle out', () {
      for (final PlateKind k in kPlateAngles.keys) {
        double last = 0;
        for (final PlateItem it in plateItems(k)) {
          expect(it.angle, inInclusiveRange(0.06, 0.94));
          expect(it.radius, inInclusiveRange(0.03, 0.97));
          expect(
            it.radius,
            greaterThanOrEqualTo(last),
            reason: 'so it can be revealed from the middle outwards',
          );
          last = it.radius;
        }
      }
    });

    test('is spread by area, not bunched in the middle', () {
      final List<PlateItem> items = plateItems(PlateKind.grains);
      final int outer = items.where((PlateItem i) => i.radius > 0.7).length;
      final int inner = items.where((PlateItem i) => i.radius < 0.3).length;
      expect(outer, greaterThan(inner));
    });
  });

  group('on screen', () {
    Future<void> pump(
      WidgetTester tester,
      List<PlateSlice> slices, {
      double width = 400,
      double textScale = 1,
      bool dark = false,
      bool reduceMotion = false,
      bool settle = true,
    }) async {
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: reduceMotion,
          ),
          child: MaterialApp(
            theme: dark ? AkshayaTheme.dark() : AkshayaTheme.light(),
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: width,
                  child: SingleChildScrollView(child: MyPlate(slices: slices)),
                ),
              ),
            ),
          ),
        ),
      );
      if (settle) {
        await tester.pumpAndSettle();
      }
    }

    List<double> shown(WidgetTester tester) =>
        (tester.state(find.byType(MyPlate)) as dynamic).debugShown
            as List<double>;

    testWidgets('shows the plate, the bowl and a chip for every part', (
      tester,
    ) async {
      await pump(tester, sample());
      expect(find.byType(MyPlate), findsOneWidget);
      for (final String chip in <String>[
        'Vegetables 30%',
        'Fruit 25%',
        'Grains 50%',
        'Dal and eggs 100%',
        'Milk and curd 50%',
      ]) {
        expect(
          find.widgetWithText(ChoiceChip, chip),
          findsOneWidget,
          reason: chip,
        );
      }
      expect(
        find.text('Tap a part of the plate to see its amounts.'),
        findsOneWidget,
      );
    });

    testWidgets('the middle shows how full the whole plate is', (tester) async {
      await pump(tester, <PlateSlice>[
        slice(PlateKind.vegetables, 400, 400),
        slice(PlateKind.fruit, 50, 100),
        slice(PlateKind.grains, 0, 250),
        slice(PlateKind.protein, 42.5, 85),
        slice(PlateKind.milk, 300, 300, 'ml'),
      ]);
      // (1 + 0.5 + 0 + 0.5 + 1) / 5 = 60%
      expect(find.text('60%'), findsOneWidget);
    });

    testWidgets('an empty plate says 0% and does not break', (tester) async {
      await pump(tester, <PlateSlice>[
        for (final PlateKind k in PlateKind.values) slice(k, 0, 100),
      ]);
      expect(find.text('0%'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping a part names its amounts, and again clears it', (
      tester,
    ) async {
      await pump(tester, sample());
      final Offset origin = tester.getTopLeft(find.byType(MyPlate));
      // The plate is 300 wide here; its middle is (150, 150).
      await tester.tapAt(
        origin +
            const Offset(150, 150) +
            Offset(
              70 * math.cos(200 * math.pi / 180),
              70 * math.sin(200 * math.pi / 180),
            ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Vegetables: 120 g of about 400 g (30%)'),
        findsOneWidget,
      );
      await tester.tapAt(
        origin +
            const Offset(150, 150) +
            Offset(
              70 * math.cos(200 * math.pi / 180),
              70 * math.sin(200 * math.pi / 180),
            ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Tap a part of the plate to see its amounts.'),
        findsOneWidget,
      );
    });

    testWidgets('each part can be picked on the plate', (tester) async {
      await pump(tester, sample());
      final Offset origin = tester.getTopLeft(find.byType(MyPlate));
      final Map<double, String> want = <double, String>{
        108: 'Fruit: 25 g of about 100 g (25%)',
        300: 'Grains: 125 g of about 250 g (50%)',
        45: 'Dal and eggs: 85 g of about 85 g (100%)',
      };
      for (final MapEntry<double, String> e in want.entries) {
        await tester.tapAt(
          origin +
              const Offset(150, 150) +
              Offset(
                70 * math.cos(e.key * math.pi / 180),
                70 * math.sin(e.key * math.pi / 180),
              ),
        );
        await tester.pumpAndSettle();
        expect(find.text(e.value), findsOneWidget, reason: e.value);
      }
    });

    testWidgets('tapping the bowl picks the milk', (tester) async {
      await pump(tester, sample());
      final Offset origin = tester.getTopLeft(find.byType(MyPlate));
      await tester.tapAt(origin + const Offset(345, 217));
      await tester.pumpAndSettle();
      expect(
        find.text('Milk and curd: 150 ml of about 300 ml (50%)'),
        findsOneWidget,
      );
    });

    testWidgets('the legend chips pick a part too', (tester) async {
      await pump(tester, sample());
      await tester.tap(find.widgetWithText(ChoiceChip, 'Fruit 25%'));
      await tester.pumpAndSettle();
      expect(find.text('Fruit: 25 g of about 100 g (25%)'), findsOneWidget);
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Fruit 25%'))
            .selected,
        isTrue,
      );
    });

    testWidgets('tapping the rim or the table picks nothing', (tester) async {
      await pump(tester, sample());
      final Offset origin = tester.getTopLeft(find.byType(MyPlate));
      await tester.tapAt(origin + const Offset(2, 150));
      await tester.pumpAndSettle();
      expect(
        find.text('Tap a part of the plate to see its amounts.'),
        findsOneWidget,
      );
    });

    group('motion', () {
      testWidgets('starts empty, fills part by part, ends full', (
        tester,
      ) async {
        await pump(tester, sample(), settle: false);
        expect(shown(tester), everyElement(0));
        await tester.pump(const Duration(milliseconds: 350));
        final List<double> early = shown(tester);
        // The first part is ahead of the last: they fill one after another.
        final double ahead = early[0] / 0.30;
        final double behind = early[4] / 0.50;
        expect(ahead, greaterThan(behind));
        expect(early[0], inExclusiveRange(0, 0.30));
        await tester.pumpAndSettle();
        final List<double> end = shown(tester);
        expect(end[0], closeTo(0.30, 1e-9));
        expect(end[1], closeTo(0.25, 1e-9));
        expect(end[2], closeTo(0.50, 1e-9));
        expect(end[3], closeTo(1.0, 1e-9));
        expect(end[4], closeTo(0.50, 1e-9));
      });

      testWidgets('the plate slides in: fading and growing', (tester) async {
        await pump(tester, sample(), settle: false);
        await tester.pump(const Duration(milliseconds: 100));
        final Opacity early = tester.widget<Opacity>(
          find
              .descendant(
                of: find.byType(MyPlate),
                matching: find.byType(Opacity),
              )
              .first,
        );
        expect(early.opacity, lessThan(1));
        await tester.pumpAndSettle();
        final Opacity done = tester.widget<Opacity>(
          find
              .descendant(
                of: find.byType(MyPlate),
                matching: find.byType(Opacity),
              )
              .first,
        );
        expect(done.opacity, 1);
      });

      testWidgets('new numbers refill from where it was, not from empty', (
        tester,
      ) async {
        await pump(tester, sample(v: 100));
        expect(shown(tester)[0], closeTo(0.25, 1e-9));
        await pump(tester, sample(v: 300), settle: false);
        await tester.pump(const Duration(milliseconds: 120));
        final double mid = shown(tester)[0];
        expect(mid, greaterThanOrEqualTo(0.25));
        expect(mid, lessThan(0.75));
        await tester.pumpAndSettle();
        expect(shown(tester)[0], closeTo(0.75, 1e-9));
      });

      testWidgets('the same numbers again do not restart it', (tester) async {
        await pump(tester, sample());
        await pump(tester, sample(), settle: false);
        await tester.pump(const Duration(milliseconds: 50));
        expect(shown(tester)[0], closeTo(0.30, 1e-9));
      });

      testWidgets('with reduced motion it is full at once', (tester) async {
        await pump(tester, sample(), reduceMotion: true, settle: false);
        await tester.pump();
        expect(shown(tester)[0], closeTo(0.30, 1e-9));
        expect(shown(tester)[3], closeTo(1.0, 1e-9));
        final Opacity o = tester.widget<Opacity>(
          find
              .descendant(
                of: find.byType(MyPlate),
                matching: find.byType(Opacity),
              )
              .first,
        );
        expect(o.opacity, 1);
      });

      testWidgets('going over the guide fills to the brim and no further', (
        tester,
      ) async {
        await pump(tester, sample(g: 500));
        expect(shown(tester)[2], 1.0);
        expect(find.widgetWithText(ChoiceChip, 'Grains 200%'), findsOneWidget);
      });
    });

    group('in tough conditions', () {
      testWidgets('a narrow phone with big text', (tester) async {
        await pump(tester, sample(), width: 300, textScale: 1.6);
        expect(tester.takeException(), isNull);
      });

      testWidgets('very narrow', (tester) async {
        await pump(tester, sample(), width: 220);
        expect(tester.takeException(), isNull);
      });

      testWidgets('dark mode', (tester) async {
        await pump(tester, sample(), dark: true);
        expect(tester.takeException(), isNull);
        expect(find.byType(CustomPaint), findsWidgets);
      });

      testWidgets('read out as one summary', (tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        await pump(tester, sample());
        expect(
          find.bySemanticsLabel(RegExp(r'^Plate\. Vegetables 30 percent')),
          findsOneWidget,
        );
        handle.dispose();
      });
    });
  });
}
