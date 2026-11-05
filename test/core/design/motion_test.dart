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
      expect(find.byType(Opacity), findsNothing);
      expect(find.text('hello'), findsOneWidget);
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
