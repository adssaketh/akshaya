import 'package:akshaya/core/design/design.dart';
import 'package:akshaya/core/ui/swipe_tabs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A page that remembers how many times it was tapped.
class _Counter extends StatefulWidget {
  const _Counter();

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int taps = 0;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton(
        onPressed: () => setState(() => taps++),
        child: Text('taps: $taps'),
      ),
    );
  }
}

class _Harness extends StatefulWidget {
  const _Harness({
    required this.position,
    this.initial = 0,
    this.reduceMotion = false,
    this.pages,
  });

  final ValueNotifier<double> position;
  final int initial;
  final bool reduceMotion;
  final List<Widget>? pages;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  late int index = widget.initial;
  final List<int> swipes = <int>[];

  void go(int i) => setState(() => index = i);

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQueryData(disableAnimations: widget.reduceMotion),
      child: MaterialApp(
        theme: AkshayaTheme.light(),
        home: Scaffold(
          body: SwipeTabs(
            index: index,
            position: widget.position,
            onIndexChanged: (int i) {
              swipes.add(i);
              setState(() => index = i);
            },
            children:
                widget.pages ??
                <Widget>[
                  for (int i = 0; i < 5; i++)
                    i == 1 ? const _Counter() : Center(child: Text('Page $i')),
                ],
          ),
        ),
      ),
    );
  }
}

void main() {
  late ValueNotifier<double> position;

  setUp(() => position = ValueNotifier<double>(0));
  tearDown(() => position.dispose());

  Future<_HarnessState> pump(
    WidgetTester tester, {
    int initial = 0,
    bool reduceMotion = false,
    List<Widget>? pages,
  }) async {
    await tester.pumpWidget(
      _Harness(
        position: position,
        initial: initial,
        reduceMotion: reduceMotion,
        pages: pages,
      ),
    );
    await tester.pumpAndSettle();
    return tester.state<_HarnessState>(find.byType(_Harness));
  }

  Future<void> swipe(WidgetTester tester, {required bool towardsNext}) async {
    await tester.fling(
      find.byType(PageView),
      Offset(towardsNext ? -500 : 500, 0),
      1500,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the page for the starting index', (tester) async {
    await pump(tester, initial: 3);
    expect(find.text('Page 3'), findsOneWidget);
    expect(position.value, 3);
  });

  testWidgets('a swipe goes to the next page and says so once', (tester) async {
    final _HarnessState h = await pump(tester);
    await swipe(tester, towardsNext: true);
    expect(find.text('taps: 0'), findsOneWidget, reason: 'page 1');
    expect(h.swipes, <int>[1]);
    expect(h.index, 1);
    await swipe(tester, towardsNext: true);
    expect(find.text('Page 2'), findsOneWidget);
    expect(h.swipes, <int>[1, 2]);
  });

  testWidgets('and back again', (tester) async {
    final _HarnessState h = await pump(tester, initial: 2);
    await swipe(tester, towardsNext: false);
    expect(find.text('taps: 0'), findsOneWidget);
    expect(h.index, 1);
  });

  testWidgets('the first page does not bounce into nothing', (tester) async {
    final _HarnessState h = await pump(tester);
    await swipe(tester, towardsNext: false);
    expect(find.text('Page 0'), findsOneWidget);
    expect(h.swipes, isEmpty);
    expect(position.value, 0);
  });

  testWidgets('nor does the last', (tester) async {
    final _HarnessState h = await pump(tester, initial: 4);
    await swipe(tester, towardsNext: true);
    expect(find.text('Page 4'), findsOneWidget);
    expect(h.swipes, isEmpty);
    expect(position.value, 4);
  });

  testWidgets('a short, slow drag that does not pass halfway springs back', (
    tester,
  ) async {
    final _HarnessState h = await pump(tester);
    final TestGesture g = await tester.startGesture(const Offset(300, 300));
    await g.moveBy(const Offset(-80, 0));
    await tester.pump();
    expect(position.value, greaterThan(0));
    await g.up();
    await tester.pumpAndSettle();
    expect(h.index, 0);
    expect(position.value, 0);
    expect(h.swipes, isEmpty);
  });

  testWidgets('the position follows the finger part-way', (tester) async {
    await pump(tester);
    final TestGesture g = await tester.startGesture(const Offset(400, 300));
    await g.moveBy(const Offset(-240, 0));
    await tester.pump();
    expect(position.value, inExclusiveRange(0.1, 0.9));
    final double halfway = position.value;
    await g.moveBy(const Offset(-120, 0));
    await tester.pump();
    expect(position.value, greaterThan(halfway));
    await g.up();
    await tester.pumpAndSettle();
    expect(position.value, anyOf(0, 1));
  });

  testWidgets('a nav tap (index change) slides there and is not a swipe', (
    tester,
  ) async {
    final _HarnessState h = await pump(tester);
    h.go(1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(
      position.value,
      inExclusiveRange(0.01, 0.99),
      reason: 'it is sliding, not jumping',
    );
    await tester.pumpAndSettle();
    expect(position.value, 1);
    expect(find.text('taps: 0'), findsOneWidget);
    expect(h.swipes, isEmpty);
  });

  testWidgets('a far tab is reached in one move, not through every page', (
    tester,
  ) async {
    final _HarnessState h = await pump(tester);
    final List<double> seen = <double>[];
    position.addListener(() => seen.add(position.value));
    h.go(4);
    await tester.pumpAndSettle();
    expect(position.value, 4);
    expect(h.swipes, isEmpty);
    final Iterable<double> after = seen.skipWhile((double v) => v < 2.5);
    expect(after, isNotEmpty);
    expect(
      seen.where((double v) => v > 0.5 && v < 2.9),
      isEmpty,
      reason: 'pages 1 and 2 were never slid through',
    );
  });

  testWidgets('going back to a far tab works the same way', (tester) async {
    final _HarnessState h = await pump(tester, initial: 4);
    h.go(0);
    await tester.pumpAndSettle();
    expect(position.value, 0);
    expect(find.text('Page 0'), findsOneWidget);
    expect(h.swipes, isEmpty);
  });

  testWidgets('every page keeps its state while it is away', (tester) async {
    final _HarnessState h = await pump(tester);
    h.go(1);
    await tester.pumpAndSettle();
    await tester.tap(find.text('taps: 0'));
    await tester.pump();
    await tester.tap(find.text('taps: 1'));
    await tester.pump();
    expect(find.text('taps: 2'), findsOneWidget);
    await swipe(tester, towardsNext: true);
    await swipe(tester, towardsNext: true);
    expect(find.text('Page 3'), findsOneWidget);
    h.go(1);
    await tester.pumpAndSettle();
    expect(find.text('taps: 2'), findsOneWidget);
  });

  testWidgets('with reduced motion the page switches at once', (tester) async {
    final _HarnessState h = await pump(tester, reduceMotion: true);
    h.go(2);
    await tester.pump();
    expect(position.value, 2);
    expect(find.text('Page 2'), findsOneWidget);
  });

  testWidgets('a page with its own sideways list keeps those drags', (
    tester,
  ) async {
    final _HarnessState h = await pump(
      tester,
      pages: <Widget>[
        SizedBox(
          height: 200,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: <Widget>[
              for (int i = 0; i < 20; i++)
                SizedBox(width: 120, child: Center(child: Text('chip $i'))),
            ],
          ),
        ),
        const Center(child: Text('Page 1')),
      ],
    );
    await tester.drag(find.byType(ListView), const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(find.text('chip 0'), findsNothing, reason: 'the list scrolled');
    expect(h.index, 0, reason: 'the page did not');
    expect(h.swipes, isEmpty);
  });

  testWidgets('a finger can stop a slide and take over', (tester) async {
    final _HarnessState h = await pump(tester);
    h.go(2);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    final TestGesture g = await tester.startGesture(const Offset(300, 300));
    await g.moveBy(const Offset(200, 0));
    await tester.pump();
    await g.up();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(position.value, position.value.roundToDouble());
    // The screen and the state agree afterwards.
    final int shown = position.value.round();
    expect(h.index, shown);
  });

  testWidgets('pages ease back while sliding and are plain at rest', (
    tester,
  ) async {
    await pump(tester);
    double smallest() => tester
        .widgetList<Transform>(
          find.descendant(
            of: find.byType(PageView),
            matching: find.byType(Transform),
          ),
        )
        .map((Transform t) => t.transform.storage[0])
        .fold<double>(1, (double a, double b) => b < a ? b : a);
    expect(smallest(), 1, reason: 'nothing scaled at rest');
    final TestGesture g = await tester.startGesture(const Offset(400, 300));
    await g.moveBy(const Offset(-200, 0));
    await tester.pump();
    expect(smallest(), lessThan(1));
    expect(smallest(), greaterThan(0.9), reason: 'only a little');
    await g.up();
    await tester.pumpAndSettle();
    expect(smallest(), 1);
  });

  testWidgets('pages never fade, which would redraw them every frame', (
    tester,
  ) async {
    await pump(tester);
    final TestGesture g = await tester.startGesture(const Offset(400, 300));
    await g.moveBy(const Offset(-200, 0));
    await tester.pump();
    final Iterable<Opacity> faded = tester
        .widgetList<Opacity>(
          find.descendant(
            of: find.byType(PageView),
            matching: find.byType(Opacity),
          ),
        )
        .where((Opacity o) => o.opacity < 1);
    expect(faded, isEmpty);
    await g.up();
    await tester.pumpAndSettle();
  });

  group('the nav bar indicator', () {
    Future<void> pumpBar(
      WidgetTester tester,
      ValueNotifier<double>? pos, {
      int selected = 0,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AkshayaTheme.light(),
          home: Scaffold(
            bottomNavigationBar: AkshayaNavBar(
              selectedIndex: selected,
              position: pos,
              onSelected: (_) {},
              destinations: <AkshayaNavDestination>[
                for (int i = 0; i < 5; i++)
                  const AkshayaNavDestination(
                    icon: Icons.circle_outlined,
                    selectedIcon: Icons.circle,
                    label: 'tab',
                  ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    double indicatorLeft(WidgetTester tester) {
      final Positioned p = tester
          .widgetList<Positioned>(find.byType(Positioned))
          .firstWhere((Positioned p) => p.width == AppSizes.navIndicatorWidth);
      return p.left!;
    }

    testWidgets('moves with the position, with nothing of its own', (
      tester,
    ) async {
      final ValueNotifier<double> pos = ValueNotifier<double>(0);
      addTearDown(pos.dispose);
      await pumpBar(tester, pos);
      final double a = indicatorLeft(tester);
      pos.value = 1;
      await tester.pump();
      final double b = indicatorLeft(tester);
      pos.value = 1.5;
      await tester.pump();
      final double c = indicatorLeft(tester);
      expect(b, greaterThan(a));
      expect(c - b, closeTo((b - a) / 2, 0.01), reason: 'in step, no lag');
    });

    testWidgets('stays inside the bar at the ends', (tester) async {
      final ValueNotifier<double> pos = ValueNotifier<double>(0);
      addTearDown(pos.dispose);
      await pumpBar(tester, pos);
      final double first = indicatorLeft(tester);
      pos.value = -3;
      await tester.pump();
      expect(indicatorLeft(tester), first);
      pos.value = 99;
      await tester.pump();
      pos.value = 4;
      await tester.pump();
      expect(indicatorLeft(tester), greaterThan(first));
    });

    testWidgets('without a position it slides to the selected tab as before', (
      tester,
    ) async {
      await pumpBar(tester, null, selected: 2);
      final double at2 = indicatorLeft(tester);
      await pumpBar(tester, null);
      expect(indicatorLeft(tester), lessThan(at2));
    });
  });
}
