import 'package:akshaya/features/home/presentation/home_screen.dart';
import 'package:akshaya/features/pantry/domain/entities.dart';
import 'package:akshaya/features/pantry/domain/item_kind.dart';
import 'package:akshaya/features/pantry/domain/pantry_query.dart';
import 'package:akshaya/features/pantry/domain/stock_logic.dart';
import 'package:akshaya/features/pantry/domain/storage_location.dart';
import 'package:akshaya/features/pantry/domain/unit.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_data.dart';

ItemStock stock(Item item, List<StockBatch> batches) => StockLogic.summarize(
      ItemWithBatches(item: item, batches: batches),
      today: kToday,
      warningDays: 3,
    );

void main() {
  test('stocked item line is unchanged', () {
    final ItemStock s = stock(makeItem(), <StockBatch>[makeBatch(bought: 2)]);
    expect(s.summaryLine, 'Pantry · 2 kg left');
  });

  test('cooked item shows kind, place, amount and container', () {
    final ItemStock s = stock(
      makeItem(name: 'Sambar', unit: Unit.portion, kind: ItemKind.cooked),
      <StockBatch>[
        makeBatch(
          bought: 3,
          unit: Unit.portion,
          location: StorageLocation.fridge,
          expiry: DateTime(2026, 11, 6),
          container: 'steel dabba',
        ),
      ],
    );
    expect(s.summaryLine, 'Cooked · Fridge · 3 portions left · steel dabba');
  });

  test('container comes from the batch used first', () {
    final ItemStock s = stock(
      makeItem(unit: Unit.portion, kind: ItemKind.cooked),
      <StockBatch>[
        makeBatch(
          id: 'late',
          bought: 1,
          unit: Unit.portion,
          expiry: DateTime(2026, 11, 9),
          container: 'blue box',
        ),
        makeBatch(
          id: 'soon',
          bought: 1,
          unit: Unit.portion,
          expiry: DateTime(2026, 11, 5),
          container: 'steel dabba',
        ),
      ],
    );
    expect(s.containerLabel, 'steel dabba');
  });

  test('kind filter', () {
    final ItemStock cooked = stock(
      makeItem(id: 'c', kind: ItemKind.cooked, unit: Unit.portion),
      <StockBatch>[makeBatch(itemId: 'c', unit: Unit.portion)],
    );
    final ItemStock plain = stock(makeItem(), <StockBatch>[makeBatch()]);
    const PantryQuery q = PantryQuery(kindFilter: ItemKind.cooked);
    expect(q.matches(cooked), isTrue);
    expect(q.matches(plain), isFalse);
    expect(q.hasActiveFilters, isTrue);
    expect(q.copyWith(clearKindFilter: true).matches(plain), isTrue);
  });

  test('portion units format and never convert to weight', () {
    expect(Unit.portion.format(1), '1 portion');
    expect(Unit.portion.format(2), '2 portions');
    expect(Unit.portion.isCompatibleWith(Unit.kg), isFalse);
    expect(Unit.portion.compatibleUnits, <Unit>[Unit.portion]);
  });

  test('Use these first lists cooked leftovers even before they expire', () {
    final ItemStock leftover = stock(
      makeItem(id: 'c', name: 'Sambar', kind: ItemKind.cooked, unit: Unit.portion),
      <StockBatch>[
        makeBatch(
          itemId: 'c',
          unit: Unit.portion,
          expiry: DateTime(2026, 11, 20),
        ),
      ],
    );
    final ItemStock fresh = stock(
      makeItem(id: 'r'),
      <StockBatch>[makeBatch(itemId: 'r', expiry: DateTime(2026, 12, 20))],
    );
    final List<ItemStock> out = useTheseFirst(<ItemStock>[fresh, leftover]);
    expect(out.map((ItemStock s) => s.item.id), <String>['c']);
  });
}
