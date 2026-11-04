import 'package:akshaya/core/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget host(Widget child, {double textScale = 1}) {
  return MaterialApp(
    theme: AkshayaTheme.light(),
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
  group('ChecklistCard', () {
    testWidgets('shows title, subtitle and trailing widget', (tester) async {
      await tester.pumpWidget(
        host(
          const ChecklistCard(
            title: 'Basmati Rice',
            subtitle: '2 kg · Every week',
            checked: false,
            trailing: StatusChip(kind: StatusKind.lowStock),
          ),
        ),
      );

      expect(find.text('Basmati Rice'), findsOneWidget);
      expect(find.text('2 kg · Every week'), findsOneWidget);
      expect(find.text(StatusKind.lowStock.label), findsOneWidget);
    });

    testWidgets('ticking the checkbox reports the new state', (tester) async {
      final List<bool> changes = <bool>[];
      await tester.pumpWidget(
        host(
          ChecklistCard(
            title: 'Milk',
            checked: false,
            onChanged: changes.add,
          ),
        ),
      );

      await tester.tap(find.byType(Checkbox));
      await tester.pump();

      expect(changes, <bool>[true]);
    });

    testWidgets('tapping the body calls onTap, not onChanged', (tester) async {
      int taps = 0;
      final List<bool> changes = <bool>[];
      await tester.pumpWidget(
        host(
          ChecklistCard(
            title: 'Milk',
            checked: false,
            onChanged: changes.add,
            onTap: () => taps++,
          ),
        ),
      );

      await tester.tap(find.text('Milk'));
      await tester.pump();

      expect(taps, 1);
      expect(changes, isEmpty);
    });

    testWidgets('a checked card strikes the title through', (tester) async {
      await tester.pumpWidget(
        host(
          ChecklistCard(title: 'Milk', checked: true, onChanged: (_) {}),
        ),
      );

      final Text title = tester.widget<Text>(find.text('Milk'));
      expect(title.style?.decoration, TextDecoration.lineThrough);
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
    });

    testWidgets('a null onChanged disables the checkbox', (tester) async {
      await tester.pumpWidget(
        host(const ChecklistCard(title: 'Milk', checked: false)),
      );

      expect(tester.widget<Checkbox>(find.byType(Checkbox)).onChanged, isNull);
    });

    testWidgets('does not overflow at 200% font scale', (tester) async {
      await tester.pumpWidget(
        host(
          ChecklistCard(
            title: 'Extra virgin cold pressed groundnut oil',
            subtitle: '5 L · Every month · the big tin from the wholesaler',
            checked: false,
            trailing: const StatusChip(kind: StatusKind.lowStock),
            onChanged: (_) {},
          ),
          textScale: 2,
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });
}
