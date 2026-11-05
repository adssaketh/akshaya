import 'package:akshaya/core/design/design.dart';
import 'package:akshaya/features/pantry/domain/entities.dart';
import 'package:akshaya/features/pantry/presentation/add_item_screen.dart';
import 'package:akshaya/features/pantry/presentation/pantry_screen.dart';
import 'package:akshaya/features/pantry/presentation/providers.dart';
import 'package:akshaya/features/settings/presentation/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../domain/test_data.dart';
import '../../settings/fake_settings_repository.dart';
import 'fake_repository.dart';

Widget host(FakePantryRepository repo, Widget home) {
  return ProviderScope(
    overrides: [
      pantryRepositoryProvider.overrideWithValue(repo),
      settingsRepositoryProvider.overrideWithValue(FakeSettingsRepository()),
    ],
    child: MaterialApp(theme: AkshayaTheme.light(), home: home),
  );
}

void main() {
  void bigScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('pantry shows the empty state', (WidgetTester tester) async {
    bigScreen(tester);
    await tester.pumpWidget(host(FakePantryRepository(), const PantryScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Your pantry is empty'), findsOneWidget);
  });

  testWidgets('pantry lists items, finds them by alias, shows no-match',
      (WidgetTester tester) async {
    bigScreen(tester);
    final FakePantryRepository repo = FakePantryRepository(
      items: <ItemWithBatches>[
        ItemWithBatches(
          item: makeItem(
            name: 'Basmati Rice',
            aliases: <String>['బియ్యం', 'chawal'],
          ),
          batches: <StockBatch>[makeBatch(bought: 5)],
        ),
        ItemWithBatches(
          item: makeItem(id: 'i2', name: 'Milk', categoryId: 'cat_dairy'),
          batches: <StockBatch>[makeBatch(id: 'b2', itemId: 'i2', bought: 1)],
        ),
      ],
    );
    await tester.pumpWidget(host(repo, const PantryScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Basmati Rice'), findsOneWidget);
    expect(find.text('Milk'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'chawal');
    await tester.pumpAndSettle();
    expect(find.text('Basmati Rice'), findsOneWidget);
    expect(find.text('Milk'), findsNothing);

    await tester.enterText(find.byType(TextField).first, 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('No matches'), findsOneWidget);
  });

  testWidgets('add item saves the item and its first batch',
      (WidgetTester tester) async {
    bigScreen(tester);
    final FakePantryRepository repo = FakePantryRepository();
    await tester.pumpWidget(host(repo, const AddItemScreen()));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Item name'),
      'Jaggery',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Quantity'),
      '2',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(repo.addedItems.single.name, 'Jaggery');
    expect(repo.addedBatches.single.quantityBought, 2);
    expect(repo.addedBatches.single.itemId, 'new-1');
  });

  testWidgets('add item requires a name', (WidgetTester tester) async {
    bigScreen(tester);
    final FakePantryRepository repo = FakePantryRepository();
    await tester.pumpWidget(host(repo, const AddItemScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(repo.addedItems, isEmpty);
  });
}
