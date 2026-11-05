import 'package:akshaya/core/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget host(Widget child, {bool disableAnimations = false}) {
  return MaterialApp(
    theme: AkshayaTheme.light(),
    builder: (BuildContext context, Widget? app) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: disableAnimations),
      child: app!,
    ),
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  tearDown(() => AppMotion.userEnabled = true);

  group('Reveal', () {
    testWidgets('starts hidden, then settles fully visible',
        (WidgetTester tester) async {
      await tester.pumpWidget(host(const Reveal(child: Text('hello'))));
      Opacity opacity = tester.widget(find.byType(Opacity));
      expect(opacity.opacity, lessThan(1));

      await tester.pumpAndSettle();
      opacity = tester.widget(find.byType(Opacity));
      expect(opacity.opacity, 1);
      expect(find.text('hello'), findsOneWidget);
    });

    testWidgets('keeps its child alive when the entrance finishes',
        (WidgetTester tester) async {
      _Probe.created = 0;
      await tester.pumpWidget(host(const Reveal(child: _Probe())));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
      expect(_Probe.created, 1, reason: 'the child must not be rebuilt');
    });

    testWidgets('rows far down a long list appear at once',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        host(const Reveal(index: AppMotion.maxStaggered, child: Text('late'))),
      );
      expect(find.byType(Opacity), findsNothing);
      expect(find.text('late'), findsOneWidget);
    });

    testWidgets('later rows start later', (WidgetTester tester) async {
      await tester.pumpWidget(
        host(
          const Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Reveal(child: Text('first')),
              Reveal(index: 5, child: Text('sixth')),
            ],
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      final List<Opacity> o =
          tester.widgetList<Opacity>(find.byType(Opacity)).toList();
      expect(o.length, 2);
      expect(o[0].opacity, greaterThan(o[1].opacity));
      await tester.pumpAndSettle();
    });

    testWidgets('does not animate when the phone asks for no animations',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        host(const Reveal(child: Text('hello')), disableAnimations: true),
      );
      expect(find.byType(Opacity), findsNothing);
    });

    testWidgets('does not animate when switched off in Settings',
        (WidgetTester tester) async {
      AppMotion.userEnabled = false;
      await tester.pumpWidget(host(const Reveal(child: Text('hello'))));
      expect(find.byType(Opacity), findsNothing);
    });
  });

  group('TabPane', () {
    Widget pane({required bool active}) => host(
          TabPane(active: active, child: const _Probe()),
        );

    testWidgets('never starts fully transparent', (WidgetTester tester) async {
      await tester.pumpWidget(pane(active: false));
      await tester.pumpWidget(pane(active: true));
      final FadeTransition fade = tester.widget(find.byType(FadeTransition).last);
      expect(fade.opacity.value, greaterThanOrEqualTo(0.4));
      expect(fade.opacity.value, lessThan(1));
      await tester.pumpAndSettle();
      expect(
        tester.widget<FadeTransition>(find.byType(FadeTransition).last)
            .opacity
            .value,
        1,
      );
    });

    testWidgets('switching tabs does not rebuild the screen',
        (WidgetTester tester) async {
      _Probe.created = 0;
      await tester.pumpWidget(pane(active: false));
      await tester.pumpWidget(pane(active: true));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
      await tester.pumpWidget(pane(active: false));
      await tester.pumpWidget(pane(active: true));
      await tester.pumpAndSettle();
      expect(_Probe.created, 1, reason: 'state must survive every switch');
    });
  });

  testWidgets('AnimatedCount counts up to its value',
      (WidgetTester tester) async {
    await tester.pumpWidget(host(const AnimatedCount(value: 12)));
    expect(find.text('12'), findsNothing);
    await tester.pumpAndSettle();
    expect(find.text('12'), findsOneWidget);
  });

  testWidgets('Pressable shrinks while held and keeps the child tappable',
      (WidgetTester tester) async {
    int taps = 0;
    await tester.pumpWidget(
      host(
        Pressable(
          child: GestureDetector(
            onTap: () => taps++,
            child: const SizedBox(width: 100, height: 60, child: Text('card')),
          ),
        ),
      ),
    );
    final TestGesture gesture =
        await tester.startGesture(tester.getCenter(find.text('card')));
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
      lessThan(1),
    );
    await gesture.up();
    await tester.pumpAndSettle();
    expect(taps, 1);
    expect(
      tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
      1,
    );
  });

  testWidgets('a pushed screen slides in and settles',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      host(
        Builder(
          builder: (BuildContext context) => FilledButton(
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (BuildContext _) =>
                    const Scaffold(body: Text('second screen')),
              ),
            ),
            child: const Text('go'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text('second screen'), findsOneWidget);
  });
}

/// Counts how many times its State is created, to catch needless rebuilds.
class _Probe extends StatefulWidget {
  const _Probe();

  static int created = 0;

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  void initState() {
    super.initState();
    _Probe.created++;
  }

  @override
  Widget build(BuildContext context) => const Text('probe');
}
