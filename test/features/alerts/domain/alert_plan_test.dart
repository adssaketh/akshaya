import 'package:akshaya/features/alerts/domain/alert_digest.dart';
import 'package:akshaya/features/alerts/domain/alert_plan.dart';
import 'package:akshaya/features/alerts/domain/alert_settings.dart';
import 'package:akshaya/features/pantry/domain/entities.dart';
import 'package:akshaya/features/pantry/domain/unit.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../pantry/domain/test_data.dart';

ItemWithBatches stocked(
  String id,
  String name, {
  DateTime? expiry,
  double? threshold,
  double bought = 5,
  double? remaining,
}) {
  return ItemWithBatches(
    item: makeItem(id: id, name: name, threshold: threshold),
    batches: <StockBatch>[
      makeBatch(
        id: 'b-$id',
        itemId: id,
        bought: bought,
        remaining: remaining,
        expiry: expiry,
      ),
    ],
  );
}

AlertDigest digestOf(
  List<ItemWithBatches> items, {
  AlertSettings settings = const AlertSettings(),
}) {
  return AlertDigestBuilder.build(
    items: items,
    entries: const [],
    today: kToday,
    settings: settings,
  );
}

void main() {
  group('AlertPlanner', () {
    test('says nothing when there is nothing to say', () {
      expect(AlertPlanner.plan(digestOf(const <ItemWithBatches>[])), isEmpty);
    });

    test('expired: one item, yesterday', () {
      final List<AlertNotification> plan = AlertPlanner.plan(
        digestOf(<ItemWithBatches>[
          stocked('m', 'Milk', expiry: DateTime(2026, 11, 3)),
        ]),
      );
      expect(plan, hasLength(1));
      expect(plan.single.title, '1 item has expired');
      expect(plan.single.body, 'Milk (yesterday)');
      expect(plan.single.target, AlertTarget.pantryExpired);
      expect(plan.single.channel, AlertChannelKind.expiry);
    });

    test('expired: several, most overdue first', () {
      final List<AlertNotification> plan = AlertPlanner.plan(
        digestOf(<ItemWithBatches>[
          stocked('c', 'Curd', expiry: DateTime(2026, 11, 3)),
          stocked('m', 'Milk', expiry: DateTime(2026, 10, 31)),
        ]),
      );
      expect(plan.single.title, '2 items have expired');
      expect(plan.single.body, 'Milk (4d ago), Curd (yesterday)');
    });

    test('expiring: today and soon together', () {
      final List<AlertNotification> plan = AlertPlanner.plan(
        digestOf(<ItemWithBatches>[
          stocked('c', 'Curd', expiry: DateTime(2026, 11, 4)),
          stocked('s', 'Spinach', expiry: DateTime(2026, 11, 6)),
          stocked('p', 'Paneer', expiry: DateTime(2026, 11, 7)),
        ]),
      );
      expect(plan, hasLength(1));
      expect(plan.single.title, '1 expiring today, 2 more soon');
      expect(
        plan.single.body,
        'Today: Curd\nNext 3 days: Spinach (in 2d), Paneer (in 3d)',
      );
      expect(plan.single.target, AlertTarget.pantryExpiring);
      expect(plan.single.channel, AlertChannelKind.expiry);
    });

    test('expiring: only today, singular and plural', () {
      final AlertNotification one = AlertPlanner.plan(
        digestOf(<ItemWithBatches>[
          stocked('c', 'Curd', expiry: DateTime(2026, 11, 4)),
        ]),
      ).single;
      expect(one.title, '1 item expires today');
      expect(one.body, 'Today: Curd');

      final AlertNotification two = AlertPlanner.plan(
        digestOf(<ItemWithBatches>[
          stocked('c', 'Curd', expiry: DateTime(2026, 11, 4)),
          stocked('b', 'Bread', expiry: DateTime(2026, 11, 4)),
        ]),
      ).single;
      expect(two.title, '2 items expire today');
      expect(two.body, 'Today: Bread, Curd');
    });

    test('expiring: only soon', () {
      final AlertNotification one = AlertPlanner.plan(
        digestOf(<ItemWithBatches>[
          stocked('s', 'Spinach', expiry: DateTime(2026, 11, 6)),
        ]),
      ).single;
      expect(one.title, '1 item expiring soon');
      expect(one.body, 'Next 3 days: Spinach (in 2d)');
    });

    test('expiring: a one-day window reads "Tomorrow"', () {
      final AlertNotification note = AlertPlanner.plan(
        digestOf(
          <ItemWithBatches>[
            stocked('e', 'Eggs', expiry: DateTime(2026, 11, 5)),
          ],
          settings: const AlertSettings(warningDays: 1),
        ),
      ).single;
      expect(note.title, '1 item expiring soon');
      expect(note.body, 'Tomorrow: Eggs');
    });

    test('low stock lists what is left, and what has run out', () {
      final AlertNotification note = AlertPlanner.plan(
        digestOf(<ItemWithBatches>[
          stocked('o', 'Onion', threshold: 2, bought: 1),
          stocked('a', 'Atta', threshold: 1, bought: 1, remaining: 0),
        ]),
      ).single;
      expect(note.title, '2 items are running low');
      expect(note.body, 'Atta (none left), Onion (${Unit.kg.format(1)} left)');
      expect(note.target, AlertTarget.shoppingSuggestions);
      expect(note.channel, AlertChannelKind.stock);
    });

    test('one low-stock item reads in the singular', () {
      final AlertNotification note = AlertPlanner.plan(
        digestOf(<ItemWithBatches>[
          stocked('o', 'Onion', threshold: 2, bought: 1),
        ]),
      ).single;
      expect(note.title, '1 item is running low');
    });

    test('long lists stop after four names', () {
      final List<ItemWithBatches> items = <ItemWithBatches>[
        for (int i = 1; i <= 6; i++)
          stocked('i$i', 'Item $i', expiry: DateTime(2026, 11, 3)),
      ];
      final AlertNotification note =
          AlertPlanner.plan(digestOf(items)).single;
      expect(note.title, '6 items have expired');
      expect(
        note.body,
        'Item 1 (yesterday), Item 2 (yesterday), Item 3 (yesterday), '
        'Item 4 (yesterday), +2 more',
      );
    });

    test('gives all three, in order, with ids for the day', () {
      final List<ItemWithBatches> items = <ItemWithBatches>[
        stocked('m', 'Milk', expiry: DateTime(2026, 11, 3)),
        stocked('c', 'Curd', expiry: DateTime(2026, 11, 4)),
        stocked('o', 'Onion', threshold: 2, bought: 1),
      ];
      final List<AlertNotification> today = AlertPlanner.plan(digestOf(items));
      expect(today.map((n) => n.target), <AlertTarget>[
        AlertTarget.pantryExpired,
        AlertTarget.pantryExpiring,
        AlertTarget.shoppingSuggestions,
      ]);
      expect(today.map((n) => n.id), <int>[4101, 4102, 4103]);

      final List<AlertNotification> next =
          AlertPlanner.plan(digestOf(items), dayOffset: 1);
      expect(next.map((n) => n.id), <int>[4111, 4112, 4113]);

      final List<AlertNotification> preview = AlertPlanner.plan(
        digestOf(items),
        dayOffset: AlertPlanner.previewDayOffset,
      );
      expect(preview.map((n) => n.id), <int>[4191, 4192, 4193]);
    });
  });

  group('AlertTarget', () {
    test('payloads round-trip', () {
      for (final AlertTarget target in AlertTarget.values) {
        expect(AlertTarget.fromPayload(target.payload), target);
      }
    });

    test('unknown or missing payloads are no target', () {
      expect(AlertTarget.fromPayload(null), isNull);
      expect(AlertTarget.fromPayload(''), isNull);
      expect(AlertTarget.fromPayload('pantry:everything'), isNull);
    });
  });
}
