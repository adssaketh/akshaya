import 'package:akshaya/features/pantry/domain/entities.dart';
import 'package:akshaya/features/shopping/domain/shopping_entities.dart';
import 'package:akshaya/features/shopping/domain/shopping_enums.dart';
import 'package:akshaya/features/shopping/domain/shopping_share.dart';
import 'package:akshaya/features/shopping/domain/shopping_view.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../pantry/domain/test_data.dart';
import 'shopping_test_data.dart';

ShoppingListView build(List<ShoppingEntry> entries, {List<Item>? items}) {
  return ShoppingListBuilder.build(
    entries: entries,
    itemsById: <String, Item>{
      for (final Item i in items ?? <Item>[]) i.id: i,
    },
    categories: testCategories,
    today: kToday,
  );
}

List<String> names(Iterable<ShoppingEntry> entries) =>
    entries.map((ShoppingEntry e) => e.name).toList();

void main() {
  final Item rice = makeItem();
  final Item milk = makeItem(id: 'i2', name: 'Milk', categoryId: 'cat_dairy');
  final Item onion = makeItem(
    id: 'i3',
    name: 'Onion',
    categoryId: 'cat_vegetables',
  );

  group('Recurrence', () {
    test('next due date', () {
      final DateTime day = DateTime(2026, 1, 31, 18, 30);

      expect(Recurrence.none.nextDue(day), DateTime(2026, 1, 31));
      expect(Recurrence.daily.nextDue(day), DateTime(2026, 2, 1));
      expect(Recurrence.weekly.nextDue(day), DateTime(2026, 2, 7));
      // 31 Jan + 1 month clamps to the end of February.
      expect(Recurrence.monthly.nextDue(day), DateTime(2026, 2, 28));
    });

    test('only the repeating kinds repeat', () {
      expect(Recurrence.none.repeats, isFalse);
      expect(
        Recurrence.values.where((Recurrence r) => r.repeats),
        <Recurrence>[Recurrence.daily, Recurrence.weekly, Recurrence.monthly],
      );
    });
  });

  group('ShoppingEntry', () {
    test('is due when it has no date, or the date is today or earlier', () {
      expect(makeEntry().isDueOn(kToday), isTrue);
      expect(makeEntry(dueOn: DateTime(2026, 11, 3)).isDueOn(kToday), isTrue);
      expect(makeEntry(dueOn: kToday).isDueOn(kToday), isTrue);
      expect(makeEntry(dueOn: DateTime(2026, 11, 5)).isDueOn(kToday), isFalse);
    });

    test('quantity label uses the unit', () {
      expect(makeEntry(quantity: 2).quantityLabel, '2 kg');
      expect(makeEntry(quantity: 1).quantityLabel, '1 kg');
    });

    test('copyWith keeps what is not changed and can clear fields', () {
      final ShoppingEntry entry = makeEntry(
        itemId: 'i1',
        notes: 'red',
        recurrence: Recurrence.weekly,
        dueOn: DateTime(2026, 11, 10),
      );

      final ShoppingEntry same = entry.copyWith(quantity: 3);
      expect(same.quantity, 3);
      expect(same.itemId, 'i1');
      expect(same.notes, 'red');
      expect(same.dueOn, DateTime(2026, 11, 10));

      final ShoppingEntry cleared = entry.copyWith(
        clearItemId: true,
        clearNotes: true,
        clearDueOn: true,
      );
      expect(cleared.itemId, isNull);
      expect(cleared.notes, isNull);
      expect(cleared.dueOn, isNull);
    });
  });

  group('ShoppingListBuilder', () {
    test('groups unchecked entries by category in category order', () {
      final ShoppingListView view = build(
        <ShoppingEntry>[
          makeEntry(id: '1', name: 'Milk', itemId: 'i2'),
          makeEntry(id: '2', name: 'Rice', itemId: 'i1'),
          makeEntry(id: '3', name: 'Onion', itemId: 'i3'),
        ],
        items: <Item>[rice, milk, onion],
      );

      expect(
        view.sections.map((ShoppingSection s) => s.title).toList(),
        <String>['Vegetables', 'Dairy', 'Grains & Rice'],
      );
      expect(view.toBuyCount, 3);
    });

    test('free text and entries of deleted items go under Other', () {
      final ShoppingListView view = build(
        <ShoppingEntry>[
          makeEntry(id: '1', name: 'Candles'),
          makeEntry(id: '2', name: 'Ghost', itemId: 'gone'),
          makeEntry(id: '3', name: 'Rice', itemId: 'i1'),
        ],
        items: <Item>[rice],
      );

      expect(
        view.sections.map((ShoppingSection s) => s.title).toList(),
        <String>['Grains & Rice', 'Other'],
      );
      expect(names(view.sections.last.entries), <String>['Candles', 'Ghost']);
    });

    test('urgent entries come first, then by name', () {
      final ShoppingListView view = build(
        <ShoppingEntry>[
          makeEntry(id: '1', name: 'Candles'),
          makeEntry(id: '2', name: 'Batteries'),
          makeEntry(id: '3', name: 'Matches', priority: ShoppingPriority.high),
        ],
      );

      expect(
        names(view.sections.single.entries),
        <String>['Matches', 'Batteries', 'Candles'],
      );
    });

    test('checked entries go to the basket', () {
      final ShoppingListView view = build(
        <ShoppingEntry>[
          makeEntry(id: '1', name: 'Rice', itemId: 'i1', checked: true),
          makeEntry(id: '2', name: 'Milk', itemId: 'i2'),
        ],
        items: <Item>[rice, milk],
      );

      expect(names(view.basket), <String>['Rice']);
      expect(names(view.sections.single.entries), <String>['Milk']);
      expect(view.toBuyCount, 1);
    });

    test('repeating entries not due yet wait under upcoming', () {
      final ShoppingListView view = build(
        <ShoppingEntry>[
          makeEntry(
            id: '1',
            name: 'Milk',
            recurrence: Recurrence.daily,
            dueOn: DateTime(2026, 11, 5),
          ),
          makeEntry(
            id: '2',
            name: 'Bread',
            recurrence: Recurrence.weekly,
            dueOn: DateTime(2026, 11, 4),
          ),
          makeEntry(
            id: '3',
            name: 'Eggs',
            recurrence: Recurrence.weekly,
            dueOn: DateTime(2026, 11, 11),
          ),
        ],
      );

      // Bread is due today, so it is on the list now.
      expect(names(view.sections.single.entries), <String>['Bread']);
      expect(names(view.upcoming), <String>['Milk', 'Eggs']);
      expect(view.isEmpty, isFalse);
    });

    test('an empty list is empty', () {
      final ShoppingListView view = build(const <ShoppingEntry>[]);

      expect(view.isEmpty, isTrue);
      expect(view.toBuyCount, 0);
    });

    test('toBuyCount counts unchecked entries that are due', () {
      final int count = ShoppingListBuilder.toBuyCount(
        <ShoppingEntry>[
          makeEntry(id: '1'),
          makeEntry(id: '2', checked: true),
          makeEntry(id: '3', dueOn: DateTime(2026, 11, 9)),
        ],
        kToday,
      );

      expect(count, 1);
    });
  });

  group('ShoppingShare', () {
    test('formats what is left to buy by category', () {
      final ShoppingListView view = build(
        <ShoppingEntry>[
          makeEntry(
            id: '1',
            name: 'Onion',
            itemId: 'i3',
            quantity: 1,
            priority: ShoppingPriority.high,
            notes: 'red ones',
          ),
          makeEntry(id: '2', name: 'Milk', itemId: 'i2', quantity: 2),
          makeEntry(id: '3', name: 'Rice', itemId: 'i1', checked: true),
        ],
        items: <Item>[rice, milk, onion],
      );

      expect(
        ShoppingShare.build(listName: 'Weekly', view: view),
        '*Weekly*\n'
        '\n'
        '*Vegetables*\n'
        '• Onion — 1 kg (urgent) · red ones\n'
        '\n'
        '*Dairy*\n'
        '• Milk — 2 kg',
      );
    });

    test('is empty when there is nothing left to buy', () {
      final ShoppingListView view = build(
        <ShoppingEntry>[makeEntry(checked: true)],
      );

      expect(ShoppingShare.build(listName: 'Weekly', view: view), '');
    });
  });
}
