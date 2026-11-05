import 'package:akshaya/features/insights/domain/insights.dart';
import 'package:akshaya/features/pantry/domain/consumption_type.dart';
import 'package:akshaya/features/pantry/domain/entities.dart';
import 'package:akshaya/features/pantry/domain/storage_location.dart';
import 'package:akshaya/features/pantry/domain/unit.dart';
import 'package:flutter_test/flutter_test.dart';

import '../pantry/domain/test_data.dart';

StockBatch batch(
  String id,
  String itemId, {
  required DateTime purchase,
  double bought = 1,
  double? price,
  String? store,
}) {
  return StockBatch(
    id: id,
    itemId: itemId,
    quantityBought: bought,
    quantityRemaining: bought,
    unit: Unit.kg,
    purchaseDate: purchase,
    storageLocation: StorageLocation.pantry,
    createdAt: purchase,
    price: price,
    store: store,
  );
}

ConsumptionEntry log(
  String id,
  String batchId,
  String itemId,
  DateTime date,
  double qty,
  ConsumptionType type,
) {
  return ConsumptionEntry(
    id: id,
    batchId: batchId,
    itemId: itemId,
    quantityUsed: qty,
    unit: Unit.kg,
    date: date,
    type: type,
  );
}

void main() {
  final Item rice = makeItem();
  final Item dal = makeItem(id: 'i2', name: 'Toor Dal', categoryId: 'cat_dals');
  const List<Category> cats = <Category>[
    Category(id: 'cat_grains', name: 'Grains & Rice', iconKey: 'grains', sortOrder: 1),
    Category(id: 'cat_dals', name: 'Dals & Pulses', iconKey: 'dals', sortOrder: 2),
  ];

  final List<ItemWithBatches> records = <ItemWithBatches>[
    ItemWithBatches(item: rice, batches: <StockBatch>[
      batch('b1', 'i1', purchase: DateTime(2026, 11, 2), price: 100, store: 'DMart'),
      batch('b2', 'i1', purchase: DateTime(2026, 10, 5), price: 90, store: 'Ratnadeep'),
    ]),
    ItemWithBatches(item: dal, batches: <StockBatch>[
      batch('b3', 'i2', purchase: DateTime(2026, 11, 3), price: 150),
      batch('b4', 'i2', purchase: DateTime(2026, 11, 3)),
    ]),
  ];

  test('spend in a month adds only priced batches of that month', () {
    expect(Insights.spendInMonth(records, DateTime(2026, 11)), 250);
    expect(Insights.spendInMonth(records, DateTime(2026, 10)), 90);
    expect(Insights.spendInMonth(records, DateTime(2026, 9)), 0);
  });

  test('spend by category is sorted, biggest first', () {
    final List<CategorySpend> out =
        Insights.spendByCategory(records, cats, DateTime(2026, 11));
    expect(out.map((CategorySpend c) => c.name), <String>[
      'Dals & Pulses',
      'Grains & Rice',
    ]);
    expect(out.first.amount, 150);
  });

  test('monthly spend runs oldest to newest and ends at the last month', () {
    final List<MonthTotal> out =
        Insights.monthlySpend(records, DateTime(2026, 11, 20), months: 3);
    expect(out.length, 3);
    expect(out.first.month, DateTime(2026, 9));
    expect(out.last.month, DateTime(2026, 11));
    expect(out.map((MonthTotal m) => m.amount), <double>[0, 90, 250]);
  });

  test('waste report values a loss by the share of the batch', () {
    final WasteReport report = Insights.wasteReport(
      records,
      <ConsumptionEntry>[
        log('l1', 'b1', 'i1', DateTime(2026, 11, 3), 0.5, ConsumptionType.wasted),
        log('l2', 'b1', 'i1', DateTime(2026, 11, 4), 0.25, ConsumptionType.expired),
        log('l3', 'b1', 'i1', DateTime(2026, 11, 4), 0.25, ConsumptionType.used),
        log('l4', 'b1', 'i1', DateTime(2026, 10, 4), 1, ConsumptionType.wasted),
      ],
      DateTime(2026, 11),
    );
    expect(report.entries, 2);
    expect(report.value, closeTo(75, 0.001));
    expect(report.topItems.single.name, 'Rice');
  });

  test('run-out estimate needs enough history', () {
    final List<RunOutEstimate> none = Insights.runOutEstimates(
      <ItemWithBatches>[
        ItemWithBatches(item: rice, batches: <StockBatch>[
          batch('b1', 'i1', purchase: DateTime(2026, 11, 1), bought: 5),
        ]),
      ],
      <ConsumptionEntry>[
        log('l1', 'b1', 'i1', DateTime(2026, 11, 2), 0.5, ConsumptionType.used),
      ],
      kToday,
    );
    expect(none, isEmpty);
  });

  test('run-out estimate uses real use over the span', () {
    final List<RunOutEstimate> out = Insights.runOutEstimates(
      <ItemWithBatches>[
        ItemWithBatches(item: rice, batches: <StockBatch>[
          batch('b1', 'i1', purchase: DateTime(2026, 10, 1), bought: 5),
        ]),
      ],
      <ConsumptionEntry>[
        log('l1', 'b1', 'i1', DateTime(2026, 10, 20), 0.5, ConsumptionType.used),
        log('l2', 'b1', 'i1', DateTime(2026, 10, 27), 0.5, ConsumptionType.used),
        log('l3', 'b1', 'i1', DateTime(2026, 11, 3), 0.5, ConsumptionType.used),
        log('l4', 'b1', 'i1', DateTime(2026, 11, 3), 2, ConsumptionType.wasted),
      ],
      kToday,
    );
    expect(out.single.perDay, closeTo(0.1, 0.0001));
    expect(out.single.daysLeft, 50);
    expect(out.single.label, contains('50'));
  });

  test('price history lists priced batches by date', () {
    final List<PricePoint> pts = Insights.priceHistory(records.first);
    expect(pts.length, 2);
    expect(pts.first.date.isBefore(pts.last.date), isTrue);
  });

  test('items with prices needs two prices', () {
    expect(
      Insights.itemsWithPrices(records).map((ItemWithBatches r) => r.item.id),
      <String>['i1'],
    );
  });
}
