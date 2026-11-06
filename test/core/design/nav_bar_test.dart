import 'package:akshaya/core/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const List<AkshayaNavDestination> _tabs = <AkshayaNavDestination>[
  AkshayaNavDestination(
    icon: Icons.home_outlined,
    selectedIcon: Icons.home_rounded,
    label: 'Home',
  ),
  AkshayaNavDestination(
    icon: Icons.inventory_2_outlined,
    selectedIcon: Icons.inventory_2_rounded,
    label: 'Pantry',
  ),
  AkshayaNavDestination(
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings_rounded,
    label: 'Settings',
  ),
];

Widget _host({required int index, required ValueChanged<int> onSelected}) {
  return MaterialApp(
    theme: AkshayaTheme.light(),
    home: Scaffold(
      bottomNavigationBar: AkshayaNavBar(
        destinations: _tabs,
        selectedIndex: index,
        onSelected: onSelected,
      ),
    ),
  );
}

void main() {
  testWidgets('glass bar blurs the page behind it and stays tappable',
      (tester) async {
    int? tapped;
    await tester.pumpWidget(
      MaterialApp(
        theme: AkshayaTheme.light(),
        home: Scaffold(
          bottomNavigationBar: AkshayaNavBar(
            destinations: _tabs,
            selectedIndex: 0,
            onSelected: (int i) => tapped = i,
            glass: const NavBarGlass(opacity: 0.5, blurSigma: 9, edge: true),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(BackdropFilter), findsOneWidget);
    await tester.tap(find.text('Pantry'));
    expect(tapped, 1);
  });

  testWidgets('solid bar has no backdrop filter', (tester) async {
    await tester.pumpWidget(_host(index: 0, onSelected: (_) {}));
    await tester.pumpAndSettle();
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('with extendBody the page runs behind the bar and reports the '
      'clearance', (tester) async {
    double? clearance;
    await tester.pumpWidget(
      MaterialApp(
        theme: AkshayaTheme.light(),
        home: Scaffold(
          extendBody: true,
          body: Builder(
            builder: (BuildContext context) {
              clearance = context.navClearance;
              return const SizedBox.expand(key: Key('body'));
            },
          ),
          bottomNavigationBar: AkshayaNavBar(
            destinations: _tabs,
            selectedIndex: 0,
            onSelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final double screen =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    expect(tester.getSize(find.byKey(const Key('body'))).height, screen);
    expect(clearance, greaterThanOrEqualTo(AppSizes.navBarHeight));
  });

  testWidgets('sits at the bottom and leaves the body its height',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AkshayaTheme.light(),
        home: Scaffold(
          body: const SizedBox.expand(key: Key('body')),
          bottomNavigationBar: AkshayaNavBar(
            destinations: _tabs,
            selectedIndex: 0,
            onSelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final double screen = tester.view.physicalSize.height /
        tester.view.devicePixelRatio;
    final Size bar = tester.getSize(find.byType(AkshayaNavBar));
    expect(bar.height, greaterThanOrEqualTo(AppSizes.navBarHeight));
    expect(bar.height, lessThan(120));
    expect(tester.getBottomLeft(find.byType(AkshayaNavBar)).dy, screen);
    expect(tester.getSize(find.byKey(const Key('body'))).height,
        greaterThan(screen - 140));
  });

  testWidgets('shows every label and the selected icon', (tester) async {
    await tester.pumpWidget(_host(index: 1, onSelected: (_) {}));
    await tester.pumpAndSettle();
    for (final String label in <String>['Home', 'Pantry', 'Settings']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.byIcon(Icons.inventory_2_rounded), findsOneWidget);
    expect(find.byIcon(Icons.home_outlined), findsOneWidget);
  });

  testWidgets('tapping a tab reports its index', (tester) async {
    int? tapped;
    await tester.pumpWidget(_host(index: 0, onSelected: (i) => tapped = i));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    expect(tapped, 2);
  });

  testWidgets('the indicator slides to the selected tab', (tester) async {
    await tester.pumpWidget(_host(index: 0, onSelected: (_) {}));
    await tester.pumpAndSettle();
    final double before = tester
        .getTopLeft(find.byType(AnimatedPositioned))
        .dx;
    await tester.pumpWidget(_host(index: 2, onSelected: (_) {}));
    await tester.pumpAndSettle();
    final double after = tester.getTopLeft(find.byType(AnimatedPositioned)).dx;
    expect(after, greaterThan(before));
  });

  testWidgets('large text does not overflow', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AkshayaTheme.light(),
        builder: (BuildContext context, Widget? app) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: app!,
        ),
        home: Scaffold(
          bottomNavigationBar: AkshayaNavBar(
            destinations: _tabs,
            selectedIndex: 0,
            onSelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
