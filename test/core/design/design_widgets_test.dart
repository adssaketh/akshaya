import 'package:akshaya/core/design/design.dart';
import 'package:akshaya/core/design/gallery/design_gallery_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget host(
  Widget child, {
  ThemeData? theme,
  double textScale = 1,
}) {
  return MaterialApp(
    theme: theme ?? AkshayaTheme.light(),
    builder: (BuildContext context, Widget? app) {
      return MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
        ),
        child: app!,
      );
    },
    home: Scaffold(
      body: Center(child: SizedBox(width: 360, child: child)),
    ),
  );
}

void main() {
  group('StatusChip', () {
    testWidgets('shows the default label and icon for each kind',
        (tester) async {
      for (final StatusKind kind in StatusKind.values) {
        await tester.pumpWidget(host(StatusChip(kind: kind)));
        expect(find.text(kind.label), findsOneWidget, reason: kind.name);
        expect(find.byIcon(kind.icon), findsOneWidget, reason: kind.name);
      }
    });

    testWidgets('a custom label replaces the default', (tester) async {
      await tester.pumpWidget(
        host(const StatusChip(kind: StatusKind.expiring, label: 'In 2 days')),
      );
      expect(find.text('In 2 days'), findsOneWidget);
      expect(find.text('Expiring soon'), findsNothing);
    });

    testWidgets('uses the status colours from the tokens', (tester) async {
      await tester.pumpWidget(
        host(const StatusChip(kind: StatusKind.expired)),
      );
      final Icon icon = tester.widget<Icon>(find.byIcon(StatusKind.expired.icon));
      expect(icon.color, AkshayaColors.light.expired.foreground);
    });
  });

  group('SummaryTile', () {
    testWidgets('shows count and label and reports taps', (tester) async {
      int taps = 0;
      await tester.pumpWidget(
        host(
          SummaryTile(
            kind: StatusKind.lowStock,
            count: 7,
            label: 'Low stock',
            onTap: () => taps++,
          ),
        ),
      );
      expect(find.text('7'), findsOneWidget);
      expect(find.text('Low stock'), findsOneWidget);
      await tester.tap(find.byType(SummaryTile));
      expect(taps, 1);
    });

    testWidgets('exposes one semantic label', (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        host(
          const SummaryTile(
            kind: StatusKind.expiring,
            count: 3,
            label: 'Expiring soon',
          ),
        ),
      );
      expect(find.bySemanticsLabel('3 Expiring soon'), findsOneWidget);
      handle.dispose();
    });
  });

  group('ItemCard', () {
    testWidgets('shows name, subtitle and status chip and reports taps',
        (tester) async {
      int taps = 0;
      await tester.pumpWidget(
        host(
          ItemCard(
            name: 'Curd',
            subtitle: 'Fridge · 1 kg left',
            icon: Icons.water_drop_outlined,
            status: StatusKind.expiring,
            statusLabel: 'Tomorrow',
            onTap: () => taps++,
          ),
        ),
      );
      expect(find.text('Curd'), findsOneWidget);
      expect(find.text('Fridge · 1 kg left'), findsOneWidget);
      expect(find.text('Tomorrow'), findsOneWidget);
      await tester.tap(find.byType(ItemCard));
      expect(taps, 1);
    });

    testWidgets('does not overflow at 2x text scale with long text',
        (tester) async {
      await tester.pumpWidget(
        host(
          const ItemCard(
            name: 'Organic cold pressed groundnut oil, family pack',
            subtitle: 'Pantry shelf, second row · 4.5 L left',
            icon: Icons.grain_rounded,
            status: StatusKind.outOfStock,
          ),
          textScale: 2,
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('SectionHeader', () {
    testWidgets('shows the action only when a label is given', (tester) async {
      int taps = 0;
      await tester.pumpWidget(
        host(
          SectionHeader(
            title: 'Use soon',
            actionLabel: 'See all',
            onAction: () => taps++,
          ),
        ),
      );
      expect(find.text('Use soon'), findsOneWidget);
      await tester.tap(find.text('See all'));
      expect(taps, 1);

      await tester.pumpWidget(host(const SectionHeader(title: 'Use soon')));
      expect(find.text('See all'), findsNothing);
    });
  });

  group('EmptyState', () {
    testWidgets('shows copy and an action button', (tester) async {
      int taps = 0;
      await tester.pumpWidget(
        host(
          EmptyState(
            icon: Icons.inventory_2_outlined,
            title: 'Start your pantry',
            body: 'Add what you have.',
            actionLabel: 'Add item',
            onAction: () => taps++,
          ),
        ),
      );
      expect(find.text('Start your pantry'), findsOneWidget);
      expect(find.text('Add what you have.'), findsOneWidget);
      await tester.tap(find.text('Add item'));
      expect(taps, 1);
    });

    testWidgets('omits the button without an action label', (tester) async {
      await tester.pumpWidget(
        host(
          const EmptyState(
            icon: Icons.inventory_2_outlined,
            title: 'Nothing to buy',
            body: 'Your list is empty.',
          ),
        ),
      );
      expect(find.byType(FilledButton), findsNothing);
    });
  });

  group('Brand widgets', () {
    testWidgets('header shows the wordmark and trailing actions',
        (tester) async {
      await tester.pumpWidget(
        host(
          AkshayaHeader(
            actions: <Widget>[
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.notifications_none_rounded),
              ),
            ],
          ),
        ),
      );
      expect(find.text('Akshaya Patra'), findsOneWidget);
      expect(find.byType(AkshayaLogo), findsOneWidget);
      expect(find.byType(SarukuluMotif), findsOneWidget);
      expect(find.byIcon(Icons.notifications_none_rounded), findsOneWidget);
    });
  });

  group('DesignGalleryPage', () {
    for (final MapEntry<String, ThemeData> entry in <String, ThemeData>{
      'light': AkshayaTheme.light(),
      'dark': AkshayaTheme.dark(),
    }.entries) {
      testWidgets('builds without errors in ${entry.key} mode',
          (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 2400));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          MaterialApp(theme: entry.value, home: const DesignGalleryPage()),
        );
        expect(tester.takeException(), isNull);
        expect(find.text('Akshaya Patra'), findsOneWidget);
        expect(find.text('4 items need attention'), findsOneWidget);
      });
    }
  });
}
