import 'package:akshaya/features/pantry/domain/entities.dart';
import 'package:akshaya/features/produce/domain/produce.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('default and icon-matched categories are recognised', () {
    expect(
      produceKindOfCategory(null, 'cat_vegetables'),
      ProduceKind.vegetable,
    );
    expect(produceKindOfCategory(null, 'cat_fruits'), ProduceKind.fruit);
    expect(produceKindOfCategory(null, 'cat_dairy'), isNull);
    const Category custom = Category(
      id: 'c1',
      name: 'Greens',
      iconKey: 'vegetables',
      sortOrder: 0,
    );
    expect(produceKindOfCategory(custom, 'c1'), ProduceKind.vegetable);
  });
}
