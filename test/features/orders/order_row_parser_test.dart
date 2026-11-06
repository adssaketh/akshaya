import 'package:akshaya/features/orders/domain/ocr_models.dart';
import 'package:akshaya/features/orders/domain/order_models.dart';
import 'package:akshaya/features/orders/domain/order_row_parser.dart';
import 'package:akshaya/features/pantry/domain/unit.dart';
import 'package:flutter_test/flutter_test.dart';

import 'order_fixtures.dart';

class _Expect {
  const _Expect(
    this.name,
    this.quantity,
    this.unit,
    this.sized,
    this.price,
    this.truncated,
  );

  final String name;
  final double quantity;
  final Unit unit;
  final bool sized;
  final double? price;
  final bool truncated;
}

const Map<String, List<_Expect>> _expected = <String, List<_Expect>>{
  'blinkit': <_Expect>[
    _Expect('Basic Kabuli Chana (Small Size)', 1.0, Unit.kg, true, 98.0, false),
    _Expect('Conscious Food Tamarind (Imli) - Seedless', 200.0, Unit.g, true, 82.0, false),
    _Expect('Catch Dhania / Coriander Seeds', 100.0, Unit.g, true, 39.0, false),
    _Expect('Orika Fenugreek/ Methi Seeds', 150.0, Unit.g, true, 34.0, false),
    _Expect('Catch Pav Bhaji Masala', 100.0, Unit.g, true, 62.0, false),
    _Expect('Tata Sampann Unpolished Chana Dal', 500.0, Unit.g, true, 65.0, false),
    _Expect('Popular Essentials Premium Cashew Split', 100.0, Unit.g, true, 99.0, false),
    _Expect('Whole Farm Premium Stemless Red Chilli Whole', 100.0, Unit.g, true, 70.0, false),
    _Expect('Amruth Raj Small Mustard Seeds', 100.0, Unit.g, true, 22.0, false),
    _Expect('Whole Farm Premium Ajwain Seeds', 100.0, Unit.g, true, 37.0, false),
  ],
  'zepto': <_Expect>[
    _Expect('The Select Aisle Dark Choco Chips', 150.0, Unit.g, true, 165.81, false),
    _Expect('Akshayakalpa Organic Unsalted Cooking Butter', 100.0, Unit.g, true, 112.2, false),
    _Expect('Eggs By Henfruit - Max Protein Specialty Eggs', 10.0, Unit.pcs, true, 121.13, false),
    _Expect("Sid's Farm Tested Toned Milk (No Antibiotics . No Hormones . No Preservati", 1.0, Unit.l, true, 76.0, true),
    _Expect('Akshayakalpa Organic Probiotic Curd Pouch', 500.0, Unit.g, true, 57.59, false),
    _Expect("Sid's Farm Malai Paneer", 200.0, Unit.g, true, 140.99, false),
    _Expect('The Select Aisle Double Acting Baking Powder', 100.0, Unit.g, true, 31.78, false),
    _Expect('Garlic (Velluli)', 100.0, Unit.g, true, 27.77, false),
    _Expect('Zepbake Baking Paper, Cooking, Parchment paper | 10 Meter', 1.0, Unit.packet, false, 104.25, false),
  ],
  'amazon': <_Expect>[
    _Expect('Tata Sampann Toor Dal/Arhar Dal (Split)', 1.0, Unit.kg, true, 164.0, false),
    _Expect('Tata Sampann Chana Dal (Split)', 1.0, Unit.kg, true, 133.0, false),
    _Expect('Tata Sampann Yellow Moong Dal (Split)', 1.0, Unit.kg, true, 169.0, false),
    _Expect('Fresh Green Chilli', 200.0, Unit.g, true, 32.0, false),
    _Expect('Themisto Digital LCD Kitchen Thermometer - White', 1.0, Unit.pcs, false, 157.0, false),
    _Expect('Organic India Jaggery Powder', 500.0, Unit.g, true, 94.0, false),
    _Expect('Tata Sampann Whole Spice Cumin Seeds', 100.0, Unit.g, true, 56.0, false),
    _Expect("Sid's Farm Malai Paneer", 200.0, Unit.g, true, 135.0, false),
  ],
  'swiggy': <_Expect>[
    _Expect('Garlic', 1.0, Unit.packet, false, 39.0, false),
    _Expect('WishCare Hydrating AHA BHA Anti Dandr', 1.0, Unit.packet, false, 182.0, true),
    _Expect('Tata Low Sodium Lite Salt', 1.0, Unit.packet, false, 54.0, false),
    _Expect("Baker's Loaf High Protein Bread", 1.0, Unit.packet, false, 1.0, false),
    _Expect('Green Capsicum (Shimla Mirch)', 1.0, Unit.packet, false, 17.0, false),
    _Expect('Everest Chicken Masala Powder', 1.0, Unit.packet, false, 99.0, false),
    _Expect('Tata Salt Pink Salt, for Everyday Cooking', 1.0, Unit.packet, false, 78.0, true),
    _Expect('Ginger (Allam)', 1.0, Unit.packet, false, 56.0, false),
  ],
  'flipkart': <_Expect>[
    _Expect('Harpic Power Plus Jas', 500.0, Unit.ml, true, 86.0, true),
    _Expect('Tata Salt Lite Namak,', 1.0, Unit.kg, true, 38.0, true),
    _Expect('Tata Sampann Toor/A', 500.0, Unit.g, true, 77.0, true),
    _Expect('Tata Sampann White', 500.0, Unit.g, true, 76.0, true),
    _Expect("MOTHER'S RECIPE Ta", 200.0, Unit.g, true, 41.0, true),
    _Expect('Dettol Liquid Hand wa', 1.35, Unit.l, true, 148.0, true),
    _Expect('Onion', 400.0, Unit.g, true, 1.0, false),
  ],
};

final Map<String, OcrPage Function()> _pages = <String, OcrPage Function()>{
  'blinkit': blinkitPage,
  'zepto': zeptoPage,
  'amazon': amazonPage,
  'swiggy': swiggyPage,
  'flipkart': flipkartPage,
};

void main() {
  const OrderRowParser parser = OrderRowParser();

  for (final MapEntry<String, List<_Expect>> shop in _expected.entries) {
    test('reads every product of the ${shop.key} screenshot', () {
      final OrderRowsResult result = parser.parse(_pages[shop.key]!());
      expect(result.rows.length, shop.value.length);
      for (int i = 0; i < shop.value.length; i++) {
        final OrderRow row = result.rows[i];
        final _Expect want = shop.value[i];
        expect(row.rawName, want.name, reason: 'name of line $i');
        expect(row.quantity, closeTo(want.quantity, 0.0001), reason: want.name);
        expect(row.unit, want.unit, reason: want.name);
        expect(row.sizeKnown, want.sized, reason: want.name);
        if (want.price == null) {
          expect(row.price, isNull, reason: want.name);
        } else {
          expect(row.price, closeTo(want.price!, 0.0001), reason: want.name);
        }
        expect(row.truncated, want.truncated, reason: want.name);
      }
    });
  }

  test('multiplies pack size by the number of packs', () {
    final OrderRow chilli = parser.parse(amazonPage()).rows[3];
    expect(chilli.rawName, 'Fresh Green Chilli');
    expect(chilli.quantity, 200);
    expect(chilli.unit, Unit.g);
  });

  test('shows 1000 ml as 1 L', () {
    final OrderRow milk = parser.parse(zeptoPage()).rows[3];
    expect(milk.quantity, 1);
    expect(milk.unit, Unit.l);
  });

  test('takes the lower of two prices and ignores the coin count', () {
    final List<OrderRow> flipkart = parser.parse(flipkartPage()).rows;
    expect(flipkart[0].price, 86);
    final List<OrderRow> blinkit = parser.parse(blinkitPage()).rows;
    expect(blinkit[0].price, 98);
  });

  test('a picture with no order text gives no rows', () {
    const OcrPage empty = OcrPage(width: 900, height: 1900, lines: <OcrLine>[]);
    final OrderRowsResult result = parser.parse(empty);
    expect(result.rows, isEmpty);
    expect(result.textLines, 0);
  });

  group('OrderStore.guess', () {
    List<String> texts(OcrPage p) => <String>[for (final OcrLine l in p.lines) l.text];

    test('knows each shop by its headings', () {
      expect(OrderStore.guess(texts(blinkitPage())), OrderStore.blinkit);
      expect(OrderStore.guess(texts(zeptoPage())), OrderStore.zepto);
      expect(OrderStore.guess(texts(amazonPage())), OrderStore.amazonNow);
      expect(OrderStore.guess(texts(swiggyPage())), OrderStore.instamart);
      expect(OrderStore.guess(texts(flipkartPage())), OrderStore.flipkartMinutes);
    });

    test('returns null when nothing matches', () {
      expect(OrderStore.guess(const <String>['hello', 'world']), isNull);
    });
  });
}
