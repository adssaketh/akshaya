import 'package:akshaya/features/pantry/domain/storage_location.dart';
import 'package:akshaya/features/pantry/domain/unit.dart';
import 'package:akshaya/features/pantry/presentation/widgets/stock_fields.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  StockFieldsController controller() {
    final StockFieldsController c = StockFieldsController(
      today: DateTime(2026, 11, 4),
      unit: Unit.kg,
      location: StorageLocation.pantry,
    );
    addTearDown(c.dispose);
    return c;
  }

  test('a price with a thousands comma is read in full', () {
    final StockFieldsController c = controller()..price.text = '1,250';
    expect(c.priceValue, 1250);
  });

  test('a rupee sign and Indian grouping are accepted', () {
    final StockFieldsController c = controller()..price.text = '₹1,25,000';
    expect(c.priceValue, 125000);
  });

  test('an empty price is no price', () {
    expect(controller().priceValue, isNull);
  });

  test('the draft carries the parsed price', () {
    final StockFieldsController c = controller()
      ..quantity.text = '2'
      ..price.text = '1,250.50';
    expect(c.toDraft('i1').price, 1250.5);
  });
}
