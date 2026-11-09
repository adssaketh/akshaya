import 'package:akshaya/core/design/tokens/status_kind.dart';
import 'package:akshaya/features/pantry/domain/consumption_type.dart';
import 'package:akshaya/features/pantry/domain/entities.dart';
import 'package:akshaya/features/pantry/domain/stock_logic.dart';
import 'package:akshaya/features/pantry/domain/storage_location.dart';
import 'package:akshaya/features/pantry/domain/unit.dart';
import 'package:akshaya/features/report/domain/nutrition_table.dart';
import 'package:akshaya/features/report/domain/report_builder.dart';
import 'package:akshaya/features/report/domain/report_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../pantry/domain/test_data.dart';

final DateTime today = DateTime(2026, 11, 4);

final Map<String, Item> items = <String, Item>{
  'rice': makeItem(id: 'rice', name: 'Basmati Rice'),
  'dal': makeItem(id: 'dal', name: 'Toor Dal', categoryId: 'cat_dals'),
  'tomato': makeItem(
    id: 'tomato',
    name: 'Tomato',
    categoryId: 'cat_vegetables',
  ),
  'banana': makeItem(
    id: 'banana',
    name: 'Banana',
    unit: Unit.pcs,
    categoryId: 'cat_fruits',
  ),
  'curd': makeItem(
    id: 'curd',
    name: 'Curd',
    unit: Unit.g,
    categoryId: 'cat_dairy',
  ),
  'oil': makeItem(
    id: 'oil',
    name: 'Sunflower Oil',
    unit: Unit.l,
    categoryId: 'cat_oils',
  ),
  'mystery': makeItem(
    id: 'mystery',
    name: 'Zorbo',
    unit: Unit.g,
    categoryId: 'cat_vegetables',
  ),
  'snack': makeItem(
    id: 'snack',
    name: 'Chips',
    unit: Unit.packet,
    categoryId: 'cat_snacks',
  ),
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
      expect(r.lines.map((ConsumedLine l) => l.name).toSet(), <String>{
        'Basmati Rice',
        'Toor Dal',
      });
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
      final ConsumptionReport r = build(<ConsumptionEntry>[
        used('gone', 1, Unit.kg),
      ]);
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
      final ConsumptionReport r = build(
        <ConsumptionEntry>[
          used('rice', 400, Unit.g, daysAgo: 1), // 1420
          used('rice', 400, Unit.g, daysAgo: 3), // 1420
        ],
        period: ReportPeriod.week,
        people: 1,
      );
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

    test('an unknown food gets its category figure, marked as an estimate', () {
      final ConsumptionReport r = build(<ConsumptionEntry>[
        used('mystery', 100, Unit.g),
      ]);
      expect(r.lines.single.kcal, closeTo(35, 0.5));
      expect(r.lines.single.estimatedFromGroup, isTrue);
    });

    test('says nothing about calories when nothing can be counted', () {
      final ConsumptionReport r = build(<ConsumptionEntry>[
        used('snack', 1, Unit.packet),
      ]);
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

    test('a day without vegetables is not balanced, and says what to add', () {
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
      expect(
        r.missing,
        containsAll(<PlateGroup>[
          PlateGroup.vegetables,
          PlateGroup.fruits,
          PlateGroup.dairy,
        ]),
      );
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

    test('with eggs allowed, the protein tip suggests an egg, never meat', () {
      final ConsumptionReport r = build(<ConsumptionEntry>[
        used('rice', 300, Unit.g),
        used('tomato', 200, Unit.g),
        used('banana', 2, Unit.pcs),
      ]);
      final String all = r.tips.join(' ').toLowerCase();
      expect(all, contains('egg'));
      expect(all, isNot(contains('meat')));
    });

    test('heavy oil use is pointed out', () {
      final ConsumptionReport r = build(<ConsumptionEntry>[
        ...fullDay(0),
        used('oil', 0.5, Unit.l), // 4100 kcal
      ]);
      expect(r.fatShare, greaterThan(0.3));
      expect(r.tips.join(' '), contains('Oil'));
    });

    test(
      'suggests pantry foods for a gap, expiring ones first, never expired',
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
          id: 'okra',
          name: 'Okra',
          unit: Unit.g,
          categoryId: 'cat_vegetables',
        );
        final Item carrot = makeItem(
          id: 'carrot',
          name: 'Carrot',
          unit: Unit.g,
          categoryId: 'cat_vegetables',
        );
        final Item spoiled = makeItem(
          id: 'spoiled',
          name: 'Cabbage',
          unit: Unit.g,
          categoryId: 'cat_vegetables',
        );
        final Item none = makeItem(
          id: 'none',
          name: 'Beans',
          unit: Unit.g,
          categoryId: 'cat_vegetables',
        );
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
        final PantrySuggestion veg = r.suggestions.firstWhere(
          (PantrySuggestion s) => s.group == PlateGroup.vegetables,
        );
        expect(veg.items, <String>['Okra', 'Carrot']);
      },
    );

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

  group('the detailed numbers', () {
    test('protein, carbs, fat and fibre are averaged per person per day', () {
      final ConsumptionReport r = build(<ConsumptionEntry>[
        used('rice', 300, Unit.g),
        used('dal', 100, Unit.g),
      ], people: 2);
      final NutrientAverages n = r.nutrients!;
      // Rice 300 g: 21 g protein, 234 g carbs. Toor dal 100 g: 22 g, 62 g.
      expect(n.protein, closeTo((21 + 22) / 2, 0.5));
      expect(n.carbs, closeTo((234 + 62) / 2, 0.5));
      expect(n.fibre, greaterThan(5));
    });

    test('energy shares add up to 1 and carbs lead for rice and dal', () {
      final Map<String, double> shares = build(<ConsumptionEntry>[
        used('rice', 300, Unit.g),
        used('dal', 100, Unit.g),
      ]).nutrients!.energyShares!;
      expect(
        shares.values.fold<double>(0, (double a, double b) => a + b),
        closeTo(1, 0.0001),
      );
      expect(shares['Carbs'], greaterThan(shares['Protein']!));
      expect(shares['Carbs'], greaterThan(shares['Fat']!));
    });

    test(
      'every day of the window is listed, oldest first, with the logged ones',
      () {
        final ConsumptionReport r = build(
          <ConsumptionEntry>[
            used('rice', 400, Unit.g, daysAgo: 1),
            used('rice', 200, Unit.g, daysAgo: 3),
          ],
          period: ReportPeriod.week,
          people: 1,
        );
        expect(r.daily.length, 7);
        expect(r.daily.first.day, DateTime(2026, 10, 29));
        expect(r.daily.last.day, today);
        expect(r.daily.where((DailyPoint p) => p.logged).length, 2);
        expect(r.daily[5].logged, isTrue, reason: 'yesterday');
        expect(r.daily[5].kcalPerPerson, closeTo(1420, 1));
        expect(r.daily[6].kcalPerPerson, 0);
      },
    );

    test('a month has 30 daily points', () {
      expect(
        build(<ConsumptionEntry>[], period: ReportPeriod.month).daily.length,
        30,
      );
    });

    test('energy is split by food group', () {
      final ConsumptionReport r = build(fullDay(0));
      expect(
        r.energyByGroup.keys,
        containsAll(<FoodGroup>[
          FoodGroup.cereals,
          FoodGroup.pulses,
          FoodGroup.vegetables,
          FoodGroup.fruits,
          FoodGroup.dairy,
        ]),
      );
      expect(
        r.energyByGroup.values.fold<double>(0, (double a, double b) => a + b),
        closeTo(r.totalKcal, 0.01),
      );
    });

    test('lines carry their group and protein', () {
      final ConsumedLine rice = build(
        fullDay(0),
      ).lines.firstWhere((ConsumedLine l) => l.name == 'Basmati Rice');
      expect(rice.group, FoodGroup.cereals);
      expect(rice.protein, closeTo(21, 0.5));
    });

    test('nothing countable means no nutrient averages', () {
      expect(
        build(<ConsumptionEntry>[used('snack', 1, Unit.packet)]).nutrients,
        isNull,
      );
    });
  });

  group('streak and comparison', () {
    test('counts days in a row, ending today', () {
      final int streak = loggingStreak(<ConsumptionEntry>[
        used('rice', 1, Unit.kg),
        used('rice', 1, Unit.kg, daysAgo: 1),
        used('rice', 1, Unit.kg, daysAgo: 2),
        used('rice', 1, Unit.kg, daysAgo: 4),
      ], today);
      expect(streak, 3);
    });

    test(
      'a day without logging does not break the streak until it has passed',
      () {
        final int streak = loggingStreak(<ConsumptionEntry>[
          used('rice', 1, Unit.kg, daysAgo: 1),
          used('rice', 1, Unit.kg, daysAgo: 2),
        ], today);
        expect(streak, 2);
        expect(
          loggingStreak(<ConsumptionEntry>[
            used('rice', 1, Unit.kg, daysAgo: 2),
          ], today),
          0,
        );
      },
    );

    test('waste does not count towards the streak', () {
      expect(
        loggingStreak(<ConsumptionEntry>[
          used('rice', 1, Unit.kg, type: ConsumptionType.wasted),
        ], today),
        0,
      );
    });

    test('compares with the window before', () {
      final ConsumptionReport now = build(<ConsumptionEntry>[
        used('rice', 500, Unit.g),
      ], people: 1);
      final ConsumptionReport before = build(<ConsumptionEntry>[
        used('rice', 300, Unit.g),
      ], people: 1);
      final ReportComparison c = compareReports(now, before);
      expect(c.kcalChange, closeTo(710, 1));
      expect(c.proteinChange, closeTo(14, 0.5));
      expect(c.isEmpty, isFalse);
    });

    test('nothing to compare with gives an empty comparison', () {
      final ReportComparison c = compareReports(
        build(fullDay(0)),
        build(<ConsumptionEntry>[]),
      );
      expect(c.isEmpty, isTrue);
    });
  });

  group('exact amounts from the pantry, not per 100 g', () {
    test('double the quantity used gives double the nutrients', () {
      final ConsumptionReport a = build(<ConsumptionEntry>[
        used('rice', 300, Unit.g),
      ], people: 1);
      final ConsumptionReport b = build(<ConsumptionEntry>[
        used('rice', 600, Unit.g),
      ], people: 1);
      expect(b.totalKcal, closeTo(2 * a.totalKcal, 0.001));
      expect(b.nutrients!.protein, closeTo(2 * a.nutrients!.protein, 0.001));
      expect(b.nutrients!.carbs, closeTo(2 * a.nutrients!.carbs, 0.001));
      expect(
        b.lines.single.protein,
        closeTo(2 * a.lines.single.protein, 0.001),
      );
    });

    test('300 g of rice shows the nutrients in 300 g', () {
      final ConsumedLine l = build(<ConsumptionEntry>[
        used('rice', 300, Unit.g),
      ], people: 1).lines.single;
      expect(l.protein, closeTo(21, 0.01));
      expect(l.carbs, closeTo(234, 0.01));
      expect(l.fat, closeTo(1.8, 0.01));
      expect(l.fibre, closeTo(3.9, 0.01));
      expect(l.kcal, closeTo(1065, 0.01));
    });

    test('a different unit gives the same answer', () {
      final ConsumedLine kg = build(<ConsumptionEntry>[
        used('rice', 0.3, Unit.kg),
      ]).lines.single;
      final ConsumedLine g = build(<ConsumptionEntry>[
        used('rice', 300, Unit.g),
      ]).lines.single;
      expect(kg.protein, closeTo(g.protein, 0.0001));
    });

    test('what is used over several days adds up', () {
      final ConsumedLine l = build(<ConsumptionEntry>[
        used('rice', 300, Unit.g),
        used('rice', 200, Unit.g, daysAgo: 1),
      ], period: ReportPeriod.week).lines.single;
      expect(l.quantityLabel, '500 g');
      expect(l.protein, closeTo(35, 0.01));
    });
  });

  group('amounts of each food group, per person per day', () {
    test('are totalled and divided by people and logged days', () {
      final ConsumptionReport r = build(
        <ConsumptionEntry>[
          used('rice', 300, Unit.g),
          used('dal', 100, Unit.g),
          used('rice', 300, Unit.g, daysAgo: 1),
        ],
        period: ReportPeriod.week,
        people: 2,
      );
      expect(
        r.amountPerPersonPerDay[FoodGroup.cereals],
        closeTo(600 / 2 / 2, 0.01),
      );
      expect(
        r.amountPerPersonPerDay[FoodGroup.pulses],
        closeTo(100 / 2 / 2, 0.01),
      );
    });

    test('milk and curd are in millilitres', () {
      final Map<String, Item> withMilk = <String, Item>{
        ...items,
        'milk': makeItem(
          id: 'milk',
          name: 'Milk',
          unit: Unit.l,
          categoryId: 'cat_dairy',
        ),
      };
      final ConsumptionReport r = buildConsumptionReport(
        period: ReportPeriod.today,
        today: today,
        history: <ConsumptionEntry>[used('milk', 0.5, Unit.l)],
        itemsById: withMilk,
        people: 2,
      );
      expect(r.amountPerPersonPerDay[FoodGroup.dairy], closeTo(250, 0.01));
    });

    test('foods that cannot be weighed are left out of the amounts', () {
      final ConsumptionReport r = build(<ConsumptionEntry>[
        used('snack', 2, Unit.packet),
      ]);
      expect(r.amountPerPersonPerDay, isEmpty);
    });
  });

  group('potato is not a vegetable on the plate', () {
    final Map<String, Item> withPotato = <String, Item>{
      ...items,
      'potato': makeItem(
        id: 'potato',
        name: 'Potato',
        unit: Unit.g,
        categoryId: 'cat_vegetables',
      ),
    };

    ConsumptionReport run(List<ConsumptionEntry> h) => buildConsumptionReport(
      period: ReportPeriod.today,
      today: today,
      history: h,
      itemsById: withPotato,
      people: 1,
    );

    test('a day with only potato as the vegetable is missing vegetables', () {
      final ConsumptionReport r = run(<ConsumptionEntry>[
        used('rice', 300, Unit.g),
        used('dal', 100, Unit.g),
        used('potato', 300, Unit.g),
        used('banana', 2, Unit.pcs),
        used('curd', 200, Unit.g),
      ]);
      expect(r.missing, contains(PlateGroup.vegetables));
      expect(r.verdict, isNot(BalanceVerdict.balanced));
    });

    test('and is kept out of the vegetable and fruit amounts', () {
      final ConsumptionReport r = run(<ConsumptionEntry>[
        used('potato', 300, Unit.g),
        used('banana', 2, Unit.pcs),
        used('tomato', 100, Unit.g),
      ]);
      expect(
        r.vegFruitGramsPerPersonPerDay,
        closeTo(300, 0.01),
        reason: '200 g banana and 100 g tomato',
      );
      expect(r.amountPerPersonPerDay[FoodGroup.tubers], closeTo(300, 0.01));
      expect(r.amountPerPersonPerDay[FoodGroup.vegetables], closeTo(100, 0.01));
    });
  });

  group('sugar and fat against the guideline', () {
    final Map<String, Item> withSugar = <String, Item>{
      ...items,
      'sugar': makeItem(id: 'sugar', name: 'Sugar', unit: Unit.g),
      'jaggery': makeItem(id: 'jaggery', name: 'Jaggery', unit: Unit.g),
    };

    ConsumptionReport run(List<ConsumptionEntry> h, {int people = 1}) =>
        buildConsumptionReport(
          period: ReportPeriod.today,
          today: today,
          history: h,
          itemsById: withSugar,
          people: people,
        );

    test('sugar grams are per person per day', () {
      final ConsumptionReport r = run(<ConsumptionEntry>[
        used('sugar', 60, Unit.g),
        used('jaggery', 20, Unit.g),
        used('rice', 300, Unit.g),
        used('dal', 100, Unit.g),
      ], people: 2);
      expect(
        r.sugarGramsPerPersonPerDay,
        closeTo((60 + 19) / 2, 0.01),
        reason: 'sugar is all carbohydrate, jaggery 95%',
      );
    });

    test('more than 30 g a person gets a tip that names the guideline', () {
      final ConsumptionReport r = run(<ConsumptionEntry>[
        used('sugar', 80, Unit.g),
        used('rice', 300, Unit.g),
        used('dal', 100, Unit.g),
        used('tomato', 200, Unit.g),
      ]);
      expect(r.tips.join(' '), contains('25 to 30 g'));
    });

    test('a little sugar gets no tip', () {
      final ConsumptionReport r = run(<ConsumptionEntry>[
        used('sugar', 10, Unit.g),
        used('rice', 300, Unit.g),
        used('dal', 100, Unit.g),
        used('tomato', 200, Unit.g),
      ]);
      expect(r.tips.join(' '), isNot(contains('25 to 30 g')));
    });

    test('oil above 15% of the calories is pointed out', () {
      final ConsumptionReport r = build(<ConsumptionEntry>[
        ...fullDay(0),
        used('oil', 0.1, Unit.l), // 820 of about 2,500 kcal
      ]);
      expect(r.fatShare, greaterThan(0.15));
      expect(r.tips.join(' '), contains('12%'));
    });

    test('oil below 15% is not', () {
      final ConsumptionReport r = build(<ConsumptionEntry>[
        ...fullDay(0),
        used('oil', 0.02, Unit.l),
      ]);
      expect(r.fatShare ?? 0, lessThan(0.15));
      expect(r.tips.join(' '), isNot(contains('12%')));
    });

    test('the total fat share is worked out', () {
      final ConsumptionReport r = build(fullDay(0));
      expect(r.totalFatShare, isNotNull);
      expect(r.totalFatShare, inInclusiveRange(0, 1));
    });
  });
}
