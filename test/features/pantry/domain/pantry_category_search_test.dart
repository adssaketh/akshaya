import 'package:akshaya/features/pantry/domain/entities.dart';
import 'package:akshaya/features/pantry/domain/pantry_query.dart';
import 'package:akshaya/features/pantry/domain/stock_logic.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_data.dart';

ItemStock _stock(Item item) => StockLogic.summarize(
      ItemWithBatches(
        item: item,
        batches: <StockBatch>[makeBatch(id: 'b-${item.id}', itemId: item.id)],
      ),
      today: kToday,
      warningDays: 3,
    );

void main() {
  const List<Category> categories = <Category>[
    Category(id: 'cat_dairy', name: 'Dairy', iconKey: 'dairy', sortOrder: 0),
    Category(id: 'cat_grains', name: 'Grains', iconKey: 'grains', sortOrder: 1),
  ];
  final ItemStock rice = _stock(makeItem(id: 'rice', name: 'Basmati Rice'));
  final ItemStock milk = _stock(
    makeItem(id: 'milk', name: 'Milk', categoryId: 'cat_dairy'),
  );

  test('search also matches the category name', () {
    const PantryQuery q = PantryQuery(text: 'dairy');
    expect(q.matches(milk, categoryName: 'Dairy'), isTrue);
    expect(q.matches(rice, categoryName: 'Grains'), isFalse);
    // Without a category name only name, brand and aliases count.
    expect(q.matches(milk), isFalse);
  });

  test('the list builder searches by category', () {
    final List<PantrySection> sections = PantryListBuilder.build(
      <ItemStock>[rice, milk],
      const PantryQuery(text: 'grains'),
      categories,
    );
    expect(sections.length, 1);
    expect(sections.single.items.single.item.name, 'Basmati Rice');
  });

  test('sort by type orders by category, then name', () {
    final List<PantrySection> sections = PantryListBuilder.build(
      <ItemStock>[rice, milk],
      const PantryQuery(sort: PantrySort.type, group: PantryGroup.location),
      categories,
    );
    final List<String> names = <String>[
      for (final PantrySection s in sections)
        for (final ItemStock i in s.items) i.item.name,
    ];
    // Dairy (order 0) comes before Grains (order 1).
    expect(names, <String>['Milk', 'Basmati Rice']);
  });
}
