import 'package:akshaya/features/insights/domain/waste_cost.dart';
import 'package:akshaya/features/pantry/domain/consumption_type.dart';
import 'package:akshaya/features/pantry/domain/entities.dart';
import 'package:akshaya/features/pantry/domain/waste_reason.dart';
import 'package:flutter_test/flutter_test.dart';

import '../pantry/domain/test_data.dart';

ConsumptionEntry log(
  String id,
  ConsumptionType type, {
  double qty = 1,
  DateTime? date,
  WasteReason? reason,
}) {
  return ConsumptionEntry(
    id: id,
    batchId: 'b1',
    itemId: 'i1',
    quantityUsed: qty,
    unit: makeBatch().unit,
    date: date ?? DateTime(2026, 11, 2),
    type: type,
    wasteReason: reason,
  );
}

void main() {
  final List<ItemWithBatches> records = <ItemWithBatches>[
    ItemWithBatches(
      item: makeItem(),
      batches: <StockBatch>[
        StockBatch(
          id: 'b1',
          itemId: 'i1',
          quantityBought: 4,
          quantityRemaining: 2,
          unit: makeBatch().unit,
          purchaseDate: DateTime(2026, 10, 1),
          expiryDate: DateTime(2026, 11, 5),
          storageLocation: makeBatch().storageLocation,
          price: 100,
          createdAt: DateTime(2026, 10, 1),
        ),
      ],
    ),
  ];
  final DateTime month = DateTime(2026, 11);

  test('byReason splits waste, old expired logs count as expired', () {
    final List<ReasonWaste> out = WasteCost.byReason(
      records,
      <ConsumptionEntry>[
        log('1', ConsumptionType.expired),
        log('2', ConsumptionType.wasted, reason: WasteReason.spoiled, qty: 2),
        log('3', ConsumptionType.wasted),
        log('4', ConsumptionType.used),
        log('5', ConsumptionType.wasted, date: DateTime(2026, 10, 2)),
      ],
      month,
    );
    expect(out.first.reason, WasteReason.spoiled);
    expect(out.first.value, 50);
    final Map<WasteReason, int> counts = <WasteReason, int>{
      for (final ReasonWaste r in out) r.reason: r.count,
    };
    expect(counts, <WasteReason, int>{
      WasteReason.spoiled: 1,
      WasteReason.expired: 1,
      WasteReason.unspecified: 1,
    });
  });

  test('moneySaved counts uses inside the warning window only', () {
    final MoneySaved s = WasteCost.moneySaved(
      records: records,
      logs: <ConsumptionEntry>[
        log('1', ConsumptionType.used, date: DateTime(2026, 11, 3)),
        log('2', ConsumptionType.cookedInRecipe,
            date: DateTime(2026, 11, 5), qty: 2),
        log('3', ConsumptionType.used, date: DateTime(2026, 10, 20)),
        log('4', ConsumptionType.used, date: DateTime(2026, 11, 6)),
        log('5', ConsumptionType.wasted, date: DateTime(2026, 11, 3)),
      ],
      month: month,
      warningDays: 3,
    );
    expect(s.uses, 2);
    expect(s.value, 75);
    expect(s.itemCount, 1);
    expect(s.topItems.single.name, 'Rice');
    expect(s.isEmpty, isFalse);
  });
}
