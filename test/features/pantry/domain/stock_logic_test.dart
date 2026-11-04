import 'package:akshaya/core/design/design.dart' show StatusKind;
import 'package:akshaya/features/pantry/domain/entities.dart';
import 'package:akshaya/features/pantry/domain/stock_logic.dart';
import 'package:akshaya/features/pantry/domain/unit.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_data.dart';

ItemStock summarize(Item item, List<StockBatch> batches) {
  return StockLogic.summarize(
    ItemWithBatches(item: item, batches: batches),
    today: kToday,
    warningDays: 3,
  );
}

void main() {
  group('effectiveExpiry', () {
    test('printed expiry only', () {
      final StockBatch b = makeBatch(expiry: DateTime(2026, 12, 1));
      expect(b.effectiveExpiry, DateTime(2026, 12, 1));
    });

    test('opened rule wins when earlier', () {
      final StockBatch b = makeBatch(
        expiry: DateTime(2026, 12, 1),
        opened: DateTime(2026, 11, 1),
        within: 5,
      );
      expect(b.effectiveExpiry, DateTime(2026, 11, 6));
    });

    test('printed wins when earlier than opened rule', () {
      final StockBatch b = makeBatch(
        expiry: DateTime(2026, 11, 3),
        opened: DateTime(2026, 11, 1),
        within: 30,
      );
      expect(b.effectiveExpiry, DateTime(2026, 11, 3));
    });

    test('no dates -> null', () {
      expect(makeBatch().effectiveExpiry, isNull);
    });
  });

  group('expiryStatus date boundaries', () {
    StatusKind kind(DateTime? d) =>
        StockLogic.expiryStatus(d, today: kToday, warningDays: 3).kind;

    test('yesterday is expired', () => expect(kind(DateTime(2026, 11, 3)), StatusKind.expired));
    test('today is expiring', () => expect(kind(DateTime(2026, 11, 4)), StatusKind.expiring));
    test('day 3 is expiring', () => expect(kind(DateTime(2026, 11, 7)), StatusKind.expiring));
    test('day 4 is fresh', () => expect(kind(DateTime(2026, 11, 8)), StatusKind.fresh));
    test('no expiry is fresh', () => expect(kind(null), StatusKind.fresh));

    test('labels', () {
      expect(StockLogic.expiringLabel(0), 'Today');
      expect(StockLogic.expiringLabel(1), 'Tomorrow');
      expect(StockLogic.expiringLabel(3), 'In 3 days');
      expect(StockLogic.expiredLabel(2), 'Expired 2d ago');
    });
  });

  group('summarize', () {
    test('sums batches across convertible units', () {
      final ItemStock s = summarize(makeItem(), <StockBatch>[
        makeBatch(id: 'a', bought: 1),
        makeBatch(id: 'b', bought: 500, unit: Unit.g),
      ]);
      expect(s.totalRemaining, 1.5);
      expect(s.status, StatusKind.fresh);
    });

    test('no batches -> out of stock', () {
      expect(summarize(makeItem(), <StockBatch>[]).status, StatusKind.outOfStock);
    });

    test('used-up batches -> out of stock', () {
      final ItemStock s = summarize(makeItem(), <StockBatch>[makeBatch(remaining: 0)]);
      expect(s.status, StatusKind.outOfStock);
    });

    test('low stock at threshold', () {
      final ItemStock s = summarize(
        makeItem(threshold: 1),
        <StockBatch>[makeBatch(bought: 2, remaining: 1)],
      );
      expect(s.status, StatusKind.lowStock);
    });

    test('expired beats low stock', () {
      final ItemStock s = summarize(
        makeItem(threshold: 5),
        <StockBatch>[makeBatch(expiry: DateTime(2026, 11, 1))],
      );
      expect(s.status, StatusKind.expired);
    });

    test('nearest expiry ignores used-up batches', () {
      final ItemStock s = summarize(makeItem(), <StockBatch>[
        makeBatch(id: 'a', remaining: 0, expiry: DateTime(2026, 11, 1)),
        makeBatch(id: 'b', expiry: DateTime(2026, 12, 20)),
      ]);
      expect(s.nearestExpiry, DateTime(2026, 12, 20));
      expect(s.status, StatusKind.fresh);
    });
  });
}
