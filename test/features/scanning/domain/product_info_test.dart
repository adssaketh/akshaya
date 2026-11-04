import 'package:akshaya/features/pantry/domain/unit.dart';
import 'package:akshaya/features/scanning/domain/product_info.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parsePackSize', () {
    void expectPack(String? text, double amount, Unit unit) {
      final PackSize? pack = parsePackSize(text);
      expect(pack, isNotNull, reason: text);
      expect(pack!.amount, closeTo(amount, 0.0001), reason: text);
      expect(pack.unit, unit, reason: text);
    }

    test('reads common pack sizes', () {
      expectPack('500 g', 500, Unit.g);
      expectPack('250g', 250, Unit.g);
      expectPack('2 kg', 2, Unit.kg);
      expectPack('1 L', 1, Unit.l);
      expectPack('750 ml', 750, Unit.ml);
      expectPack('1 litre', 1, Unit.l);
      expectPack('6 pcs', 6, Unit.pcs);
    });

    test('accepts a decimal comma', () {
      expectPack('1,5 l', 1.5, Unit.l);
    });

    test('multiplies multipacks', () {
      expectPack('6 x 100 g', 600, Unit.g);
      expectPack('2 × 250 ml', 500, Unit.ml);
    });

    test('shows 1000 g and 1000 ml or more as kg and L', () {
      expectPack('1000 g', 1, Unit.kg);
      expectPack('1500 ml', 1.5, Unit.l);
    });

    test('converts cl and dl to ml', () {
      expectPack('33 cl', 330, Unit.ml);
      expectPack('5 dl', 500, Unit.ml);
    });

    test('ignores text after the first size', () {
      expectPack('500 g (2 x 250 g)', 500, Unit.g);
    });

    test('returns null when there is no size', () {
      expect(parsePackSize(null), isNull);
      expect(parsePackSize(''), isNull);
      expect(parsePackSize('family pack'), isNull);
      expect(parsePackSize('0 g'), isNull);
      expect(parsePackSize('12 gummies'), isNull);
    });
  });

  group('categoryIdForTags', () {
    test('maps dairy and keeps milk out of beverages', () {
      expect(
        categoryIdForTags(<String>['en:beverages', 'en:dairies', 'en:milks']),
        'cat_dairy',
      );
    });

    test('maps ghee and oils', () {
      expect(categoryIdForTags(<String>['en:clarified-butters']), 'cat_oils');
      expect(categoryIdForTags(<String>['en:vegetable-oils']), 'cat_oils');
    });

    test('maps rice, dals, snacks and drinks', () {
      expect(categoryIdForTags(<String>['en:rices']), 'cat_grains');
      expect(categoryIdForTags(<String>['en:lentils']), 'cat_dals');
      expect(
        categoryIdForTags(<String>['en:snacks', 'en:biscuits-and-cakes']),
        'cat_snacks',
      );
      expect(
        categoryIdForTags(<String>['en:beverages', 'en:juices']),
        'cat_beverages',
      );
    });

    test('matches whole words, not parts of words', () {
      // "boiled" contains "oil" but is not an oil.
      expect(categoryIdForTags(<String>['en:boiled-things']), 'cat_other');
    });

    test('falls back to Other', () {
      expect(categoryIdForTags(const <String>[]), 'cat_other');
      expect(categoryIdForTags(<String>['en:mystery']), 'cat_other');
    });
  });

  group('ProductInfo json', () {
    test('round trips', () {
      const ProductInfo info = ProductInfo(
        name: 'Salted Butter',
        brand: 'Amul',
        quantityText: '500 g',
        categoryTags: <String>['en:butters'],
      );
      final ProductInfo? back = ProductInfo.fromJson(info.toJson());
      expect(back, isNotNull);
      expect(back!.name, 'Salted Butter');
      expect(back.brand, 'Amul');
      expect(back.quantityText, '500 g');
      expect(back.categoryTags, <String>['en:butters']);
      expect(back.suggestedCategoryId, 'cat_dairy');
      expect(back.packSize!.unit, Unit.g);
    });

    test('rejects unusable json', () {
      expect(ProductInfo.fromJson(null), isNull);
      expect(ProductInfo.fromJson(<String, Object?>{'name': '  '}), isNull);
      expect(ProductInfo.fromJson('text'), isNull);
    });
  });
}
