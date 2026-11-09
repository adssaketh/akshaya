import 'package:akshaya/core/design/tokens/status_kind.dart';
import 'package:akshaya/features/pantry/domain/entities.dart';
import 'package:akshaya/features/pantry/domain/stock_logic.dart';
import 'package:akshaya/features/pantry/domain/storage_location.dart';
import 'package:akshaya/features/pantry/domain/unit.dart';
import 'package:akshaya/features/report/domain/meal_ideas.dart';
import 'package:akshaya/features/report/domain/report_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../pantry/domain/test_data.dart';

ItemStock stockOf(
  String name, {
  String category = 'cat_vegetables',
  StatusKind status = StatusKind.fresh,
  double left = 1,
}) {
  return ItemStock(
    item: makeItem(
      id: name.toLowerCase().replaceAll(' ', '_'),
      name: name,
      unit: Unit.g,
      categoryId: category,
    ),
    batches: const <StockBatch>[],
    totalRemaining: left,
    nearestExpiry: null,
    daysToExpiry: null,
    status: status,
    primaryLocation: StorageLocation.pantry,
  );
}

List<String> names(List<MealIdea> ideas) =>
    ideas.map((MealIdea i) => i.dish.name).toList();

void main() {
  group('the dishes', () {
    test('there are plenty and every one is well formed', () {
      expect(kDishes.length, greaterThan(80));
      final Set<String> seen = <String>{};
      for (final Dish d in kDishes) {
        expect(seen.add(d.name), isTrue, reason: 'duplicate ${d.name}');
        expect(d.needs, isNotEmpty, reason: d.name);
        expect(d.minutes, inInclusiveRange(1, 90), reason: d.name);
        expect(d.how.length, greaterThan(30), reason: d.name);
        for (final Need n in d.needs) {
          expect(n.keywords, isNotEmpty, reason: d.name);
          expect(n.count, greaterThanOrEqualTo(1));
        }
      }
    });

    test('only the egg dishes are not vegetarian', () {
      expect(
        kDishes
            .where((Dish d) => !d.vegetarian)
            .every(
              (Dish d) => d.needs.any((Need n) => n.keywords.contains('egg')),
            ),
        isTrue,
      );
    });
  });

  group('suggestions', () {
    final List<ItemStock> pantry = <ItemStock>[
      stockOf('Basmati Rice', category: 'cat_grains'),
      stockOf('Moong Dal', category: 'cat_dals'),
      stockOf('Potato'),
      stockOf('Cauliflower'),
      stockOf('Curd', category: 'cat_dairy'),
    ];

    test('finds dishes the pantry can make now', () {
      final List<String> found = names(
        suggestMealIdeas(stocks: pantry, limit: 20),
      );
      expect(found, contains('Moong dal khichdi'));
      expect(found, contains('Aloo gobi'));
      expect(found, contains('Perugu annam (curd rice)'));
    });

    test('a dish that can be made lists what it uses and covers', () {
      final MealIdea khichdi = suggestMealIdeas(
        stocks: pantry,
        limit: 20,
      ).firstWhere((MealIdea i) => i.dish.name == 'Moong dal khichdi');
      expect(khichdi.canMakeNow, isTrue);
      expect(khichdi.uses, containsAll(<String>['Basmati Rice', 'Moong Dal']));
      expect(
        khichdi.fills,
        containsAll(<PlateGroup>[PlateGroup.cereals, PlateGroup.protein]),
      );
    });

    test('dishes that fill a gap come first', () {
      final List<MealIdea> noGap = suggestMealIdeas(stocks: pantry);
      final List<MealIdea> dairyGap = suggestMealIdeas(
        stocks: pantry,
        missing: const <PlateGroup>[PlateGroup.dairy],
      );
      expect(dairyGap.first.fills, contains(PlateGroup.dairy));
      expect(noGap, isNotEmpty);
    });

    test('items that expire soon are used first and flagged', () {
      final List<ItemStock> stocks = <ItemStock>[
        stockOf('Basmati Rice', category: 'cat_grains'),
        stockOf('Tomato', status: StatusKind.expiring),
        stockOf('Lemon'),
      ];
      final List<MealIdea> ideas = suggestMealIdeas(stocks: stocks, limit: 20);
      final MealIdea tomatoRice = ideas.firstWhere(
        (MealIdea i) => i.dish.name == 'Tomato bath (tomato rice)',
      );
      expect(tomatoRice.usesExpiring, <String>['Tomato']);
      expect(
        names(ideas).indexOf('Tomato bath (tomato rice)'),
        lessThan(names(ideas).indexOf('Chitranna (lemon rice)')),
      );
    });

    test('expired and used-up items are never used', () {
      final List<ItemStock> stocks = <ItemStock>[
        stockOf('Basmati Rice', category: 'cat_grains'),
        stockOf('Moong Dal', category: 'cat_dals', status: StatusKind.expired),
        stockOf('Toor Dal', category: 'cat_dals', left: 0),
      ];
      expect(
        names(suggestMealIdeas(stocks: stocks, limit: 20)),
        isNot(contains('Moong dal khichdi')),
      );
    });

    test(
      'a dish missing one thing is offered last, once, with what to buy',
      () {
        final List<MealIdea> ideas = suggestMealIdeas(
          stocks: <ItemStock>[stockOf('Basmati Rice', category: 'cat_grains')],
          limit: 4,
        );
        expect(
          ideas.where((MealIdea i) => !i.canMakeNow).length,
          lessThanOrEqualTo(1),
        );
        for (final MealIdea i in ideas.where((MealIdea i) => !i.canMakeNow)) {
          expect(i.missing.length, 1);
        }
      },
    );

    test('egg dishes only for people who eat eggs', () {
      final List<ItemStock> stocks = <ItemStock>[
        stockOf('Eggs', category: 'cat_meat_eggs'),
        stockOf('Onion'),
      ];
      expect(
        names(suggestMealIdeas(stocks: stocks, limit: 20)),
        isNot(contains('Muttai podimas (egg bhurji)')),
      );
      expect(
        names(suggestMealIdeas(stocks: stocks, vegetarian: false, limit: 20)),
        contains('Muttai podimas (egg bhurji)'),
      );
    });

    test('an empty pantry gives no ideas', () {
      expect(suggestMealIdeas(stocks: const <ItemStock>[]), isEmpty);
    });

    test('needing two vegetables means two different items', () {
      expect(
        names(
          suggestMealIdeas(stocks: <ItemStock>[stockOf('Carrot')], limit: 20),
        ),
        isNot(contains('Vegetable soup')),
      );
      expect(
        names(
          suggestMealIdeas(
            stocks: <ItemStock>[stockOf('Carrot'), stockOf('Beans')],
            limit: 20,
          ),
        ),
        contains('Vegetable soup'),
      );
    });
  });

  group('South Indian first, and eggs', () {
    test('most dishes are South Indian', () {
      final int south = kDishes
          .where((Dish d) => d.cuisine == Cuisine.south)
          .length;
      expect(south / kDishes.length, greaterThan(0.6));
      expect(south, greaterThan(50));
    });

    test('there are several egg dishes, all marked as not vegetarian', () {
      final List<Dish> egg = kDishes
          .where(
            (Dish d) => d.needs.any((Need n) => n.keywords.contains('egg')),
          )
          .toList();
      expect(egg.length, greaterThanOrEqualTo(8));
      expect(egg.every((Dish d) => !d.vegetarian), isTrue);
      expect(
        egg.where((Dish d) => d.cuisine == Cuisine.south).length,
        greaterThanOrEqualTo(7),
      );
    });

    test('well-known Andhra, Tamil, Karnataka and Kerala dishes are there', () {
      final Set<String> all = kDishes.map((Dish d) => d.name).toSet();
      for (final String word in <String>[
        'Mudda pappu',
        'Gongura pappu',
        'Sambar',
        'Pesarattu',
        'Ven pongal',
        'Bisi bele bath',
        'Pulihora',
        'Gutti vankaya',
        'Avial',
        'Kodi guddu kura',
        'Medu vada',
        'Ragi mudde',
      ]) {
        expect(all.any((String n) => n.contains(word)), isTrue, reason: word);
      }
    });

    test('with a mixed pantry, South Indian dishes lead the suggestions', () {
      final List<ItemStock> pantry = <ItemStock>[
        stockOf('Basmati Rice', category: 'cat_grains'),
        stockOf('Toor Dal', category: 'cat_dals'),
        stockOf('Moong Dal', category: 'cat_dals'),
        stockOf('Tomato'),
        stockOf('Onion'),
        stockOf('Potato'),
        stockOf('Curd', category: 'cat_dairy'),
        stockOf('Atta', category: 'cat_grains'),
        stockOf('Paneer', category: 'cat_dairy'),
        stockOf('Peas'),
        stockOf('Okra'),
      ];
      final List<MealIdea> top = suggestMealIdeas(stocks: pantry);
      expect(top.length, 6);
      expect(
        top.where((MealIdea i) => i.dish.cuisine == Cuisine.south).length,
        greaterThanOrEqualTo(4),
      );
    });

    test(
      'eggs in the pantry give several egg dishes when eggs are allowed',
      () {
        final List<ItemStock> pantry = <ItemStock>[
          stockOf('Eggs', category: 'cat_meat_eggs'),
          stockOf('Onion'),
          stockOf('Tomato'),
          stockOf('Basmati Rice', category: 'cat_grains'),
          stockOf('Dosa Batter', category: 'cat_grains'),
        ];
        final List<String> found = names(
          suggestMealIdeas(stocks: pantry, vegetarian: false, limit: 30),
        );
        expect(found, contains('Kodi guddu kura (Andhra egg curry)'));
        expect(found, contains('Muttai podimas (egg bhurji)'));
        expect(found, contains('Masala omelette'));
        expect(found, contains('Egg dosa'));
        expect(found, contains('Egg fried rice'));
        expect(
          names(
            suggestMealIdeas(stocks: pantry, limit: 30),
          ).any((String n) => n.contains('Egg') || n.contains('egg')),
          isFalse,
          reason: 'none for a vegetarian',
        );
      },
    );
  });
}
