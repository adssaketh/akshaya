import 'package:akshaya/features/pantry/domain/entities.dart';
import 'package:akshaya/features/pantry/domain/fifo.dart';
import 'package:akshaya/features/pantry/domain/unit.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_data.dart';

void main() {
  test('uses the earliest-expiring batch first', () {
    final FifoPlan plan = Fifo.plan(
      batches: <StockBatch>[
        makeBatch(id: 'late', bought: 2, expiry: DateTime(2026, 12, 30)),
        makeBatch(id: 'soon', bought: 2, expiry: DateTime(2026, 11, 10)),
      ],
      quantity: 1,
      unit: Unit.kg,
    );
    expect(plan.deductions.map((Deduction d) => d.batchId), <String>['soon']);
    expect(plan.isComplete, isTrue);
  });

  test('spans batches when the first is not enough', () {
    final FifoPlan plan = Fifo.plan(
      batches: <StockBatch>[
        makeBatch(id: 'a', bought: 1, expiry: DateTime(2026, 11, 10)),
        makeBatch(id: 'b', bought: 2, expiry: DateTime(2026, 12, 1)),
      ],
      quantity: 2.5,
      unit: Unit.kg,
    );
    expect(plan.deductions.length, 2);
    expect(plan.deductions[0].amount, 1);
    expect(plan.deductions[1].amount, 1.5);
    expect(plan.shortfall, 0);
  });

  test('batches without expiry come last', () {
    final List<StockBatch> ordered = Fifo.order(<StockBatch>[
      makeBatch(id: 'none'),
      makeBatch(id: 'dated', expiry: DateTime(2027, 1, 1)),
    ]);
    expect(ordered.map((StockBatch b) => b.id), <String>['dated', 'none']);
  });

  test('ties break on purchase date', () {
    final List<StockBatch> ordered = Fifo.order(<StockBatch>[
      makeBatch(id: 'new', purchase: DateTime(2026, 10, 20)),
      makeBatch(id: 'old', purchase: DateTime(2026, 10, 2)),
    ]);
    expect(ordered.first.id, 'old');
  });

  test('converts units: 500 g from a kg batch', () {
    final FifoPlan plan = Fifo.plan(
      batches: <StockBatch>[makeBatch(bought: 1)],
      quantity: 500,
      unit: Unit.g,
    );
    expect(plan.deductions.single.amount, 0.5);
    expect(plan.deductions.single.unit, Unit.kg);
  });

  test('reports shortfall', () {
    final FifoPlan plan = Fifo.plan(
      batches: <StockBatch>[makeBatch(bought: 1)],
      quantity: 3,
      unit: Unit.kg,
    );
    expect(plan.isComplete, isFalse);
    expect(plan.shortfall, 2);
  });

  test('skips incompatible units and empty batches', () {
    final FifoPlan plan = Fifo.plan(
      batches: <StockBatch>[
        makeBatch(id: 'empty', remaining: 0),
        makeBatch(id: 'litres', unit: Unit.l),
      ],
      quantity: 1,
      unit: Unit.kg,
    );
    expect(plan.deductions, isEmpty);
    expect(plan.shortfall, 1);
  });
}
