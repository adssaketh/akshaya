import 'package:akshaya/features/pantry/domain/unit.dart';
import 'package:akshaya/features/report/domain/nutrition_table.dart';
import 'package:akshaya/features/report/domain/report_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('findFoodEnergy', () {
    FoodGroup? group(String name) => findFoodEnergy(name)?.group;

    test('finds common groceries by name, ignoring case and plurals', () {
      expect(group('Basmati Rice'), FoodGroup.cereals);
      expect(group('toor dal'), FoodGroup.pulses);
      expect(group('Tomatoes'), FoodGroup.vegetables);
      expect(group('Banana'), FoodGroup.fruits);
      expect(group('Curd'), FoodGroup.dairy);
      expect(group('Eggs'), FoodGroup.meatEggs);
    });

    test('the specific food wins over the general one', () {
      expect(group('Coconut Oil'), FoodGroup.fats, reason: 'not the coconut');
      expect(group('Sweet Potato'), FoodGroup.tubers);
      expect(
        findFoodEnergy('Sweet Potato')!.kcalPer100g,
        86,
        reason: 'not the plain potato',
      );
      expect(group('Buttermilk'), FoodGroup.dairy, reason: 'not butter');
      expect(group('Peanut Butter'), FoodGroup.fats);
      expect(group('Chana Dal'), FoodGroup.pulses);
    });

    test('matches whole words only', () {
      expect(
        findFoodEnergy('Boiled sweets'),
        isNull,
        reason: '"oil" is inside "boiled"',
      );
      expect(findFoodEnergy('Dishwash liquid'), isNull);
    });

    test('also looks at aliases', () {
      expect(
        findFoodEnergy('Aloo', const <String>['batata'])?.group,
        FoodGroup.tubers,
      );
      expect(
        findFoodEnergy('Special flour', const <String>['atta'])?.group,
        FoodGroup.cereals,
      );
    });
  });

  group('estimateEnergy', () {
    test('weighs mass units', () {
      final EnergyEstimate e = estimateEnergy(
        findFoodEnergy('Rice')!,
        500,
        Unit.g,
      )!;
      expect(e.kcal, closeTo(1775, 0.5));
      expect(e.grams, 500);
      expect(
        estimateEnergy(findFoodEnergy('Rice')!, 0.5, Unit.kg)!.kcal,
        closeTo(1775, 0.5),
      );
    });

    test('uses the per 100 ml figure for liquids', () {
      expect(
        estimateEnergy(findFoodEnergy('Sunflower Oil')!, 1, Unit.l)!.kcal,
        closeTo(8200, 0.5),
      );
      expect(
        estimateEnergy(findFoodEnergy('Milk')!, 500, Unit.ml)!.kcal,
        closeTo(310, 0.5),
      );
    });

    test('counts pieces and dozens when the piece weight is known', () {
      final FoodEnergy egg = findFoodEnergy('Eggs')!;
      expect(estimateEnergy(egg, 6, Unit.pcs)!.kcal, closeTo(429, 0.5));
      expect(estimateEnergy(egg, 0.5, Unit.dozen)!.kcal, closeTo(429, 0.5));
    });

    test('counts a bunch of leaves', () {
      final EnergyEstimate e = estimateEnergy(
        findFoodEnergy('Spinach')!,
        1,
        Unit.bunch,
      )!;
      expect(e.grams, 250);
      expect(e.kcal, closeTo(57.5, 0.5));
    });

    test('says nothing when the amount cannot be weighed', () {
      expect(estimateEnergy(findFoodEnergy('Rice')!, 1, Unit.packet), isNull);
      expect(estimateEnergy(findFoodEnergy('Rice')!, 1, Unit.portion), isNull);
      expect(
        estimateEnergy(findFoodEnergy('Rice')!, 2, Unit.pcs),
        isNull,
        reason: 'rice has no piece weight',
      );
      expect(estimateEnergy(findFoodEnergy('Rice')!, 0, Unit.kg), isNull);
    });
  });

  test('categories map to a food group when the name is unknown', () {
    expect(groupForCategory('cat_vegetables'), FoodGroup.vegetables);
    expect(groupForCategory('cat_bakery'), FoodGroup.cereals);
    expect(groupForCategory('cat_cleaning'), FoodGroup.other);
    expect(
      kCategoryEnergyFallback.containsKey('cat_dairy'),
      isFalse,
      reason: 'dairy products differ too much for a group figure',
    );
  });

  group('the table itself', () {
    test('is much bigger than before and covers Indian staples', () {
      expect(kFoodEnergyTable.length, greaterThan(190));
      for (final String name in <String>[
        'Ragi flour',
        'Horse gram',
        'Makhana',
        'Rajgira',
        'Ridge gourd',
        'Ivy gourd',
        'Drumstick',
        'Gongura',
        'Amla',
        'Jamun',
        'Sattu',
        'Kuttu atta',
        'Moth beans',
        'Tofu',
        'Lassi',
        'Idli batter',
      ]) {
        expect(findFoodEnergy(name), isNotNull, reason: name);
      }
    });

    test('every keyword is lower case, plain and used only once', () {
      final Set<String> seen = <String>{};
      for (final FoodEnergy e in kFoodEnergyTable) {
        expect(e.keywords, isNotEmpty);
        for (final String k in e.keywords) {
          expect(k, k.toLowerCase().trim(), reason: k);
          expect(RegExp(r'^[a-z ]+$').hasMatch(k), isTrue, reason: k);
          expect(seen.add(k), isTrue, reason: 'keyword "$k" is in two entries');
        }
      }
    });

    test('calories agree with protein, carbs, fat and fibre', () {
      // Catches typing slips (a decimal point in the wrong place). It cannot
      // tell a value that is wrong in the source.
      for (final FoodEnergy e in kFoodEnergyTable) {
        final double kcal = e.kcalPer100g!;
        final double sum =
            4 * e.protein +
            4 * (e.carbs - e.fibre).clamp(0, double.infinity) +
            9 * e.fat +
            2 * e.fibre;
        expect(
          (sum - kcal).abs() <= (0.35 * kcal > 10 ? 0.35 * kcal : 10),
          isTrue,
          reason:
              '${e.keywords.first}: $kcal kcal but nutrients sum to '
              '${sum.round()}',
        );
      }
    });

    test('nutrients are possible: no more than 100 g in 100 g', () {
      for (final FoodEnergy e in kFoodEnergyTable) {
        expect(
          e.protein + e.carbs + e.fat,
          lessThanOrEqualTo(100.5),
          reason: e.keywords.first,
        );
        expect(
          e.fibre,
          lessThanOrEqualTo(e.carbs + 0.01),
          reason: e.keywords.first,
        );
        expect(
          <double>[
            e.protein,
            e.carbs,
            e.fat,
            e.fibre,
          ].every((double v) => v >= 0),
          isTrue,
        );
      }
    });

    test('animal foods are in the meat and egg group only', () {
      for (final FoodEnergy e in kFoodEnergyTable) {
        if (e.group == FoodGroup.meatEggs) {
          expect(
            e.keywords.any(
              (String k) => <String>{
                'egg',
                'chicken',
                'mutton',
                'prawn',
                'fish',
              }.contains(k),
            ),
            isTrue,
            reason: e.keywords.first,
          );
        }
      }
    });
  });

  group('nutrients in an amount', () {
    test('500 g of rice', () {
      final EnergyEstimate e = estimateEnergy(
        findFoodEnergy('Rice')!,
        500,
        Unit.g,
      )!;
      expect(e.protein, closeTo(35, 0.5));
      expect(e.carbs, closeTo(390, 0.5));
      expect(e.fat, closeTo(3, 0.5));
    });

    test(
      'a litre of oil is about 928 g of fat, as oil is lighter than water',
      () {
        final EnergyEstimate e = estimateEnergy(
          findFoodEnergy('Sunflower Oil')!,
          1,
          Unit.l,
        )!;
        expect(e.fat, closeTo(927.6, 1));
        expect(e.protein, 0);
      },
    );

    test('six eggs', () {
      final EnergyEstimate e = estimateEnergy(
        findFoodEnergy('Eggs')!,
        6,
        Unit.pcs,
      )!;
      expect(e.protein, closeTo(37.8, 0.5));
    });

    test('dal brings fibre', () {
      final EnergyEstimate e = estimateEnergy(
        findFoodEnergy('Toor Dal')!,
        100,
        Unit.g,
      )!;
      expect(e.fibre, greaterThan(10));
      expect(e.protein, closeTo(22, 0.5));
    });
  });

  group('roots and tubers', () {
    test('potato and other starchy roots are not counted as vegetables', () {
      for (final String name in <String>[
        'Potato',
        'Sweet Potato',
        'Yam',
        'Arbi',
        'Tapioca',
      ]) {
        expect(findFoodEnergy(name)!.group, FoodGroup.tubers, reason: name);
      }
      expect(findFoodEnergy('Raw Banana')!.group, FoodGroup.vegetables);
      expect(findFoodEnergy('Tomato')!.group, FoodGroup.vegetables);
    });

    test('and do not count towards a plate group', () {
      expect(plateGroupOf(FoodGroup.tubers), isNull);
      expect(plateGroupOf(FoodGroup.vegetables), PlateGroup.vegetables);
    });
  });

  group('the amount that was eaten', () {
    test('is in grams for weights and millilitres for liquids', () {
      expect(
        estimateEnergy(findFoodEnergy('Rice')!, 0.5, Unit.kg)!.amount,
        500,
      );
      expect(
        estimateEnergy(findFoodEnergy('Milk')!, 0.25, Unit.l)!.amount,
        250,
      );
      expect(
        estimateEnergy(findFoodEnergy('Eggs')!, 2, Unit.pcs)!.amount,
        100,
        reason: 'two eggs of 50 g',
      );
    });

    test('everything scales with the quantity: double the amount, double '
        'the nutrients', () {
      final FoodEnergy dal = findFoodEnergy('Toor Dal')!;
      final EnergyEstimate a = estimateEnergy(dal, 150, Unit.g)!;
      final EnergyEstimate b = estimateEnergy(dal, 300, Unit.g)!;
      expect(b.kcal, closeTo(2 * a.kcal, 0.0001));
      expect(b.protein, closeTo(2 * a.protein, 0.0001));
      expect(b.carbs, closeTo(2 * a.carbs, 0.0001));
      expect(b.fat, closeTo(2 * a.fat, 0.0001));
      expect(b.fibre, closeTo(2 * a.fibre, 0.0001));
    });

    test('150 g of dal is NOT shown as 100 g', () {
      final EnergyEstimate e = estimateEnergy(
        findFoodEnergy('Toor Dal')!,
        150,
        Unit.g,
      )!;
      expect(e.protein, closeTo(33, 0.01), reason: '22 g per 100 g x 1.5');
      expect(e.kcal, closeTo(502.5, 0.01));
    });
  });
}
