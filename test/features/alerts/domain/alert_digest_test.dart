import 'package:akshaya/features/alerts/domain/alert_digest.dart';
import 'package:akshaya/features/alerts/domain/alert_settings.dart';
import 'package:akshaya/features/pantry/domain/entities.dart';
import 'package:akshaya/features/shopping/domain/shopping_entities.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../pantry/domain/test_data.dart';
import '../../shopping/domain/shopping_test_data.dart';

/// 2026-11-04 is [kToday].
ItemWithBatches stocked(
  String id,
  String name, {
  DateTime? expiry,
  double? threshold,
  double bought = 5,
  double? remaining,
  DateTime? opened,
  int? within,
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
        opened: opened,
        within: within,
      ),
    ],
  );
}

void main() {
  final List<ItemWithBatches> pantry = <ItemWithBatches>[
    stocked('m', 'Milk', expiry: DateTime(2026, 11, 2)),
    stocked('c', 'Curd', expiry: DateTime(2026, 11, 4)),
    stocked('s', 'Spinach', expiry: DateTime(2026, 11, 6)),
    stocked('p', 'Paneer', expiry: DateTime(2026, 11, 7)),
    stocked('h', 'Honey', expiry: DateTime(2026, 11, 8)),
    stocked('o', 'Onion', threshold: 2, bought: 1),
    stocked('r', 'Rice', threshold: 1),
    stocked('a', 'Atta', threshold: 1, bought: 1, remaining: 0),
  ];

  AlertDigest build({
    List<ItemWithBatches>? items,
    List<ShoppingEntry> entries = const <ShoppingEntry>[],
    AlertSettings settings = const AlertSettings(),
    DateTime? today,
  }) {
    return AlertDigestBuilder.build(
      items: items ?? pantry,
      entries: entries,
      today: today ?? kToday,
      settings: settings,
    );
  }

  test('sorts items into expired, today, soon and low stock', () {
    final AlertDigest digest = build();
    expect(digest.expired.map((s) => s.item.name), <String>['Milk']);
    expect(digest.expiringToday.map((s) => s.item.name), <String>['Curd']);
    // Soonest first; Honey is 4 days away, outside the 3-day window.
    expect(
      digest.expiringSoon.map((s) => s.item.name),
      <String>['Spinach', 'Paneer'],
    );
    // Out of stock comes before low stock.
    expect(
      digest.lowStock.map((s) => s.item.name),
      <String>['Atta', 'Onion'],
    );
    expect(digest.isEmpty, isFalse);
  });

  test('a wider window brings later dates in; a narrower one pushes them out',
      () {
    final AlertDigest wide = build(
      settings: const AlertSettings(warningDays: 4),
    );
    expect(
      wide.expiringSoon.map((s) => s.item.name),
      <String>['Spinach', 'Paneer', 'Honey'],
    );

    final AlertDigest narrow = build(
      settings: const AlertSettings(warningDays: 1),
    );
    expect(narrow.expiringToday.map((s) => s.item.name), <String>['Curd']);
    expect(narrow.expiringSoon, isEmpty);
  });

  test('judges every date against the day asked about', () {
    // The day after: Curd has expired, Spinach is one day away.
    final AlertDigest tomorrow = build(today: DateTime(2026, 11, 5));
    expect(
      tomorrow.expired.map((s) => s.item.name),
      <String>['Milk', 'Curd'],
    );
    expect(
      tomorrow.expiringSoon.map((s) => s.item.name),
      <String>['Spinach', 'Paneer', 'Honey'],
    );
  });

  test('leaves out low stock that is already on a shopping list', () {
    final AlertDigest digest = build(
      entries: <ShoppingEntry>[makeEntry(itemId: 'o', name: 'Onion')],
    );
    expect(digest.lowStock.map((s) => s.item.name), <String>['Atta']);
  });

  test('leaves low stock out when it is switched off', () {
    final AlertDigest digest = build(
      settings: const AlertSettings(lowStock: false),
    );
    expect(digest.lowStock, isEmpty);
    expect(digest.expired, isNotEmpty);
  });

  test('stock that is all past its date is expired, not low stock', () {
    final AlertDigest digest = build(
      items: <ItemWithBatches>[
        stocked('m', 'Milk', expiry: DateTime(2026, 11, 2), threshold: 1),
      ],
    );
    expect(digest.expired.map((s) => s.item.name), <String>['Milk']);
    expect(digest.lowStock, isEmpty);
  });

  test('uses the opened-item rule for the date', () {
    // Opened 1 Nov, good for 2 days: gone from 3 Nov.
    final AlertDigest digest = build(
      items: <ItemWithBatches>[
        stocked(
          'j',
          'Jam',
          expiry: DateTime(2027, 5, 1),
          opened: DateTime(2026, 11, 1),
          within: 2,
        ),
      ],
    );
    expect(digest.expired.map((s) => s.item.name), <String>['Jam']);
  });

  test('items with no date and plenty in stock say nothing', () {
    final AlertDigest digest = build(
      items: <ItemWithBatches>[stocked('r', 'Rice', threshold: 1)],
    );
    expect(digest.isEmpty, isTrue);
  });

  test('an empty pantry says nothing', () {
    expect(build(items: const <ItemWithBatches>[]).isEmpty, isTrue);
  });
}
