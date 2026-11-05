import 'package:akshaya/features/pantry/domain/entities.dart';
import 'package:akshaya/features/pantry/domain/stock_logic.dart';
import 'package:akshaya/features/rescue/domain/food_rescue.dart';
import 'package:akshaya/features/rescue/domain/freeze_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../pantry/domain/test_data.dart';

ItemStock stockOf(Item item, List<StockBatch> batches) {
  return StockLogic.summarize(
    ItemWithBatches(item: item, batches: batches),
    today: kToday,
    warningDays: 3,
  );
}

List<RescueEntry> build(List<ItemStock> stocks) => FoodRescue.build(
      stocks: stocks,
      today: kToday,
      warningDays: 3,
      freeze: const FreezeSettings(),
    );

void main() {
  test('groups batches by urgency, once each', () {
    final List<RescueEntry> out = build(<ItemStock>[
      stockOf(makeItem(id: 'a', name: 'Milk'), <StockBatch>[
        makeBatch(id: 'a1', itemId: 'a', expiry: DateTime(2026, 11, 3)),
        makeBatch(id: 'a2', itemId: 'a', expiry: DateTime(2026, 11, 4)),
        makeBatch(id: 'a3', itemId: 'a', expiry: DateTime(2026, 11, 6)),
        makeBatch(id: 'a4', itemId: 'a', expiry: DateTime(2027, 6, 1)),
      ]),
    ]);
    expect(
      out.map((RescueEntry e) => '${e.batch.id}:${e.group.name}').toList(),
      <String>['a1:expired', 'a2:today', 'a3:soon'],
    );
    expect(out.first.isExpired, isTrue);
    expect(out.first.canFreeze, isFalse);
    expect(out[1].canFreeze, isTrue);
  });

  test('opened packs further out appear as opened', () {
    final List<RescueEntry> out = build(<ItemStock>[
      stockOf(makeItem(id: 'a'), <StockBatch>[
        makeBatch(
          id: 'a1',
          itemId: 'a',
          expiry: DateTime(2027, 6, 1),
          opened: DateTime(2026, 11, 1),
        ),
      ]),
    ]);
    expect(out.single.group, RescueGroup.opened);
    expect(out.single.openedDaysAgo, 3);
  });

  test('nothing to rescue when all is fresh or empty', () {
    expect(
      build(<ItemStock>[
        stockOf(makeItem(), <StockBatch>[
          makeBatch(expiry: DateTime(2027, 6, 1)),
          makeBatch(id: 'b2', remaining: 0, expiry: DateTime(2026, 11, 4)),
        ]),
      ]),
      isEmpty,
    );
  });
}
