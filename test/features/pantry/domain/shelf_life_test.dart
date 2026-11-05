import 'package:akshaya/features/pantry/domain/item_kind.dart';
import 'package:akshaya/features/pantry/domain/shelf_life.dart';
import 'package:akshaya/features/pantry/domain/storage_location.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ItemKind', () {
    test('fromName falls back to stocked', () {
      expect(ItemKind.fromName(null), ItemKind.stocked);
      expect(ItemKind.fromName('cooked'), ItemKind.cooked);
      expect(ItemKind.fromName('homemade'), ItemKind.homemade);
      expect(ItemKind.fromName('nonsense'), ItemKind.stocked);
    });

    test('made-at-home kinds', () {
      expect(ItemKind.stocked.isMadeAtHome, isFalse);
      expect(ItemKind.cooked.isMadeAtHome, isTrue);
      expect(ItemKind.homemade.isMadeAtHome, isTrue);
    });
  });

  group('ShelfLife defaults', () {
    test('cooked food', () {
      expect(ShelfLife.defaultDays(ItemKind.cooked, StorageLocation.fridge), 2);
      expect(ShelfLife.defaultDays(ItemKind.cooked, StorageLocation.freezer), 30);
      expect(ShelfLife.defaultDays(ItemKind.cooked, StorageLocation.pantry), 1);
    });

    test('homemade food keeps longer', () {
      expect(ShelfLife.defaultDays(ItemKind.homemade, StorageLocation.pantry), 90);
      expect(ShelfLife.defaultDays(ItemKind.homemade, StorageLocation.fridge), 30);
      expect(ShelfLife.defaultDays(ItemKind.homemade, StorageLocation.freezer), 180);
    });

    test('stocked items have none', () {
      expect(ShelfLife.defaultDays(ItemKind.stocked, StorageLocation.fridge), isNull);
      expect(
        ShelfLife.expiryFor(
          kind: ItemKind.stocked,
          location: StorageLocation.fridge,
          madeOn: DateTime(2026, 11, 4),
        ),
        isNull,
      );
    });
  });

  group('ShelfLife per-item override', () {
    test('applies only to the usual location', () {
      expect(
        ShelfLife.daysFor(
          kind: ItemKind.cooked,
          location: StorageLocation.fridge,
          own: 4,
          usualLocation: StorageLocation.fridge,
        ),
        4,
      );
      expect(
        ShelfLife.daysFor(
          kind: ItemKind.cooked,
          location: StorageLocation.freezer,
          own: 4,
          usualLocation: StorageLocation.fridge,
        ),
        30,
      );
    });

    test('zero or negative override is ignored', () {
      expect(
        ShelfLife.daysFor(
          kind: ItemKind.cooked,
          location: StorageLocation.fridge,
          own: 0,
          usualLocation: StorageLocation.fridge,
        ),
        2,
      );
    });
  });

  test('expiryFor adds days across a month boundary', () {
    expect(
      ShelfLife.expiryFor(
        kind: ItemKind.cooked,
        location: StorageLocation.freezer,
        madeOn: DateTime(2026, 11, 4),
      ),
      DateTime(2026, 12, 4),
    );
  });

  test('label', () {
    expect(ShelfLife.label(1), '1 day');
    expect(ShelfLife.label(3), '3 days');
  });
}
