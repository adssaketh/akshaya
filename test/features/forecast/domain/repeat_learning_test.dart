import 'package:akshaya/features/forecast/domain/repeat_learning.dart';
import 'package:akshaya/features/pantry/domain/entities.dart';
import 'package:akshaya/features/shopping/domain/shopping_enums.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../pantry/domain/test_data.dart';
import '../../shopping/domain/shopping_test_data.dart';

List<DateTime> every(int days, int count) => <DateTime>[
      for (int i = 0; i < count; i++) DateTime(2026, 8, 1 + i * days),
    ];

ItemWithBatches rec(List<DateTime> dates) {
  return ItemWithBatches(
    item: makeItem(),
    batches: <StockBatch>[
      for (final (int i, DateTime d) in dates.indexed)
        makeBatch(id: 'b$i', purchase: d),
    ],
  );
}

void main() {
  group('learnedInterval', () {
    test('needs three purchase days', () {
      expect(RepeatLearning.learnedInterval(every(10, 2)), isNull);
      expect(RepeatLearning.learnedInterval(every(10, 3)), 10);
    });

    test('same-day purchases count once', () {
      expect(
        RepeatLearning.learnedInterval(<DateTime>[
          DateTime(2026, 8, 1),
          DateTime(2026, 8, 1, 18),
          DateTime(2026, 8, 11),
        ]),
        isNull,
      );
    });

    test('irregular habits give nothing', () {
      expect(
        RepeatLearning.learnedInterval(<DateTime>[
          DateTime(2026, 8, 1),
          DateTime(2026, 8, 3),
          DateTime(2026, 9, 20),
        ]),
        isNull,
      );
    });

    test('out of range gives nothing', () {
      expect(RepeatLearning.learnedInterval(every(1, 5)), isNull);
      expect(RepeatLearning.learnedInterval(every(200, 3)), isNull);
    });

    test('only the latest purchases count', () {
      final List<DateTime> dates = <DateTime>[
        DateTime(2026, 1, 1),
        DateTime(2026, 1, 31),
        ...every(7, 6),
      ];
      expect(RepeatLearning.learnedInterval(dates), 7);
    });
  });

  group('compute', () {
    test('suggests when the habit differs enough', () {
      final List<ScheduleSuggestion> out = RepeatLearning.compute(
        entries: [
          makeEntry(
            itemId: 'i1',
            recurrence: Recurrence.weekly,
          ),
        ],
        records: [rec(every(14, 4))],
      );
      expect(out.single.learnedDays, 14);
      expect(out.single.currentDays, 7);
      expect(out.single.learnedLabel, 'every 14 days');
    });

    test('close to the schedule is not worth mentioning', () {
      expect(
        RepeatLearning.compute(
          entries: [makeEntry(itemId: 'i1', recurrence: Recurrence.weekly)],
          records: [rec(every(8, 4))],
        ),
        isEmpty,
      );
    });

    test('non-repeating entries and unknown items are skipped', () {
      expect(
        RepeatLearning.compute(
          entries: [makeEntry(itemId: 'i1')],
          records: [rec(every(14, 4))],
        ),
        isEmpty,
      );
      expect(
        RepeatLearning.compute(
          entries: [
            makeEntry(name: 'Mystery', recurrence: Recurrence.weekly),
          ],
          records: [rec(every(14, 4))],
        ),
        isEmpty,
      );
    });

    test('a custom interval is the current schedule', () {
      expect(
        RepeatLearning.compute(
          entries: [
            makeEntry(
              itemId: 'i1',
              recurrence: Recurrence.weekly,
              repeatEveryDays: 14,
            ),
          ],
          records: [rec(every(14, 4))],
        ),
        isEmpty,
      );
    });

    test('dismissed suggestions stay hidden until the habit moves', () {
      final entries = [makeEntry(itemId: 'i1', recurrence: Recurrence.weekly)];
      expect(
        RepeatLearning.compute(
          entries: entries,
          records: [rec(every(14, 4))],
          dismissed: const <String, int>{'e1': 13},
        ),
        isEmpty,
      );
      expect(
        RepeatLearning.compute(
          entries: entries,
          records: [rec(every(14, 4))],
          dismissed: const <String, int>{'e1': 21},
        ),
        hasLength(1),
      );
    });

    test('count-mode batches are ignored', () {
      expect(
        RepeatLearning.compute(
          entries: [makeEntry(itemId: 'i1', recurrence: Recurrence.weekly)],
          records: [rec(every(14, 4))],
          excludedBatchIds: <String>{'b0', 'b1'},
        ),
        isEmpty,
      );
    });
  });

  group('ScheduleDismissals', () {
    test('round trips and skips junk', () {
      final String text =
          ScheduleDismissals.encodeWith(const <String, int>{}, 'e1', 10);
      expect(ScheduleDismissals.parse(text), <String, int>{'e1': 10});
      expect(
        ScheduleDismissals.parse('e1:10,bad,e2:x,:3,e3:4'),
        <String, int>{'e1': 10, 'e3': 4},
      );
      expect(ScheduleDismissals.parse(null), isEmpty);
    });

    test('updating replaces and the list is capped', () {
      Map<String, int> m = const <String, int>{};
      for (int i = 0; i < ScheduleDismissals.maxStored + 5; i++) {
        m = ScheduleDismissals.parse(
          ScheduleDismissals.encodeWith(m, 'e$i', 5),
        );
      }
      expect(m.length, ScheduleDismissals.maxStored);
      expect(m.containsKey('e0'), isFalse);
      final Map<String, int> n = ScheduleDismissals.parse(
        ScheduleDismissals.encodeWith(m, 'e54', 9),
      );
      expect(n['e54'], 9);
    });
  });

  group('Recurrence', () {
    test('nearestTo picks the closest built-in repeat', () {
      expect(Recurrence.nearestTo(2), Recurrence.daily);
      expect(Recurrence.nearestTo(10), Recurrence.weekly);
      expect(Recurrence.nearestTo(21), Recurrence.monthly);
    });

    test('custom days set the next due date', () {
      final e = makeEntry(recurrence: Recurrence.weekly, repeatEveryDays: 10);
      expect(e.intervalDays, 10);
      expect(e.nextDueAfter(DateTime(2026, 11, 4)), DateTime(2026, 11, 14));
      expect(e.repeatLabel, 'Every 10 days');
      expect(
        makeEntry(recurrence: Recurrence.weekly).repeatLabel,
        'Every week',
      );
    });
  });
}
