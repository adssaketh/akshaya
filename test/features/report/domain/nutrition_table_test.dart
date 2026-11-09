import 'package:akshaya/features/pantry/domain/unit.dart';
import 'package:akshaya/features/report/domain/nutrition_table.dart';
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
      expect(group('Sweet Potato'), FoodGroup.vegetables);
      expect(findFoodEnergy('Sweet Potato')!.kcalPer100g, 86,
          reason: 'not the plain potato');
      expect(group('Buttermilk'), FoodGroup.dairy, reason: 'not butter');
      expect(group('Peanut Butter'), FoodGroup.fats);
      expect(group('Chana Dal'), FoodGroup.pulses);
    });

    test('matches whole words only', () {
      expect(findFoodEnergy('Boiled sweets'), isNull,
          reason: '"oil" is inside "boiled"');
      expect(findFoodEnergy('Dishwash liquid'), isNull);
    });

    test('also looks at aliases', () {
      expect(
        findFoodEnergy('Aloo', const <String>['batata'])?.group,
        FoodGroup.vegetables,
      );
      expect(
        findFoodEnergy('Special flour', const <String>['atta'])?.group,
        FoodGroup.cereals,
      );
    });
  });

  group('estimateEnergy', () {
    test('weighs mass units', () {
      final EnergyEstimate e =
          estimateEnergy(findFoodEnergy('Rice')!, 500, Unit.g)!;
      expect(e.kcal, closeTo(1775, 0.5));
      expect(e.grams, 500);
      expect(estimateEnergy(findFoodEnergy('Rice')!, 0.5, Unit.kg)!.kcal,
          closeTo(1775, 0.5));
    });

    test('uses the per 100 ml figure for liquids', () {
      expect(estimateEnergy(findFoodEnergy('Sunflower Oil')!, 1, Unit.l)!.kcal,
          closeTo(8200, 0.5));
      expect(estimateEnergy(findFoodEnergy('Milk')!, 500, Unit.ml)!.kcal,
          closeTo(310, 0.5));
    });

    test('counts pieces and dozens when the piece weight is known', () {
      final FoodEnergy egg = findFoodEnergy('Eggs')!;
      expect(estimateEnergy(egg, 6, Unit.pcs)!.kcal, closeTo(429, 0.5));
      expect(estimateEnergy(egg, 0.5, Unit.dozen)!.kcal, closeTo(429, 0.5));
    });

    test('counts a bunch of leaves', () {
      final EnergyEstimate e =
          estimateEnergy(findFoodEnergy('Spinach')!, 1, Unit.bunch)!;
      expect(e.grams, 250);
      expect(e.kcal, closeTo(57.5, 0.5));
    });

    test('says nothing when the amount cannot be weighed', () {
      expect(estimateEnergy(findFoodEnergy('Rice')!, 1, Unit.packet), isNull);
      expect(estimateEnergy(findFoodEnergy('Rice')!, 1, Unit.portion), isNull);
      expect(estimateEnergy(findFoodEnergy('Rice')!, 2, Unit.pcs), isNull,
          reason: 'rice has no piece weight');
      expect(estimateEnergy(findFoodEnergy('Rice')!, 0, Unit.kg), isNull);
    });
  });

  test('categories map to a food group when the name is unknown', () {
    expect(groupForCategory('cat_vegetables'), FoodGroup.vegetables);
    expect(groupForCategory('cat_bakery'), FoodGroup.cereals);
    expect(groupForCategory('cat_cleaning'), FoodGroup.other);
    expect(kCategoryEnergyFallback.containsKey('cat_dairy'), isFalse,
        reason: 'dairy products differ too much for a group figure');
  });
}
