import 'package:akshaya/features/forecast/domain/consumption_forecast.dart';
import 'package:akshaya/features/forecast/domain/purchase_history.dart';
import 'package:akshaya/features/forecast/domain/what_to_buy.dart';
import 'package:akshaya/features/pantry/domain/consumption_type.dart';
import 'package:akshaya/features/pantry/domain/entities.dart';
import 'package:akshaya/features/pantry/domain/stock_logic.dart';
import 'package:akshaya/features/pantry/domain/unit.dart';
import 'package:akshaya/features/shopping/domain/shopping_entities.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../pantry/domain/test_data.dart';
import '../../shopping/domain/shopping_test_data.dart';

ItemForecast ready(Item item, {required double perDay, required double left}) {
  return ItemForecast(
    item: item,
    state: ForecastState.ready,
    dataPoints: 5,
    remaining: left,
    perDay: perDay,
    daysLeft: (left / perDay).floor(),
  );
}

ItemStock stockOf(Item item, List<StockBatch> batches) {
  return StockLogic.summarize(
    ItemWithBatches(item: item, batches: batches),
    today: kToday,
    warningDays: 3,
  );
}

void main() {
  final Item rice = makeItem();

  test('usual pack is the most common recent amount', () {
    final double pack = PurchaseHistory.usualPackSize(rice, <StockBatch>[
      makeBatch(id: 'a', bought: 5, purchase: DateTime(2026, 9, 1)),
      makeBatch(id: 'b', bought: 1, purchase: DateTime(2026, 10, 1)),
      makeBatch(id: 'c', bought: 1, purchase: DateTime(2026, 10, 10)),
    ]);
    expect(pack, 1);
  });

  test('a tie goes to the latest purchase', () {
    final double pack = PurchaseHistory.usualPackSize(rice, <StockBatch>[
      makeBatch(id: 'a', bought: 5, purchase: DateTime(2026, 9, 1)),
      makeBatch(id: 'b', bought: 2, purchase: DateTime(2026, 10, 1)),
    ]);
    expect(pack, 2);
  });

  test('count-mode batches are not purchases', () {
    final double pack = PurchaseHistory.usualPackSize(
      rice,
      <StockBatch>[
        makeBatch(id: 'a', bought: 5, purchase: DateTime(2026, 9, 1)),
        makeBatch(id: 'b', bought: 3, purchase: DateTime(2026, 10, 1)),
      ],
      excludedBatchIds: <String>{'b'},
    );
    expect(pack, 5);
  });

  test('never bought falls back to one unit', () {
    expect(PurchaseHistory.usualPackSize(rice, const <StockBatch>[]), 1);
  });

  test('adjustment batch ids come from negative adjustment logs', () {
    final Set<String> ids = PurchaseHistory.adjustmentBatchIds(
      <ConsumptionEntry>[
        ConsumptionEntry(
          id: 'l1',
          batchId: 'surplus',
          itemId: 'i1',
          quantityUsed: -1,
          unit: Unit.kg,
          date: kToday,
          type: ConsumptionType.adjustment,
        ),
        ConsumptionEntry(
          id: 'l2',
          batchId: 'normal',
          itemId: 'i1',
          quantityUsed: 1,
          unit: Unit.kg,
          date: kToday,
          type: ConsumptionType.adjustment,
        ),
      ],
    );
    expect(ids, <String>{'surplus'});
  });

  test('suggests whole packs that cover the period', () {
    final ItemStock stock = stockOf(rice, <StockBatch>[
      makeBatch(bought: 2, purchase: DateTime(2026, 10, 1)),
    ]);
    // 0.5/day, 2 kg left: 4 days. Cover 14 days = 7 kg, need 5 kg, packs of 2.
    final List<BuyRecommendation> out = WhatToBuy.compute(
      stocks: <ItemStock>[stock],
      forecasts: <String, ItemForecast>{
        'i1': ready(rice, perDay: 0.5, left: 2),
      },
      entries: const <ShoppingEntry>[],
    );
    expect(out.single.packSize, 2);
    expect(out.single.quantity, 6);
  });

  test('buys at least one pack', () {
    final ItemStock stock = stockOf(rice, <StockBatch>[
      makeBatch(bought: 5, purchase: DateTime(2026, 10, 1)),
    ]);
    final List<BuyRecommendation> out = WhatToBuy.compute(
      stocks: <ItemStock>[stock],
      forecasts: <String, ItemForecast>{
        'i1': ready(rice, perDay: 0.1, left: 0.5),
      },
      entries: const <ShoppingEntry>[],
    );
    expect(out.single.quantity, 5);
  });

  test('horizon limits the list and learning items are skipped', () {
    final Item dal = makeItem(id: 'i2', name: 'Toor Dal');
    final Item oil = makeItem(id: 'i3', name: 'Oil');
    final List<ItemStock> stocks = <ItemStock>[
      stockOf(rice, <StockBatch>[makeBatch()]),
      stockOf(dal, <StockBatch>[makeBatch(id: 'b2', itemId: 'i2')]),
      stockOf(oil, <StockBatch>[makeBatch(id: 'b3', itemId: 'i3')]),
    ];
    final Map<String, ItemForecast> forecasts = <String, ItemForecast>{
      'i1': ready(rice, perDay: 1, left: 3),
      'i2': ready(dal, perDay: 1, left: 20),
      'i3': ItemForecast(
        item: oil,
        state: ForecastState.learning,
        dataPoints: 1,
        remaining: 1,
      ),
    };
    expect(
      WhatToBuy.compute(stocks: stocks, forecasts: forecasts, entries: const [])
          .map((BuyRecommendation r) => r.item.id),
      <String>['i1'],
    );
    expect(
      WhatToBuy.compute(
        stocks: stocks,
        forecasts: forecasts,
        entries: const <ShoppingEntry>[],
        horizonDays: 30,
      ).map((BuyRecommendation r) => r.item.id),
      <String>['i1', 'i2'],
    );
  });

  test('items already on a list are not repeated', () {
    final ItemStock stock = stockOf(rice, <StockBatch>[makeBatch()]);
    final Map<String, ItemForecast> forecasts = <String, ItemForecast>{
      'i1': ready(rice, perDay: 1, left: 3),
    };
    expect(
      WhatToBuy.compute(
        stocks: <ItemStock>[stock],
        forecasts: forecasts,
        entries: <ShoppingEntry>[makeEntry(itemId: 'i1')],
      ),
      isEmpty,
    );
    expect(
      WhatToBuy.compute(
        stocks: <ItemStock>[stock],
        forecasts: forecasts,
        entries: <ShoppingEntry>[makeEntry(name: ' rice ')],
      ),
      isEmpty,
    );
  });

  test('toDraft uses the low stock reason', () {
    final ItemStock stock = stockOf(rice, <StockBatch>[makeBatch()]);
    final BuyRecommendation r = WhatToBuy.compute(
      stocks: <ItemStock>[stock],
      forecasts: <String, ItemForecast>{
        'i1': ready(rice, perDay: 1, left: 3),
      },
      entries: const <ShoppingEntry>[],
    ).single;
    final ShoppingEntryDraft draft = r.toDraft('list1');
    expect(draft.listId, 'list1');
    expect(draft.itemId, 'i1');
    expect(draft.quantity, r.quantity);
  });
}
