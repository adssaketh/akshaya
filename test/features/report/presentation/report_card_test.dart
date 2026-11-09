import 'package:akshaya/core/design/design.dart';
import 'package:akshaya/core/time/clock.dart';
import 'package:akshaya/features/insights/presentation/providers.dart';
import 'package:akshaya/features/pantry/domain/consumption_type.dart';
import 'package:akshaya/features/pantry/domain/entities.dart';
import 'package:akshaya/features/pantry/domain/stock_logic.dart';
import 'package:akshaya/features/pantry/domain/storage_location.dart';
import 'package:akshaya/features/pantry/domain/unit.dart';
import 'package:akshaya/features/recipes/domain/recipe_models.dart';
import 'package:akshaya/features/recipes/presentation/providers.dart';
import 'package:akshaya/features/report/presentation/report_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../pantry/domain/test_data.dart';

class _FixedToday extends TodayNotifier {
  @override
  DateTime build() => DateTime(2026, 11, 4);
}

ItemStock stockOf(Item item) => ItemStock(
      item: item,
      batches: const <StockBatch>[],
      totalRemaining: 1,
      nearestExpiry: null,
      daysToExpiry: null,
      status: StatusKind.fresh,
      primaryLocation: StorageLocation.pantry,
    );

ConsumptionEntry used(String itemId, double qty, Unit unit, {int daysAgo = 0}) {
  return ConsumptionEntry(
    id: '$itemId-$daysAgo',
    batchId: 'b1',
    itemId: itemId,
    quantityUsed: qty,
    unit: unit,
    date: DateTime(2026, 11, 4 - daysAgo, 13),
    type: ConsumptionType.used,
  );
}

final List<ItemStock> stocks = <ItemStock>[
  stockOf(makeItem(id: 'rice', name: 'Basmati Rice')),
  stockOf(makeItem(id: 'dal', name: 'Toor Dal', categoryId: 'cat_dals')),
  stockOf(makeItem(
      id: 'tomato', name: 'Tomato', categoryId: 'cat_vegetables')),
  stockOf(makeItem(
      id: 'banana', name: 'Banana', unit: Unit.pcs, categoryId: 'cat_fruits')),
  stockOf(makeItem(
      id: 'curd', name: 'Curd', unit: Unit.g, categoryId: 'cat_dairy')),
];

final List<ConsumptionEntry> fullDay = <ConsumptionEntry>[
  used('rice', 300, Unit.g),
  used('dal', 100, Unit.g),
  used('tomato', 200, Unit.g),
  used('banana', 2, Unit.pcs),
  used('curd', 200, Unit.g),
];

void main() {
  Future<void> pump(
    WidgetTester tester,
    List<ConsumptionEntry> history, {
    double width = 400,
    double textScale = 1,
  }) async {
    tester.view.physicalSize = Size(width, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          allHistoryProvider
              .overrideWith((ref) => Stream<List<ConsumptionEntry>>.value(history)),
          recipePreferencesProvider
              .overrideWithValue(const RecipePreferences()),
          todayProvider.overrideWith(_FixedToday.new),
        ],
        child: MaterialApp(
          theme: AkshayaTheme.light(),
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
            child: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: ReportCard(stocks: stocks),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('with nothing used it says so', (WidgetTester tester) async {
    await pump(tester, const <ConsumptionEntry>[]);
    expect(find.text('Eating report'), findsOneWidget);
    expect(find.textContaining('Nothing used today yet'), findsOneWidget);
  });

  testWidgets('a full day shows calories, the verdict, the foods and a caveat',
      (WidgetTester tester) async {
    await pump(tester, fullDay);
    expect(find.textContaining('kcal'), findsWidgets);
    expect(find.text('Balanced'), findsOneWidget);
    expect(find.text('What was used'), findsOneWidget);
    expect(find.textContaining('Basmati Rice'), findsOneWidget);
    expect(find.textContaining('not medical advice'), findsOneWidget);
    expect(find.text('for 2 people'), findsOneWidget);
  });

  testWidgets('a day with no vegetables says what to try',
      (WidgetTester tester) async {
    await pump(tester, <ConsumptionEntry>[
      used('rice', 300, Unit.g),
      used('dal', 100, Unit.g),
      used('curd', 200, Unit.g),
    ]);
    expect(find.text('Try this'), findsOneWidget);
    expect(find.textContaining('vegetables'), findsWidgets);
    expect(find.text('Balanced'), findsNothing);
  });

  testWidgets('switching to 7 days shows the weekly view',
      (WidgetTester tester) async {
    await pump(tester, <ConsumptionEntry>[
      ...fullDay,
      used('rice', 300, Unit.g, daysAgo: 2),
    ]);
    expect(find.textContaining('days had food'), findsNothing);
    await tester.tap(find.text('7 days'));
    await tester.pumpAndSettle();
    expect(find.textContaining('2 of 7 days had food'), findsOneWidget);
  });

  testWidgets('fits a narrow screen with large text', (WidgetTester tester) async {
    await pump(tester, fullDay, width: 320, textScale: 1.6);
    expect(tester.takeException(), isNull);
    expect(find.text('Eating report'), findsOneWidget);
  });
}
