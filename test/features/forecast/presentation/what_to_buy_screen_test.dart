import 'package:akshaya/core/design/design.dart';
import 'package:akshaya/core/time/clock.dart';
import 'package:akshaya/features/forecast/presentation/what_to_buy_screen.dart';
import 'package:akshaya/features/pantry/domain/consumption_type.dart';
import 'package:akshaya/features/pantry/domain/entities.dart';
import 'package:akshaya/features/pantry/domain/unit.dart';
import 'package:akshaya/features/pantry/presentation/providers.dart';
import 'package:akshaya/features/settings/presentation/providers.dart';
import 'package:akshaya/features/shopping/domain/shopping_enums.dart';
import 'package:akshaya/features/shopping/presentation/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../pantry/domain/test_data.dart';
import '../../pantry/presentation/fake_repository.dart';
import '../../settings/fake_settings_repository.dart';
import '../../shopping/presentation/fake_shopping_repository.dart';

void main() {
  void bigScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  FakePantryRepository pantryWithUse() {
    return FakePantryRepository(
      items: <ItemWithBatches>[
        ItemWithBatches(
          item: makeItem(),
          batches: <StockBatch>[
            makeBatch(bought: 2, purchase: DateTime(2026, 10, 1)),
          ],
        ),
      ],
      history: <ConsumptionEntry>[
        for (int d = 1; d <= 10; d++)
          ConsumptionEntry(
            id: 'l$d',
            batchId: 'b1',
            itemId: 'i1',
            quantityUsed: 0.5,
            unit: Unit.kg,
            date: DateTime(2026, 11, 4 - d),
            type: ConsumptionType.used,
          ),
      ],
    );
  }

  Widget host(FakeShoppingRepository shopping, FakePantryRepository pantry) {
    return ProviderScope(
      overrides: [
        shoppingRepositoryProvider.overrideWithValue(shopping),
        pantryRepositoryProvider.overrideWithValue(pantry),
        settingsRepositoryProvider.overrideWithValue(FakeSettingsRepository()),
        clockProvider.overrideWithValue(() => DateTime(2026, 11, 4, 10)),
      ],
      child: MaterialApp(
        theme: AkshayaTheme.light(),
        home: const WhatToBuyScreen(),
      ),
    );
  }

  testWidgets('adds the ticked items to the list', (WidgetTester tester) async {
    bigScreen(tester);
    final FakeShoppingRepository shopping = FakeShoppingRepository();
    await tester.pumpWidget(host(shopping, pantryWithUse()));
    await tester.pumpAndSettle();

    expect(find.text('Rice'), findsOneWidget);
    expect(find.text('Add 1 to the list'), findsOneWidget);

    await tester.tap(find.text('Add 1 to the list'));
    await tester.pumpAndSettle();

    expect(shopping.addedDrafts, hasLength(1));
    expect(shopping.addedDrafts.single.itemId, 'i1');
    expect(shopping.addedDrafts.single.addedReason, AddedReason.lowStock);
    // Once listed, it drops off the screen.
    expect(find.text('Rice'), findsNothing);
  });

  testWidgets('unticking leaves nothing to add', (WidgetTester tester) async {
    bigScreen(tester);
    final FakeShoppingRepository shopping = FakeShoppingRepository();
    await tester.pumpWidget(host(shopping, pantryWithUse()));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    expect(find.textContaining('Add '), findsNothing);
    expect(shopping.addedDrafts, isEmpty);
  });

  testWidgets('explains an empty result', (WidgetTester tester) async {
    bigScreen(tester);
    await tester.pumpWidget(
      host(FakeShoppingRepository(), FakePantryRepository()),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Nothing is predicted'), findsOneWidget);
  });
}
