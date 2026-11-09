import 'package:akshaya/core/design/tokens/status_kind.dart';
import 'package:akshaya/features/pantry/domain/consumption_type.dart';
import 'package:akshaya/features/pantry/domain/entities.dart';
import 'package:akshaya/features/pantry/domain/stock_logic.dart';
import 'package:akshaya/features/pantry/domain/storage_location.dart';
import 'package:akshaya/features/pantry/domain/unit.dart';
import 'package:akshaya/features/report/domain/report_bundle.dart';
import 'package:akshaya/features/report/domain/report_models.dart';

import '../../pantry/domain/test_data.dart';

final DateTime reportToday = DateTime(2026, 11, 4);

ItemStock reportStock(
  Item item, {
  StatusKind status = StatusKind.fresh,
  double left = 1,
}) {
  return ItemStock(
    item: item,
    batches: const <StockBatch>[],
    totalRemaining: left,
    nearestExpiry: null,
    daysToExpiry: null,
    status: status,
    primaryLocation: StorageLocation.pantry,
  );
}

final List<ItemStock> reportStocks = <ItemStock>[
  reportStock(makeItem(id: 'rice', name: 'Basmati Rice')),
  reportStock(makeItem(id: 'dal', name: 'Toor Dal', categoryId: 'cat_dals')),
  reportStock(
    makeItem(id: 'tomato', name: 'Tomato', categoryId: 'cat_vegetables'),
  ),
  reportStock(
    makeItem(
      id: 'banana',
      name: 'Banana',
      unit: Unit.pcs,
      categoryId: 'cat_fruits',
    ),
  ),
  reportStock(
    makeItem(id: 'curd', name: 'Curd', unit: Unit.g, categoryId: 'cat_dairy'),
  ),
  reportStock(
    makeItem(
      id: 'eggs',
      name: 'Eggs',
      unit: Unit.pcs,
      categoryId: 'cat_meat_eggs',
    ),
  ),
  reportStock(
    makeItem(
      id: 'onion',
      name: 'Onion',
      unit: Unit.g,
      categoryId: 'cat_vegetables',
    ),
  ),
  reportStock(
    makeItem(
      id: 'okra',
      name: 'Okra',
      unit: Unit.g,
      categoryId: 'cat_vegetables',
    ),
    status: StatusKind.expiring,
  ),
];

ConsumptionEntry reportUsed(
  String itemId,
  double qty,
  Unit unit, {
  int daysAgo = 0,
}) {
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

List<ConsumptionEntry> fullDayEntries(int daysAgo) => <ConsumptionEntry>[
  reportUsed('rice', 300, Unit.g, daysAgo: daysAgo),
  reportUsed('dal', 100, Unit.g, daysAgo: daysAgo),
  reportUsed('tomato', 200, Unit.g, daysAgo: daysAgo),
  reportUsed('banana', 2, Unit.pcs, daysAgo: daysAgo),
  reportUsed('curd', 200, Unit.g, daysAgo: daysAgo),
];

ReportBundle bundleFor(
  List<ConsumptionEntry> history, {
  ReportPeriod period = ReportPeriod.week,
  int people = 2,
  bool vegetarian = true,
}) {
  return buildReportBundle(
    period: period,
    today: reportToday,
    history: history,
    itemsById: <String, Item>{
      for (final ItemStock s in reportStocks) s.item.id: s.item,
    },
    people: people,
    vegetarian: vegetarian,
    stocks: reportStocks,
  );
}

/// A week of eating with a few gaps, so there is plenty to show.
ReportBundle fullWeekBundle() => bundleFor(<ConsumptionEntry>[
  ...fullDayEntries(0),
  ...fullDayEntries(1),
  for (int d = 2; d < 6; d++) ...<ConsumptionEntry>[
    reportUsed('rice', 300, Unit.g, daysAgo: d),
    reportUsed('dal', 100, Unit.g, daysAgo: d),
  ],
  // The week before, for the comparison.
  reportUsed('rice', 200, Unit.g, daysAgo: 9),
  reportUsed('dal', 80, Unit.g, daysAgo: 9),
]);

ReportBundle emptyBundle() => bundleFor(const <ConsumptionEntry>[]);
