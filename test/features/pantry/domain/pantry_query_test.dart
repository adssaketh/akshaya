import 'package:akshaya/core/design/design.dart' show StatusKind;
import 'package:akshaya/features/pantry/domain/default_categories.dart';
import 'package:akshaya/features/pantry/domain/entities.dart';
import 'package:akshaya/features/pantry/domain/pantry_query.dart';
import 'package:akshaya/features/pantry/domain/stock_logic.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_data.dart';

ItemStock stock(Item item, List<StockBatch> batches) => StockLogic.summarize(
      ItemWithBatches(item: item, batches: batches),
      today: kToday,
      warningDays: 3,
    );

void main() {
  final ItemStock rice = stock(
    makeItem(
      id: 'rice',
      name: 'Basmati Rice',
      aliases: <String>['బియ్యం', 'biyyam', 'चावल', 'chawal'],
    ),
    <StockBatch>[makeBatch(id: 'r', itemId: 'rice', bought: 5)],
  );
  final ItemStock milk = stock(
    makeItem(id: 'milk', name: 'Milk', brand: 'Heritage', categoryId: 'cat_dairy'),
    <StockBatch>[
      makeBatch(id: 'm', itemId: 'milk', expiry: DateTime(2026, 11, 5)),
    ],
  );

  test('search matches name, brand and aliases in all scripts', () {
    bool hit(String q) => PantryQuery(text: q).matches(rice);
    expect(hit('basmati'), isTrue);
    expect(hit('BIYYAM'), isTrue);
    expect(hit('బియ్యం'), isTrue);
    expect(hit('चावल'), isTrue);
    expect(hit('chawal'), isTrue);
    expect(hit('dal'), isFalse);
    expect(const PantryQuery(text: 'heritage').matches(milk), isTrue);
  });

  test('every word must match', () {
    expect(const PantryQuery(text: 'basmati rice').matches(rice), isTrue);
    expect(const PantryQuery(text: 'basmati milk').matches(rice), isFalse);
  });

  test('status filter', () {
    const PantryQuery q = PantryQuery(statusFilter: StatusKind.expiring);
    expect(q.matches(milk), isTrue);
    expect(q.matches(rice), isFalse);
  });

  test('builds category sections in category order, skipping empty ones', () {
    final List<Category> cats = <Category>[
      for (int i = 0; i < kDefaultCategories.length; i++)
        Category(
          id: kDefaultCategories[i].id,
          name: kDefaultCategories[i].name,
          iconKey: kDefaultCategories[i].iconKey,
          sortOrder: i,
        ),
    ];
    final List<PantrySection> sections = PantryListBuilder.build(
      <ItemStock>[rice, milk],
      const PantryQuery(),
      cats,
    );
    expect(
      sections.map((PantrySection s) => s.title).toList(),
      <String>['Dairy', 'Grains & Rice'],
    );
  });

  test('groups by location', () {
    final List<PantrySection> sections = PantryListBuilder.build(
      <ItemStock>[rice, milk],
      const PantryQuery(group: PantryGroup.location),
      const <Category>[],
    );
    expect(sections.single.title, 'Pantry');
    expect(sections.single.items.length, 2);
  });

  test('sort by name and by expiry', () {
    List<String> names(PantrySort sort) {
      final List<PantrySection> sections = PantryListBuilder.build(
        <ItemStock>[rice, milk],
        PantryQuery(sort: sort, group: PantryGroup.location),
        const <Category>[],
      );
      return <String>[
        for (final PantrySection s in sections)
          for (final ItemStock i in s.items) i.item.name,
      ];
    }

    expect(names(PantrySort.name), <String>['Basmati Rice', 'Milk']);
    // Milk has an expiry, rice has none: dated items come first.
    expect(names(PantrySort.expiry), <String>['Milk', 'Basmati Rice']);
    expect(names(PantrySort.quantity), <String>['Milk', 'Basmati Rice']);
  });
}
