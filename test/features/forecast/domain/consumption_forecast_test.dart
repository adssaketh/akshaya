import 'package:akshaya/features/forecast/domain/consumption_forecast.dart';
import 'package:akshaya/features/pantry/domain/consumption_type.dart';
import 'package:akshaya/features/pantry/domain/entities.dart';
import 'package:akshaya/features/pantry/domain/item_kind.dart';
import 'package:akshaya/features/pantry/domain/unit.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../pantry/domain/test_data.dart';

ConsumptionEntry use(
  int daysAgo,
  double qty, {
  ConsumptionType type = ConsumptionType.used,
  Unit unit = Unit.kg,
  String itemId = 'i1',
}) {
  return ConsumptionEntry(
    id: 'l$daysAgo-$qty-${type.name}',
    batchId: 'b1',
    itemId: itemId,
    quantityUsed: qty,
    unit: unit,
    date: DateTime(2026, 11, 4 - daysAgo),
    type: type,
  );
}

ItemWithBatches rice({double remaining = 5, DateTime? expiry}) {
  return ItemWithBatches(
    item: makeItem(),
    batches: <StockBatch>[
      makeBatch(bought: 10, remaining: remaining, expiry: expiry),
    ],
  );
}

void main() {
  test('fewer than three days of use is still learning', () {
    final ItemForecast f = ConsumptionForecast.forItem(
      rice(),
      <ConsumptionEntry>[use(10, 1), use(5, 1)],
      kToday,
    );
    expect(f.state, ForecastState.learning);
    expect(f.dataPoints, 2);
    expect(f.daysLeft, isNull);
    expect(f.label, 'Learning your usage');
  });

  test('a short span is still learning', () {
    final ItemForecast f = ConsumptionForecast.forItem(
      rice(),
      <ConsumptionEntry>[use(3, 1), use(2, 1), use(1, 1)],
      kToday,
    );
    expect(f.isReady, isFalse);
  });

  test('steady daily use gives the exact rate', () {
    final ItemForecast f = ConsumptionForecast.forItem(
      rice(remaining: 5),
      <ConsumptionEntry>[for (int d = 1; d <= 10; d++) use(d, 0.5)],
      kToday,
    );
    expect(f.isReady, isTrue);
    expect(f.perDay, closeTo(0.5, 0.0001));
    // Float rounding can land on 9 or 10.
    expect(f.daysLeft, inInclusiveRange(9, 10));
    expect(f.label, startsWith('Runs out in ~'));
  });

  test('recent weeks weigh more than old ones', () {
    final List<ConsumptionEntry> faster = <ConsumptionEntry>[
      for (int d = 1; d <= 7; d++) use(d, 1),
      for (int d = 40; d <= 46; d++) use(d, 0.1),
    ];
    final List<ConsumptionEntry> slower = <ConsumptionEntry>[
      for (int d = 1; d <= 7; d++) use(d, 0.1),
      for (int d = 40; d <= 46; d++) use(d, 1),
    ];
    final ItemForecast a =
        ConsumptionForecast.forItem(rice(), faster, kToday);
    final ItemForecast b =
        ConsumptionForecast.forItem(rice(), slower, kToday);
    expect(a.perDay, greaterThan(b.perDay));
  });

  test('one huge day is left out', () {
    final List<ConsumptionEntry> logs = <ConsumptionEntry>[
      for (int d = 1; d <= 8; d++) use(d, 0.5),
      use(9, 20),
    ];
    final ItemForecast f =
        ConsumptionForecast.forItem(rice(), logs, kToday);
    expect(f.perDay, closeTo(0.5, 0.0001));
  });

  test('waste, expiry and adjustments are not use', () {
    final List<ConsumptionEntry> logs = <ConsumptionEntry>[
      use(10, 1, type: ConsumptionType.wasted),
      use(8, 1, type: ConsumptionType.expired),
      use(6, 1, type: ConsumptionType.adjustment),
      use(4, 1, type: ConsumptionType.givenAway),
      use(2, 1),
    ];
    final ItemForecast f =
        ConsumptionForecast.forItem(rice(), logs, kToday);
    expect(f.dataPoints, 1);
    expect(f.isReady, isFalse);
  });

  test('cooked in recipe counts as use', () {
    final List<ConsumptionEntry> logs = <ConsumptionEntry>[
      for (int d = 1; d <= 9; d += 2)
        use(d, 0.5, type: ConsumptionType.cookedInRecipe),
    ];
    final ItemForecast f =
        ConsumptionForecast.forItem(rice(), logs, kToday);
    expect(f.isReady, isTrue);
  });

  test('units are converted to the item unit', () {
    final ItemForecast f = ConsumptionForecast.forItem(
      rice(remaining: 5),
      <ConsumptionEntry>[
        for (int d = 1; d <= 10; d++) use(d, 500, unit: Unit.g),
      ],
      kToday,
    );
    expect(f.perDay, closeTo(0.5, 0.0001));
  });

  test('expired batches are not usable stock', () {
    final ItemForecast f = ConsumptionForecast.forItem(
      rice(remaining: 5, expiry: DateTime(2026, 11, 1)),
      <ConsumptionEntry>[for (int d = 1; d <= 10; d++) use(d, 0.5)],
      kToday,
    );
    expect(f.isOut, isTrue);
    expect(f.daysLeft, 0);
    expect(f.label, 'Out of stock');
  });

  test('only stocked items get a forecast', () {
    final Map<String, ItemForecast> all = ConsumptionForecast.forAll(
      <ItemWithBatches>[
        rice(),
        ItemWithBatches(
          item: makeItem(id: 'i2', name: 'Sambar', kind: ItemKind.cooked),
          batches: const <StockBatch>[],
        ),
      ],
      const <ConsumptionEntry>[],
      kToday,
    );
    expect(all.keys, <String>['i1']);
  });

  test('runningOut lists ready items soonest first', () {
    final Map<String, ItemForecast> all = ConsumptionForecast.forAll(
      <ItemWithBatches>[rice(remaining: 5)],
      <ConsumptionEntry>[for (int d = 1; d <= 10; d++) use(d, 0.5)],
      kToday,
    );
    expect(
      ConsumptionForecast.runningOut(all).single.daysLeft,
      inInclusiveRange(9, 10),
    );
  });
}
