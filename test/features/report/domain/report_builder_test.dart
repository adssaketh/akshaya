import 'package:akshaya/core/design/tokens/status_kind.dart';
import 'package:akshaya/features/pantry/domain/consumption_type.dart';
import 'package:akshaya/features/pantry/domain/entities.dart';
import 'package:akshaya/features/pantry/domain/stock_logic.dart';
import 'package:akshaya/features/pantry/domain/storage_location.dart';
import 'package:akshaya/features/pantry/domain/unit.dart';
import 'package:akshaya/features/report/domain/report_builder.dart';
import 'package:akshaya/features/report/domain/report_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../pantry/domain/test_data.dart';

final DateTime today = DateTime(2026, 11, 4);

final Map<String, Item> items = <String, Item>{
  'rice': makeItem(id: 'rice', name: 'Basmati Rice'),
  'dal': makeItem(id: 'dal', name: 'Toor Dal', categoryId: 'cat_dals'),
  'tomato':
      makeItem(id: 'tomato', name: 'Tomato', categoryId: 'cat_vegetables'),
  'banana': makeItem(
      id: 'banana', name: 'Banana', unit: Unit.pcs, categoryId: 'cat_fruits'),
  'curd': makeItem(
      id: 'curd', name: 'Curd', unit: Unit.g, categoryId: 'cat_dairy'),
  'oil': makeItem(
      id: 'oil', name: 'Sunflower Oil', unit: Unit.l, categoryId: 'cat_oils'),
  'mystery': makeItem(
      id: 'mystery',
      name: 'Zorbo',
      unit: Unit.g,
      categoryId: 'cat_vegetables'),
  'snack': makeItem(
      id: 'snack', name: 'Chips', unit: Unit.packet, categoryId: 'cat_snacks'),
};

ConsumptionEntry used(
  String itemId,
  double qty,
  Unit unit, {
  int daysAgo = 0,
  ConsumptionType type = ConsumptionType.used,
}) {
  return ConsumptionEntry(
    id: '$itemId-$daysAgo-$qty-${type.name}',
    batchId: 'b1',
    itemId: itemId,
    quantityUsed: qty,
    unit: unit,
    date: DateTime(2026, 11, 4 - daysAgo, 13),
    type: type,
  );
}

/// A day with every plate group.
List<ConsumptionEntry> fullDay(int daysAgo) => <ConsumptionEntry>[
      used('rice', 300, Unit.g, daysAgo: daysAgo),
      used('dal', 100, Unit.g, daysAgo: daysAgo),
      used('tomato', 200, Unit.g, daysAgo: daysAgo),
      used('banana', 2, Unit.pcs, daysAgo: daysAgo),
      used('curd', 200, Unit.g, daysAgo: daysAgo),
    ];

ConsumptionReport build(
  List<ConsumptionEntry> history, {
  ReportPeriod period = ReportPeriod.today,
  int people = 2,
  bool vegetarian = false,
  List<ItemStock> stocks = const <ItemStock>[],
}) {
  return buildConsumptionReport(
    period: period,
    today: today,
    history: history,
    itemsById: items,
    people: people,
    vegetarian: vegetarian,
    stocks: stocks,
  );
}

void main() {
  group('what counts', () {
    test('only use and cooking count, only inside the window', () {
      final ConsumptionReport r = build(<ConsumptionEntry>[
        used('rice', 300, Unit.g),
        used('dal', 100, Unit.g, type: ConsumptionType.cookedInRecipe),
        used('tomato', 200, Unit.g, type: ConsumptionType.wasted),
        used('curd', 200, Unit.g, type: ConsumptionType.expired),
        used('banana', 2, Unit.pcs, type: ConsumptionType.givenAway),
        used('oil', 1, Unit.l, type: ConsumptionType.adjustment),
        used('rice', 500, Unit.g, daysAgo: 1),
      ]);
      expect(r.lines.map((ConsumedLine l) => l.name).toSet(),
          <String>{'Basmati Rice', 'Toor Dal'});
      expect(r.loggedDays, 1);
    });

    test('the windows are today, the last 7 days and the last 30 days', () {
      final List<ConsumptionEntry> history = <ConsumptionEntry>[
        used('rice', 100, Unit.g),
        used('dal', 100, Unit.g, daysAgo: 6),
        used('curd', 100, Unit.g, daysAgo: 7),
        used('tomato', 100, Unit.g, daysAgo: 29),
        used('banana', 1, Unit.pcs, daysAgo: 30),
      ];
      expect(build(history).lines.length, 1);
      expect(build(history, period: ReportPeriod.week).lines.length, 2);
      expect(build(history, period: ReportPeriod.month).lines.length, 4);
    });

    test('entries for an item that no longer exists are skipped', () {
      final ConsumptionReport r =
          build(<ConsumptionEntry>[used('gone', 1, Unit.kg)]);
      expect(r.isEmpty, isTrue);
    });

    test('the same food is added up into one line', () {
      final ConsumptionReport r = build(<ConsumptionEntry>[
        used('rice', 300, Unit.g),
        used('rice', 0.7, Unit.kg),
      ]);
      expect(r.lines.single.quantityLabel, '1 kg');
    });
  });

  group('calories', () {
    test('adds up the estimate and divides by people and logged days', () {
      final ConsumptionReport r = build(<ConsumptionEntry>[
        used('rice', 300, Unit.g), // 1065
        used('dal', 100, Unit.g), // toor dal: 335
      ], people: 2);
      expect(r.totalKcal, closeTo(1400, 0.5));
      expect(r.kcalPerPersonPerDay, closeTo(700, 0.5));
    });

    test('a week is averaged over the days something was logged', () {
      final ConsumptionReport r = build(<ConsumptionEntry>[
        used('rice', 400, Unit.g, daysAgo: 1), // 1420
        used('rice', 400, Unit.g, daysAgo: 3), // 1420
      ], period: ReportPeriod.week, people: 1);
      expect(r.loggedDays, 2);
      expect(r.kcalPerPersonPerDay, closeTo(1420, 0.5));
    });

    test('amounts that cannot be weighed are listed but not counted', () {
      final ConsumptionReport r = build(<ConsumptionEntry>[
        used('rice', 300, Unit.g),
        used('snack', 1, Unit.packet),
      ]);
      expect(r.lines.length, 2);
      expect(r.countedLines, 1);
      expect(r.uncountedLines, 1);
      expect(r.lines.last.kcal, isNull);
    });

    test('an unknown food gets its category figure, marked as an estimate',
        () {
      final ConsumptionReport r =
          build(<ConsumptionEntry>[used('mystery', 100, Unit.g)]);
      expect(r.lines.single.kcal, closeTo(35, 0.5));
      expect(r.lines.single.estimatedFromGroup, isTrue);
    });

    test('says nothing about calories when nothing can be counted', () {
      final ConsumptionReport r =
          build(<ConsumptionEntry>[used('snack', 1, Unit.packet)]);
      expect(r.kcalPerPersonPerDay, isNull);
    });
  });

  group('balance', () {
    test('a day with every group is balanced', () {
      final ConsumptionReport r = build(fullDay(0));
      expect(r.verdict, BalanceVerdict.balanced);
      expect(r.missing, isEmpty);
      expect(r.coverage[PlateGroup.fruits], 1);
    });

    test('too little logged is not judged', () {
      final ConsumptionReport r = build(<ConsumptionEntry>[
        used('rice', 300, Unit.g),
        used('dal', 100, Unit.g),
      ]);
      expect(r.verdict, BalanceVerdict.notEnoughData);
      expect(r.tips, isEmpty);
    });

    test('a day without vegetables is not balanced, and says what to add',
        () {
      final ConsumptionReport r = build(<ConsumptionEntry>[
        used('rice', 300, Unit.g),
        used('dal', 100, Unit.g),
        used('curd', 200, Unit.g),
      ]);
      expect(r.verdict, BalanceVerdict.partly);
      expect(r.missing, contains(PlateGroup.vegetables));
      expect(r.tips.first, contains('vegetables'));
    });

    test('a week is balanced when most logged days are', () {
      final ConsumptionReport r = build(<ConsumptionEntry>[
        ...fullDay(0),
        ...fullDay(1),
        ...fullDay(2),
        used('rice', 300, Unit.g, daysAgo: 3),
      ], period: ReportPeriod.week);
      expect(r.loggedDays, 4);
      expect(r.verdict, BalanceVerdict.balanced);
    });

    test('a week of only rice and dal is not balanced', () {
      final ConsumptionReport r = build(<ConsumptionEntry>[
        for (int d = 0; d < 4; d++) ...<ConsumptionEntry>[
          used('rice', 300, Unit.g, daysAgo: d),
          used('dal', 100, Unit.g, daysAgo: d),
        ],
      ], period: ReportPeriod.week);
      expect(r.verdict, BalanceVerdict.notBalanced);
      expect(r.missing, containsAll(<PlateGroup>[
        PlateGroup.vegetables,
        PlateGroup.fruits,
        PlateGroup.dairy,
      ]));
    });
  });

  group('tips', () {
    test('a vegetarian is never told to eat meat', () {
      final ConsumptionReport r = build(<ConsumptionEntry>[
        used('rice', 300, Unit.g),
        used('tomato', 200, Unit.g),
        used('banana', 2, Unit.pcs),
      ], vegetarian: true);
      final String all = r.tips.join(' ').toLowerCase();
      expect(all, contains('dal'));
      expect(all, isNot(contains('meat')));
      expect(all, isNot(contains('egg')));
    });

    test('heavy oil use is pointed out', () {
      final ConsumptionReport r = build(<ConsumptionEntry>[
        ...fullDay(0),
        used('oil', 0.5, Unit.l), // 4100 kcal
      ]);
      expect(r.fatShare, greaterThan(0.3));
      expect(r.tips.join(' '), contains('Oil'));
    });

    test('suggests pantry foods for a gap, expiring ones first, never expired',
        () {
      ItemStock stockOf(Item item, StatusKind status, double left) {
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

      final Item okra = makeItem(
          id: 'okra', name: 'Okra', unit: Unit.g, categoryId: 'cat_vegetables');
      final Item carrot = makeItem(
          id: 'carrot', name: 'Carrot', unit: Unit.g, categoryId: 'cat_vegetables');
      final Item spoiled = makeItem(
          id: 'spoiled', name: 'Cabbage', unit: Unit.g, categoryId: 'cat_vegetables');
      final Item none = makeItem(
          id: 'none', name: 'Beans', unit: Unit.g, categoryId: 'cat_vegetables');
      final ConsumptionReport r = build(
        <ConsumptionEntry>[
          used('rice', 300, Unit.g),
          used('dal', 100, Unit.g),
          used('curd', 200, Unit.g),
        ],
        stocks: <ItemStock>[
          stockOf(carrot, StatusKind.fresh, 500),
          stockOf(okra, StatusKind.expiring, 250),
          stockOf(spoiled, StatusKind.expired, 400),
          stockOf(none, StatusKind.outOfStock, 0),
        ],
      );
      final PantrySuggestion veg = r.suggestions
          .firstWhere((PantrySuggestion s) => s.group == PlateGroup.vegetables);
      expect(veg.items, <String>['Okra', 'Carrot']);
    });

    test('a very low or very high number comes with a caution', () {
      final ConsumptionReport low = build(fullDay(0), people: 6);
      expect(low.notes.join(' '), contains('low'));
      final ConsumptionReport high = build(<ConsumptionEntry>[
        used('rice', 2, Unit.kg),
        used('oil', 0.3, Unit.l),
        used('dal', 500, Unit.g),
      ], people: 1);
      expect(high.notes.join(' '), contains('high'));
    });
  });
}
