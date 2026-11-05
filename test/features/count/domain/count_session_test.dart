import 'package:akshaya/features/count/domain/count_session.dart';
import 'package:akshaya/features/pantry/domain/consumption_type.dart';
import 'package:akshaya/features/pantry/domain/entities.dart';
import 'package:akshaya/features/pantry/domain/stock_count.dart';
import 'package:akshaya/features/pantry/domain/storage_location.dart';
import 'package:akshaya/features/pantry/domain/unit.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../pantry/domain/test_data.dart';

ItemWithBatches record(
  String id,
  String name,
  List<StockBatch> batches, {
  String categoryId = 'cat_grains',
  Unit unit = Unit.kg,
}) {
  return ItemWithBatches(
    item: makeItem(id: id, name: name, categoryId: categoryId, unit: unit),
    batches: batches,
  );
}

void main() {
  group('CountScope', () {
    test('keys round-trip', () {
      const List<CountScope> scopes = <CountScope>[
        CountScope.all(),
        CountScope.inLocation(StorageLocation.freezer),
        CountScope.inCategory('cat_dairy'),
      ];
      for (final CountScope scope in scopes) {
        expect(CountScope.fromKey(scope.key), scope);
      }
      expect(const CountScope.all().key, 'all');
      expect(
        const CountScope.inLocation(StorageLocation.fridge).key,
        'location:fridge',
      );
      expect(const CountScope.inCategory('cat_x').key, 'category:cat_x');
    });

    test('unreadable keys give null', () {
      expect(CountScope.fromKey(null), isNull);
      expect(CountScope.fromKey(''), isNull);
      expect(CountScope.fromKey('location:attic'), isNull);
      expect(CountScope.fromKey('category:'), isNull);
      expect(CountScope.fromKey('everything'), isNull);
    });
  });

  group('CountPlanner', () {
    final List<ItemWithBatches> records = <ItemWithBatches>[
      record('r', 'Rice', <StockBatch>[
        makeBatch(id: 'b1', itemId: 'r', bought: 2),
        makeBatch(
          id: 'b2',
          itemId: 'r',
          bought: 1,
          location: StorageLocation.fridge,
        ),
      ]),
      record(
        'm',
        'Milk',
        <StockBatch>[
          makeBatch(
            id: 'b3',
            itemId: 'm',
            bought: 2,
            unit: Unit.l,
            location: StorageLocation.fridge,
          ),
        ],
        categoryId: 'cat_dairy',
        unit: Unit.l,
      ),
      record('a', 'Atta', <StockBatch>[
        makeBatch(id: 'b4', itemId: 'a', bought: 1, remaining: 0),
      ]),
    ];

    test('everything lists items with stock by name', () {
      final List<CountLine> lines =
          CountPlanner.lines(records, const CountScope.all());
      expect(lines.map((CountLine l) => l.item.name), <String>['Milk', 'Rice']);
      expect(lines.last.expected, 3);
      expect(lines.last.batchCount, 2);
      expect(lines.last.location, isNull);
      expect(lines.last.expectedLabel, '3 kg');
    });

    test('a location counts only the batches kept there', () {
      final List<CountLine> lines = CountPlanner.lines(
        records,
        const CountScope.inLocation(StorageLocation.fridge),
      );
      expect(lines.map((CountLine l) => l.item.name), <String>['Milk', 'Rice']);
      final CountLine rice = lines.last;
      expect(rice.expected, 1);
      expect(rice.location, StorageLocation.fridge);
    });

    test('a location with nothing in it is empty', () {
      expect(
        CountPlanner.lines(
          records,
          const CountScope.inLocation(StorageLocation.freezer),
        ),
        isEmpty,
      );
    });

    test('a category keeps only its items', () {
      final List<CountLine> lines = CountPlanner.lines(
        records,
        const CountScope.inCategory('cat_dairy'),
      );
      expect(lines.single.item.name, 'Milk');
      expect(lines.single.expectedLabel, '2 L');
    });

    test('a batch in another unit is converted to the item unit', () {
      final List<ItemWithBatches> mixed = <ItemWithBatches>[
        record('r', 'Rice', <StockBatch>[
          makeBatch(id: 'b1', itemId: 'r', bought: 1),
          makeBatch(id: 'b2', itemId: 'r', bought: 500, unit: Unit.g),
        ]),
      ];
      final CountLine line =
          CountPlanner.lines(mixed, const CountScope.all()).single;
      expect(line.expected, 1.5);
    });
  });

  group('CountOutcome', () {
    test('labels the difference with a sign', () {
      const CountOutcome more = CountOutcome(
        itemId: 'r',
        name: 'Rice',
        kind: CountOutcomeKind.raised,
        expected: 2,
        counted: 3,
        unit: Unit.kg,
      );
      const CountOutcome less = CountOutcome(
        itemId: 'r',
        name: 'Rice',
        kind: CountOutcomeKind.lowered,
        expected: 2,
        counted: 1.5,
        unit: Unit.kg,
      );
      const CountOutcome same = CountOutcome(
        itemId: 'r',
        name: 'Rice',
        kind: CountOutcomeKind.matched,
        expected: 2,
        counted: 2,
        unit: Unit.kg,
      );
      expect(more.differenceLabel, '+1 kg');
      expect(less.differenceLabel, '-0.5 kg');
      expect(same.differenceLabel, '');
    });

    test('json round-trips and rejects damage', () {
      const CountOutcome outcome = CountOutcome(
        itemId: 'r',
        name: 'Rice',
        kind: CountOutcomeKind.wasted,
        expected: 2,
        counted: 1,
        unit: Unit.kg,
      );
      final CountOutcome? back = CountOutcome.fromJson(outcome.toJson());
      expect(back, isNotNull);
      expect(back!.itemId, 'r');
      expect(back.kind, CountOutcomeKind.wasted);
      expect(back.expected, 2);
      expect(back.counted, 1);
      expect(back.unit, Unit.kg);
      expect(CountOutcome.fromJson('nope'), isNull);
      expect(
        CountOutcome.fromJson(<String, Object?>{...outcome.toJson(), 'k': 'x'}),
        isNull,
      );
      expect(
        CountOutcome.fromJson(<String, Object?>{...outcome.toJson(), 'u': 'x'}),
        isNull,
      );
    });
  });

  group('CountOutcomeKind.of', () {
    CountResult result(double before, double after, {bool changed = true}) {
      return CountResult(
        itemId: 'r',
        before: before,
        after: after,
        unit: Unit.kg,
        addedBatchId: changed && after > before ? 'b' : null,
        addedLogId: changed && after > before ? 'l' : null,
        deduction: changed && after < before
            ? const UseResult(
                itemId: 'r',
                quantity: 1,
                unit: Unit.kg,
                type: ConsumptionType.adjustment,
                applied: <AppliedDeduction>[],
              )
            : null,
      );
    }

    test('matched, raised, lowered, finished and wasted', () {
      expect(
        CountOutcomeKind.of(result(2, 2, changed: false), asWaste: false),
        CountOutcomeKind.matched,
      );
      expect(
        CountOutcomeKind.of(result(2, 3), asWaste: false),
        CountOutcomeKind.raised,
      );
      expect(
        CountOutcomeKind.of(result(2, 1), asWaste: false),
        CountOutcomeKind.lowered,
      );
      expect(
        CountOutcomeKind.of(result(2, 0), asWaste: false),
        CountOutcomeKind.finished,
      );
      expect(
        CountOutcomeKind.of(result(2, 1), asWaste: true),
        CountOutcomeKind.wasted,
      );
    });
  });

  group('CountSession', () {
    final DateTime started = DateTime(2026, 11, 4);
    CountOutcome outcome(String id, CountOutcomeKind kind) => CountOutcome(
          itemId: id,
          name: 'Item $id',
          kind: kind,
          expected: 2,
          counted: 2,
          unit: Unit.kg,
        );

    test('tracks answered and put-off items', () {
      CountSession session = CountSession(
        scope: const CountScope.all(),
        startedOn: started,
      );
      expect(session.isDone('a'), isFalse);

      session = session.withOutcome(outcome('a', CountOutcomeKind.matched));
      session = session.withSkipped('b');
      expect(session.isDone('a'), isTrue);
      expect(session.isDone('b'), isTrue);
      expect(session.isDone('c'), isFalse);

      // Answering a put-off item takes it off the put-off list.
      session = session.withOutcome(outcome('b', CountOutcomeKind.raised));
      expect(session.skipped, isEmpty);

      // Undo puts an item back in the queue.
      session = session.without('a');
      expect(session.isDone('a'), isFalse);
      expect(session.outcomes.keys, <String>['b']);
    });

    test('survives being saved and read back', () {
      final CountSession session = CountSession(
        scope: const CountScope.inLocation(StorageLocation.fridge),
        startedOn: started,
      )
          .withOutcome(outcome('a', CountOutcomeKind.lowered))
          .withSkipped('b');

      final CountSession? back = CountSession.decode(session.encode());

      expect(back, isNotNull);
      expect(back!.scope, const CountScope.inLocation(StorageLocation.fridge));
      expect(back.startedOn, started);
      expect(back.outcomes.keys, <String>['a']);
      expect(back.outcomes['a']!.kind, CountOutcomeKind.lowered);
      expect(back.skipped, <String>{'b'});
    });

    test('damaged saved text means no count to resume', () {
      expect(CountSession.decode(null), isNull);
      expect(CountSession.decode(''), isNull);
      expect(CountSession.decode('not json'), isNull);
      expect(CountSession.decode('[]'), isNull);
      expect(
        CountSession.decode('{"scope":"all","started":"2026-13-45"}'),
        isNull,
      );
      expect(
        CountSession.decode('{"scope":"weird","started":"2026-11-04"}'),
        isNull,
      );
      expect(CountSession.decode('{"scope":5,"started":"2026-11-04"}'), isNull);
    });
  });

  group('CountSummary', () {
    test('counts each kind and lists the changes by name', () {
      CountOutcome make(String id, String name, CountOutcomeKind kind) {
        return CountOutcome(
          itemId: id,
          name: name,
          kind: kind,
          expected: 2,
          counted: kind == CountOutcomeKind.matched ? 2 : 1,
          unit: Unit.kg,
        );
      }

      final CountSession session = CountSession(
        scope: const CountScope.all(),
        startedOn: DateTime(2026, 11, 4),
      )
          .withOutcome(make('1', 'Rice', CountOutcomeKind.matched))
          .withOutcome(make('2', 'Wheat', CountOutcomeKind.lowered))
          .withOutcome(make('3', 'Atta', CountOutcomeKind.raised))
          .withOutcome(make('4', 'Dal', CountOutcomeKind.finished))
          .withOutcome(make('5', 'Curd', CountOutcomeKind.wasted))
          .withSkipped('6');

      final CountSummary summary = CountSummary.of(session);

      expect(summary.matched, 1);
      expect(summary.lowered, 1);
      expect(summary.raised, 1);
      expect(summary.finished, 1);
      expect(summary.wasted, 1);
      expect(summary.skipped, 1);
      expect(summary.checked, 5);
      expect(summary.changed, 4);
      expect(
        summary.changes.map((CountOutcome o) => o.name),
        <String>['Atta', 'Curd', 'Dal', 'Wheat'],
      );
    });
  });
}
