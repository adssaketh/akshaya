import 'package:akshaya/core/design/design.dart';
import 'package:akshaya/core/ui/swipe_tabs.dart';
import 'package:akshaya/features/pantry/domain/entities.dart';
import 'package:akshaya/features/pantry/presentation/pantry_screen.dart';
import 'package:akshaya/features/pantry/presentation/providers.dart';
import 'package:akshaya/features/settings/presentation/providers.dart';
import 'package:akshaya/features/settings/presentation/swipe_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../settings/fake_settings_repository.dart';
import '../domain/test_data.dart';
import 'fake_repository.dart';

FakePantryRepository pantry() => FakePantryRepository(
  items: <ItemWithBatches>[
    ItemWithBatches(
      item: makeItem(id: 'i1', name: 'Basmati Rice'),
      batches: <StockBatch>[makeBatch(id: 'b1', itemId: 'i1', bought: 5)],
    ),
    ItemWithBatches(
      item: makeItem(id: 'i2', name: 'Milk', categoryId: 'cat_dairy'),
      batches: <StockBatch>[makeBatch(id: 'b2', itemId: 'i2', bought: 1)],
    ),
  ],
);

Widget host(
  FakePantryRepository repo,
  Widget home, {
  bool swipeDelete = false,
}) {
  return ProviderScope(
    overrides: [
      pantryRepositoryProvider.overrideWithValue(repo),
      settingsRepositoryProvider.overrideWithValue(FakeSettingsRepository()),
      if (swipeDelete) swipeItemActionsProvider.overrideWithValue(true),
    ],
    child: MaterialApp(
      theme: AkshayaTheme.light(),
      home: Scaffold(body: home),
    ),
  );
}

void main() {
  void bigScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Dismissible rowFor(WidgetTester tester, String name) {
    return tester.widget<Dismissible>(
      find.ancestor(of: find.text(name), matching: find.byType(Dismissible)),
    );
  }

  group('a pantry row', () {
    testWidgets('by default a row listens for no sideways drag at all', (
      tester,
    ) async {
      bigScreen(tester);
      await tester.pumpWidget(host(pantry(), const PantryScreen()));
      await tester.pumpAndSettle();
      expect(rowFor(tester, 'Milk').direction, DismissDirection.none);
      expect(rowFor(tester, 'Milk').secondaryBackground, isNull);
    });

    testWidgets('by default a swipe to the left does not delete anything', (
      tester,
    ) async {
      bigScreen(tester);
      final FakePantryRepository repo = pantry();
      await tester.pumpWidget(host(repo, const PantryScreen()));
      await tester.pumpAndSettle();
      await tester.drag(find.text('Milk'), const Offset(-700, 0));
      await tester.pumpAndSettle();
      expect(repo.deletedIds, isEmpty);
      expect(find.text('Milk'), findsOneWidget);
      expect(find.textContaining('Deleted'), findsNothing);
    });

    testWidgets('with item swipes switched on, a left swipe deletes with '
        'Undo', (tester) async {
      bigScreen(tester);
      final FakePantryRepository repo = pantry();
      await tester.pumpWidget(
        host(repo, const PantryScreen(), swipeDelete: true),
      );
      await tester.pumpAndSettle();
      expect(rowFor(tester, 'Milk').direction, DismissDirection.horizontal);
      await tester.drag(find.text('Milk'), const Offset(-700, 0));
      await tester.pumpAndSettle();
      expect(repo.deletedIds, <String>['i2']);
      expect(find.text('Deleted Milk'), findsOneWidget);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(repo.deletedIds, isEmpty);
    });
  });

  group('swiping a pantry row while changing tab', () {
    Widget tabs(
      FakePantryRepository repo, {
      bool swipeDelete = false,
      bool enabled = true,
    }) {
      return host(
        repo,
        SwipeTabs(
          index: 0,
          enabled: enabled,
          onIndexChanged: (_) {},
          children: const <Widget>[
            PantryScreen(),
            Center(child: Text('the next tab')),
          ],
        ),
        swipeDelete: swipeDelete,
      );
    }

    testWidgets('a left swipe over a row goes to the next tab and deletes '
        'nothing', (tester) async {
      bigScreen(tester);
      final FakePantryRepository repo = pantry();
      await tester.pumpWidget(tabs(repo));
      await tester.pumpAndSettle();
      await tester.fling(find.text('Milk'), const Offset(-400, 0), 2000);
      await tester.pumpAndSettle();
      expect(repo.deletedIds, isEmpty, reason: 'no food was deleted');
      expect(find.text('the next tab'), findsOneWidget);
    });

    testWidgets('a right swipe over a row goes back a tab (the row does not '
        'take it)', (tester) async {
      bigScreen(tester);
      final FakePantryRepository repo = pantry();
      await tester.pumpWidget(
        host(
          repo,
          SwipeTabs(
            index: 1,
            onIndexChanged: (_) {},
            children: const <Widget>[
              Center(child: Text('the previous tab')),
              PantryScreen(),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.fling(find.text('Milk'), const Offset(400, 0), 2000);
      await tester.pumpAndSettle();
      expect(find.text('the previous tab'), findsOneWidget);
      expect(repo.deletedIds, isEmpty);
    });

    testWidgets('the same swipe with item swipes on deletes instead (the '
        'person chose that)', (tester) async {
      bigScreen(tester);
      final FakePantryRepository repo = pantry();
      await tester.pumpWidget(tabs(repo, swipeDelete: true));
      await tester.pumpAndSettle();
      await tester.fling(find.text('Milk'), const Offset(-400, 0), 2000);
      await tester.pumpAndSettle();
      expect(repo.deletedIds, <String>['i2']);
    });

    testWidgets('with tab swiping off, the page stays put', (tester) async {
      bigScreen(tester);
      final FakePantryRepository repo = pantry();
      await tester.pumpWidget(tabs(repo, enabled: false));
      await tester.pumpAndSettle();
      await tester.fling(find.text('Milk'), const Offset(-400, 0), 2000);
      await tester.pumpAndSettle();
      expect(find.text('the next tab'), findsNothing);
      expect(repo.deletedIds, isEmpty);
    });
  });
}
