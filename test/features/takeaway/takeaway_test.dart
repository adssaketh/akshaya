import 'package:akshaya/features/ai/domain/ai_failures.dart';
import 'package:akshaya/features/pantry/domain/entities.dart';
import 'package:akshaya/features/pantry/domain/unit.dart';
import 'package:akshaya/features/report/domain/nutrition_table.dart';
import 'package:akshaya/features/report/domain/report_builder.dart';
import 'package:akshaya/features/report/domain/report_models.dart';
import 'package:akshaya/features/takeaway/domain/food_estimate.dart';
import 'package:akshaya/features/takeaway/domain/takeaway_models.dart';
import 'package:flutter_test/flutter_test.dart';

const String _dosa = '''
{"ingredients":[{"name":"Rice batter","grams":90},{"name":"Oil","grams":8}],
 "is_food":true,"group":"cereals","serving_grams":150,"kcal":220,
 "protein_g":5,"carbs_g":35,"fat_g":7,"fibre_g":1.5,"grams_per_piece":150}
''';

void main() {
  group('FoodEstimate', () {
    test('reads a good Gemini answer and round-trips', () {
      final FoodEstimate e = FoodEstimate.parseGemini(_dosa);
      expect(e.isFood, isTrue);
      expect(e.group, FoodGroup.cereals);
      expect(e.ingredientsLabel, 'Rice batter 90 g, Oil 8 g');
      final FoodEstimate? back = FoodEstimate.decode(e.encode());
      expect(back!.kcal, 220);
      expect(back.ingredients.length, 2);
    });

    test('refuses calories that do not match the nutrients', () {
      const String bad =
          '{"is_food":true,"group":"cereals","serving_grams":150,"kcal":900,'
          '"protein_g":5,"carbs_g":35,"fat_g":7,"fibre_g":1,"ingredients":[]}';
      expect(
        () => FoodEstimate.parseGemini(bad),
        throwsA(isA<AiInvalidResponseFailure>()),
      );
      expect(
        () => FoodEstimate.parseGemini('not json'),
        throwsA(isA<AiInvalidResponseFailure>()),
      );
    });

    test('not food is remembered as not food', () {
      final FoodEstimate e = FoodEstimate.parseGemini('{"is_food":false}');
      expect(e.isFood, isFalse);
      expect(FoodEstimate.decode(e.encode())!.isFood, isFalse);
    });

    test('keys ignore case and punctuation', () {
      expect(estimateKey('Masala  Dosa!'), 'masala dosa');
    });
  });

  group('report', () {
    final DateTime today = DateTime(2026, 11, 11);

    test('a takeaway counts with its estimate', () {
      final FoodEstimate e = FoodEstimate.parseGemini(_dosa);
      final ConsumptionReport r = buildConsumptionReport(
        period: ReportPeriod.today,
        today: today,
        history: const <ConsumptionEntry>[],
        itemsById: const <String, Item>{},
        people: 1,
        takeaways: <TakeawayMeal>[
          TakeawayMeal(
            id: 't1',
            name: 'Dosa',
            meal: MealSlot.breakfast,
            portions: 2,
            eatenOn: today,
            estimate: e,
          ),
        ],
      );
      expect(r.totalKcal, 440);
      expect(r.lines.single.name, 'Dosa (takeaway)');
      expect(r.lines.single.quantityLabel, '2 portions');
    });

    test('a takeaway without an estimate is listed but not counted', () {
      final ConsumptionReport r = buildConsumptionReport(
        period: ReportPeriod.today,
        today: today,
        history: const <ConsumptionEntry>[],
        itemsById: const <String, Item>{},
        people: 1,
        takeaways: <TakeawayMeal>[
          TakeawayMeal(
            id: 't1',
            name: 'Dosa',
            meal: MealSlot.lunch,
            portions: 1,
            eatenOn: today,
          ),
        ],
      );
      expect(r.totalKcal, 0);
      expect(r.lines.single.kcal, isNull);
    });
  });

  test('validation', () {
    expect(validateTakeaway(name: ' ', portions: 1, price: null), isNotNull);
    expect(validateTakeaway(name: 'Dosa', portions: 0, price: null), isNotNull);
    expect(validateTakeaway(name: 'Dosa', portions: 1, price: 120), isNull);
    expect(Unit.portion.format(2), '2 portions');
  });
}
