import 'package:akshaya/features/pantry/domain/unit.dart';
import 'package:akshaya/features/pantry/domain/stock_logic.dart';
import 'package:akshaya/features/pantry/domain/entities.dart';
import 'package:akshaya/features/rescue/domain/food_rescue.dart';
import 'package:akshaya/features/rescue/domain/freeze_rules.dart';
import 'package:akshaya/features/shopping/domain/shopping_entities.dart';
import 'package:akshaya/features/shopping/domain/shopping_enums.dart';
import 'package:akshaya/features/widgets/domain/widget_gateway.dart';
import 'package:akshaya/features/widgets/domain/widget_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../pantry/domain/test_data.dart';
import '../../shopping/domain/shopping_test_data.dart';

List<RescueEntry> rescueFor(int count) {
  final List<ItemStock> stocks = <ItemStock>[
    for (int i = 0; i < count; i++)
      StockLogic.summarize(
        ItemWithBatches(
          item: makeItem(id: 'i$i', name: 'Item $i'),
          batches: <StockBatch>[
            makeBatch(
              id: 'b$i',
              itemId: 'i$i',
              expiry: DateTime(2026, 11, 4).add(Duration(days: i)),
            ),
          ],
        ),
        today: kToday,
        warningDays: 10,
      ),
  ];
  return FoodRescue.build(
    stocks: stocks,
    today: kToday,
    warningDays: 10,
    freeze: const FreezeSettings(),
  );
}

void main() {
  group('WidgetSnapshots', () {
    test('Use these first lists the most urgent rows and counts the rest', () {
      final WidgetSnapshot s = WidgetSnapshots.build(
        rescue: rescueFor(7),
        entries: const <ShoppingEntry>[],
        today: kToday,
      );
      expect(s.useFirst.length, WidgetSnapshots.useFirstRows);
      expect(s.useFirst.first, 'Item 0 · Today');
      expect(s.useFirstMore, 2);
    });

    test('shopping rows: to buy first, ticked last, held-back items left out', () {
      final WidgetSnapshot s = WidgetSnapshots.build(
        rescue: const <RescueEntry>[],
        entries: <ShoppingEntry>[
          makeEntry(id: 'a', name: 'Rice', checked: true),
          makeEntry(id: 'b', name: 'Milk', quantity: 2, unit: Unit.l),
          makeEntry(
            id: 'c',
            name: 'Curd',
            recurrence: Recurrence.weekly,
            dueOn: DateTime(2026, 11, 20),
          ),
          makeEntry(id: 'd', name: 'Other list', listId: 'other'),
        ],
        today: kToday,
      );
      expect(s.shopping.map((WidgetShopRow r) => r.id).toList(), <String>['b', 'a']);
      expect(s.shopping.first.text, 'Milk, 2 L');
      expect(s.shopping.last.checked, isTrue);
      expect(s.shoppingMore, 0);
    });

    test('a trip holds repeating items back', () {
      final ShoppingEntry weekly = makeEntry(
        id: 'w',
        name: 'Curd',
        recurrence: Recurrence.weekly,
        dueOn: DateTime(2026, 11, 5),
      );
      expect(
        WidgetSnapshots.build(
          rescue: const <RescueEntry>[],
          entries: <ShoppingEntry>[weekly],
          today: DateTime(2026, 11, 6),
        ).shopping,
        hasLength(1),
      );
      expect(
        WidgetSnapshots.build(
          rescue: const <RescueEntry>[],
          entries: <ShoppingEntry>[weekly],
          today: DateTime(2026, 11, 6),
          pausedUntil: DateTime(2026, 11, 10),
        ).shopping,
        isEmpty,
      );
    });

    test('prefs pad unused rows and equal snapshots compare equal', () {
      final WidgetSnapshot a = WidgetSnapshots.build(
        rescue: rescueFor(1),
        entries: <ShoppingEntry>[makeEntry(id: 'a', name: 'Rice')],
        today: kToday,
      );
      final WidgetSnapshot b = WidgetSnapshots.build(
        rescue: rescueFor(1),
        entries: <ShoppingEntry>[makeEntry(id: 'a', name: 'Rice')],
        today: kToday,
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      final Map<String, Object> prefs = a.toPrefs();
      expect(prefs['use_first_count'], 1);
      expect(prefs['use_first_4'], '');
      expect(prefs['shop_id_5'], '');
      expect(prefs['shop_text_0'], 'Rice, 1 kg');
      expect(a == WidgetSnapshot.empty, isFalse);
    });
  });

  group('QuickLaunch', () {
    test('reads widget addresses and shortcut types', () {
      expect(QuickLaunch.fromUri(Uri.parse('akshaya://voice')), QuickLaunch.voice);
      expect(QuickLaunch.fromUri(Uri.parse('akshaya://use_first')),
          QuickLaunch.useFirst);
      expect(QuickLaunch.fromUri(Uri.parse('https://voice')), isNull);
      expect(QuickLaunch.fromUri(Uri.parse('akshaya://nope')), isNull);
      expect(QuickLaunch.fromUri(null), isNull);
      expect(QuickLaunch.fromKey('shopping'), QuickLaunch.shopping);
    });
  });
}
