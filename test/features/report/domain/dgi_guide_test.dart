import 'package:akshaya/features/report/domain/dgi_guide.dart';
import 'package:akshaya/features/report/domain/nutrition_table.dart';
import 'package:flutter_test/flutter_test.dart';

PlateTarget target(List<PlateTarget> plate, FoodGroup g) =>
    plate.firstWhere((PlateTarget t) => t.group == g);

void main() {
  test('the source is named', () {
    expect(kDgiSource, contains('ICMR-NIN'));
    expect(kDgiSource, contains('2024'));
  });

  group('protein for an energy level', () {
    test('follows the guideline\'s sample diets within a couple of grams', () {
      // 55 kg woman 1,660 kcal: 57 g. 65 kg man 2,080: 72 g. Woman, active,
      // 2,125: 72 g. Man, active, 2,680: 90 g.
      expect(proteinGuideFor(1660), closeTo(57, 1.5));
      expect(proteinGuideFor(2080), closeTo(72, 1.5));
      expect(proteinGuideFor(2125), closeTo(72, 1.5));
      expect(proteinGuideFor(2680), closeTo(90, 2.5));
    });

    test('rises with energy', () {
      expect(proteinGuideFor(2200), greaterThan(proteinGuideFor(1800)));
    });
  });

  test('fibre is about 25 g for every 1,000 kcal', () {
    expect(fibreGuideFor(2000), 50);
    expect(fibreGuideFor(1000), 25);
    expect(kFibreMinimumGrams, 25);
  });

  group('the plate for a person', () {
    test('at 2,000 kcal it is the guideline\'s My Plate for the Day', () {
      final List<PlateTarget> p = plateFor(kcal: 2000, eggs: false);
      expect(target(p, FoodGroup.cereals).amount, 250);
      expect(target(p, FoodGroup.pulses).amount, 85);
      expect(target(p, FoodGroup.dairy).amount, 300);
      expect(target(p, FoodGroup.dairy).unit, 'ml');
      expect(target(p, FoodGroup.vegetables).amount, 400);
      expect(target(p, FoodGroup.fruits).amount, 100);
      expect(target(p, FoodGroup.nutsSeeds).amount, 35);
      expect(
        target(p, FoodGroup.fats).amount,
        25,
        reason: '27 g, rounded to the nearest 5',
      );
    });

    test('grains, pulses, nuts and oil follow the sample diets', () {
      final List<PlateTarget> woman = plateFor(kcal: 1660, eggs: false);
      final List<PlateTarget> man = plateFor(kcal: 2680, eggs: false);
      expect(target(woman, FoodGroup.cereals).amount, 190);
      expect(target(woman, FoodGroup.pulses).amount, 60);
      expect(target(man, FoodGroup.cereals).amount, 370);
      expect(target(man, FoodGroup.pulses).amount, 120);
      expect(target(man, FoodGroup.fats).amount, 40);
    });

    test('vegetables, fruit and milk do not change with energy', () {
      for (final int kcal in <int>[1660, 2080, 2680]) {
        final List<PlateTarget> p = plateFor(kcal: kcal, eggs: false);
        expect(target(p, FoodGroup.vegetables).amount, 400);
        expect(target(p, FoodGroup.fruits).amount, 100);
        expect(target(p, FoodGroup.dairy).amount, 300);
      }
    });

    test('grains rise with energy, never fall', () {
      double last = 0;
      for (int kcal = 1200; kcal <= 3500; kcal += 100) {
        final double c = target(
          plateFor(kcal: kcal, eggs: false),
          FoodGroup.cereals,
        ).amount;
        expect(c, greaterThanOrEqualTo(last), reason: '$kcal kcal');
        last = c;
      }
    });

    test('with eggs there is less dal and 70 g of eggs', () {
      final List<PlateTarget> veg = plateFor(kcal: 2000, eggs: false);
      final List<PlateTarget> egg = plateFor(kcal: 2000, eggs: true);
      expect(
        veg.any((PlateTarget t) => t.group == FoodGroup.meatEggs),
        isFalse,
      );
      expect(target(egg, FoodGroup.meatEggs).amount, 70);
      expect(target(egg, FoodGroup.pulses).amount, 55);
    });

    test('oil and sugar are limits, the rest are aims', () {
      final List<PlateTarget> p = plateFor(kcal: 2000, eggs: false);
      expect(
        p
            .where((PlateTarget t) => t.isLimit)
            .map((PlateTarget t) => t.group)
            .toSet(),
        <FoodGroup>{FoodGroup.fats, FoodGroup.sugars},
      );
      expect(target(p, FoodGroup.sugars).amount, 30);
    });

    test('every target is a sensible, positive amount', () {
      for (final int kcal in <int>[1200, 1660, 2000, 2680, 3500]) {
        for (final bool eggs in <bool>[false, true]) {
          for (final PlateTarget t in plateFor(kcal: kcal, eggs: eggs)) {
            expect(t.amount, greaterThan(0), reason: '${t.label} at $kcal');
            expect(t.amount, lessThan(1000));
          }
        }
      }
    });
  });

  test('the reference adults are the guideline\'s four', () {
    expect(kReferenceAdults.map((ReferenceAdult a) => a.kcal).toList(), <int>[
      1660,
      2080,
      2125,
      2680,
    ]);
  });
}
