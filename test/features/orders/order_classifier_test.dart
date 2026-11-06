import 'package:akshaya/features/commands/domain/grocery_lexicon.dart';
import 'package:akshaya/features/orders/domain/order_classifier.dart';
import 'package:akshaya/features/orders/domain/order_models.dart';
import 'package:akshaya/features/pantry/domain/entities.dart';
import 'package:akshaya/features/pantry/domain/storage_location.dart';
import 'package:akshaya/features/pantry/domain/unit.dart';
import 'package:flutter_test/flutter_test.dart';

import '../commands/domain/command_test_support.dart';

void main() {
  late OrderClassifier classifier;

  setUp(() {
    classifier = OrderClassifier(GroceryLexicon.build(loadDictionary()));
  });

  OrderClassification run(
    String name, {
    List<String> hints = const <String>[],
    bool truncated = false,
  }) {
    return classifier.classify(name, hints: hints, truncated: truncated);
  }

  test('names a branded product from the dictionary and keeps the brand', () {
    final OrderClassification c = run('Tata Sampann Unpolished Chana Dal');
    expect(c.name, 'Chana Dal');
    expect(c.brand, 'Tata Sampann');
    expect(c.categoryId, 'cat_dals');
    expect(c.skip, isNull);
    expect(c.matched, isTrue);
  });

  test('English names come out of long printed names', () {
    expect(run('Basic Kabuli Chana (Small Size)').name, 'Chickpeas');
    expect(run('Tata Sampann Toor Dal/Arhar Dal (Split)').name, 'Toor Dal');
    expect(run('Sid\'s Farm Malai Paneer').name, 'Paneer');
    expect(run('Garlic (Velluli)').name, 'Garlic');
  });

  test('vegetables, fruits and dairy are kept cool or on the shelf by type',
      () {
    final OrderClassification garlic = run('Garlic');
    expect(garlic.categoryId, 'cat_vegetables');
    expect(garlic.location, StorageLocation.pantry);
    expect(garlic.estimateDays, 14);

    final OrderClassification capsicum = run('Green Capsicum (Shimla Mirch)');
    expect(capsicum.location, StorageLocation.fridge);
    expect(capsicum.estimateDays, 5);

    final OrderClassification milk = run('Sid\'s Farm Tested Toned Milk');
    expect(milk.categoryId, 'cat_dairy');
    expect(milk.location, StorageLocation.fridge);
    expect(milk.estimateDays, 3);
  });

  test('eggs are food and keep two weeks in the fridge', () {
    final OrderClassification c =
        run('Eggs By Henfruit - Max Protein Specialty Eggs');
    expect(c.name, 'Eggs');
    expect(c.categoryId, 'cat_meat_eggs');
    expect(c.skip, isNull);
    expect(c.estimateDays, 14);
  });

  test('packaged goods get no expiry guess', () {
    expect(run('Tata Sampann Chana Dal (Split)').estimateDays, isNull);
    expect(run('Catch Pav Bhaji Masala').estimateDays, isNull);
  });

  test('a masala is a spice, not meat', () {
    final OrderClassification c = run('Everest Chicken Masala Powder');
    expect(c.skip, isNull);
    expect(c.categoryId, 'cat_spices');
  });

  test('non-food lines are skipped by default, with the right category', () {
    expect(run('Harpic Power Plus Jas', truncated: true).skip,
        SkipReason.notFood);
    expect(run('Harpic Power Plus Jas', truncated: true).categoryId,
        'cat_cleaning');
    final OrderClassification dettol =
        run('Dettol Liquid Hand wa', truncated: true);
    expect(dettol.skip, SkipReason.notFood);
    expect(dettol.categoryId, 'cat_personal_care');
    expect(run('WishCare Hydrating AHA BHA Anti Dandr').skip,
        SkipReason.notFood);
    final OrderClassification thermometer =
        run('Themisto Digital LCD Kitchen Thermometer - White');
    expect(thermometer.skip, SkipReason.notFood);
    expect(thermometer.categoryId, 'cat_other');
    expect(run('Zepbake Baking Paper, Cooking, Parchment paper').skip,
        SkipReason.notFood);
  });

  test('meat and fish are unticked as not vegetarian', () {
    expect(run('Fresh Chicken Curry Cut').skip, SkipReason.notVegetarian);
    expect(run('Rohu Fish Fillet').skip, SkipReason.notVegetarian);
    expect(run('Chicken Breast Boneless').skip, SkipReason.notVegetarian);
  });

  test('a brand is read off the front and the product named', () {
    final OrderClassification c = run('Parle Hide & Seek Biscuits');
    expect(c.brand, 'Parle');
    expect(c.name, 'Biscuits');
    expect(c.categoryId, 'cat_snacks');
  });

  test('an unknown product is still filed by its words', () {
    final OrderClassification c = run('Tata Sampann White');
    expect(c.matched, isFalse);
    expect(c.categoryId, 'cat_other');
    final OrderClassification sauce = run('Kissan Fresh Tomato Ketchup');
    expect(sauce.matched, isFalse);
    expect(sauce.name, 'Kissan Fresh Tomato Ketchup');
    expect(sauce.categoryId, 'cat_other');
  });

  test('a cut-off name is identified from the thumbnail text when possible',
      () {
    final OrderClassification c = run(
      'Tata Sampann White',
      hints: <String>['Urad Dal'],
      truncated: true,
    );
    expect(c.matched, isTrue);
    expect(c.categoryId, 'cat_dals');
  });

  test('a pantry item answers to its own name and aliases', () {
    final Item rice = Item(
      id: 'rice-1',
      name: 'Sona Masoori Rice',
      categoryId: 'cat_grains',
      defaultUnit: Unit.kg,
      aliases: const <String>['India Gate Classic'],
      isEssential: true,
      defaultStorageLocation: StorageLocation.pantry,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    final OrderClassifier withPantry = OrderClassifier(
      GroceryLexicon.build(loadDictionary(), items: <Item>[rice]),
    );
    final OrderClassification c =
        withPantry.classify('India Gate Classic');
    expect(c.matchedItemId, 'rice-1');
    expect(c.name, 'Sona Masoori Rice');
  });
}
