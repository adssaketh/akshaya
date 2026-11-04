import 'package:akshaya/core/design/design.dart';
import 'package:akshaya/core/share/share_service.dart';
import 'package:akshaya/core/time/clock.dart';
import 'package:akshaya/features/pantry/domain/entities.dart';
import 'package:akshaya/features/pantry/domain/unit.dart';
import 'package:akshaya/features/pantry/presentation/providers.dart';
import 'package:akshaya/features/shopping/domain/shopping_entities.dart';
import 'package:akshaya/features/shopping/domain/shopping_enums.dart';
import 'package:akshaya/features/shopping/presentation/checkout_screen.dart';
import 'package:akshaya/features/shopping/presentation/entry_form_screen.dart';
import 'package:akshaya/features/shopping/presentation/providers.dart';
import 'package:akshaya/features/shopping/presentation/shopping_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../pantry/domain/test_data.dart';
import '../../pantry/presentation/fake_repository.dart';
import '../domain/shopping_test_data.dart';
import 'fake_shopping_repository.dart';

Widget host({
  required FakeShoppingRepository shopping,
  required FakePantryRepository pantry,
  required Widget home,
  FakeShareService? share,
}) {
  return ProviderScope(
    overrides: [
      shoppingRepositoryProvider.overrideWithValue(shopping),
      pantryRepositoryProvider.overrideWithValue(pantry),
      clockProvider.overrideWithValue(() => DateTime(2026, 11, 4, 10)),
      if (share != null) shareServiceProvider.overrideWithValue(share),
    ],
    child: MaterialApp(theme: AkshayaTheme.light(), home: home),
  );
}

void main() {
  void bigScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  // Plenty in stock: no suggestions get in the way.
  FakePantryRepository stockedPantry() {
    return FakePantryRepository(
      items: <ItemWithBatches>[
        ItemWithBatches(
          item: makeItem(name: 'Rice'),
          batches: <StockBatch>[makeBatch(bought: 5)],
        ),
        ItemWithBatches(
          item: makeItem(id: 'i2', name: 'Milk', categoryId: 'cat_dairy'),
          batches: <StockBatch>[makeBatch(id: 'b2', itemId: 'i2', bought: 3)],
        ),
      ],
    );
  }

  testWidgets('shows the empty state for a list with nothing on it',
      (WidgetTester tester) async {
    bigScreen(tester);
    await tester.pumpWidget(
      host(
        shopping: FakeShoppingRepository(),
        pantry: stockedPantry(),
        home: const ShoppingScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nothing to buy'), findsOneWidget);
    expect(find.text('Weekly'), findsOneWidget);
    expect(find.textContaining('Done shopping'), findsNothing);
  });

  testWidgets('groups entries by category and keeps checked ones in the basket',
      (WidgetTester tester) async {
    bigScreen(tester);
    await tester.pumpWidget(
      host(
        shopping: FakeShoppingRepository(
          entries: <ShoppingEntry>[
            makeEntry(id: 'e1', name: 'Rice', itemId: 'i1', quantity: 2),
            makeEntry(id: 'e2', name: 'Milk', itemId: 'i2', checked: true),
            makeEntry(id: 'e3', name: 'Candles', unit: Unit.pcs, quantity: 4),
          ],
        ),
        pantry: stockedPantry(),
        home: const ShoppingScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Grains & Rice (1)'), findsOneWidget);
    expect(find.text('Other (1)'), findsOneWidget);
    expect(find.text('In basket (1)'), findsOneWidget);
    expect(find.text('Done shopping (1)'), findsOneWidget);
    expect(find.text('Rice'), findsOneWidget);
    expect(find.text('2 kg'), findsOneWidget);
    expect(find.text('Candles'), findsOneWidget);
    // The list chip counts what is still to buy.
    expect(find.text('Weekly · 2'), findsOneWidget);
  });

  testWidgets('ticking an entry checks it off', (WidgetTester tester) async {
    bigScreen(tester);
    final FakeShoppingRepository shopping = FakeShoppingRepository(
      entries: <ShoppingEntry>[
        makeEntry(id: 'e1', name: 'Rice', itemId: 'i1'),
      ],
    );
    await tester.pumpWidget(
      host(
        shopping: shopping,
        pantry: stockedPantry(),
        home: const ShoppingScreen(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    expect(shopping.checkedCalls, <({String id, bool checked})>[
      (id: 'e1', checked: true),
    ]);
    // It moved to the basket and the Done shopping button appeared.
    expect(find.text('In basket (1)'), findsOneWidget);
    expect(find.text('Done shopping (1)'), findsOneWidget);
  });

  testWidgets('repeating entries that are not due yet cannot be ticked',
      (WidgetTester tester) async {
    bigScreen(tester);
    await tester.pumpWidget(
      host(
        shopping: FakeShoppingRepository(
          entries: <ShoppingEntry>[
            makeEntry(
              id: 'e1',
              name: 'Bread',
              unit: Unit.pcs,
              recurrence: Recurrence.weekly,
              dueOn: DateTime(2026, 11, 11),
            ),
          ],
        ),
        pantry: stockedPantry(),
        home: const ShoppingScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Repeats later (1)'), findsOneWidget);
    await tester.tap(find.text('Repeats later (1)'));
    await tester.pumpAndSettle();

    expect(find.text('Bread'), findsOneWidget);
    expect(find.textContaining('Back 11 Nov'), findsOneWidget);
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).onChanged, isNull);
  });

  testWidgets('swiping an entry away removes it and offers Undo',
      (WidgetTester tester) async {
    bigScreen(tester);
    final FakeShoppingRepository shopping = FakeShoppingRepository(
      entries: <ShoppingEntry>[
        makeEntry(id: 'e1', name: 'Candles', unit: Unit.pcs),
      ],
    );
    await tester.pumpWidget(
      host(
        shopping: shopping,
        pantry: stockedPantry(),
        home: const ShoppingScreen(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.text('Candles'), const Offset(-600, 0));
    await tester.pumpAndSettle();

    expect(shopping.deletedIds, <String>['e1']);
    expect(find.text('Removed Candles'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(shopping.undeletedIds, <String>['e1']);
  });

  group('suggestions', () {
    FakePantryRepository lowRicePantry() {
      return FakePantryRepository(
        items: <ItemWithBatches>[
          ItemWithBatches(
            item: makeItem(name: 'Rice', threshold: 2),
            batches: <StockBatch>[makeBatch(bought: 5, remaining: 1)],
          ),
        ],
      );
    }

    testWidgets('a low-stock item is suggested and added on tap',
        (WidgetTester tester) async {
      bigScreen(tester);
      final FakeShoppingRepository shopping = FakeShoppingRepository();
      await tester.pumpWidget(
        host(
          shopping: shopping,
          pantry: lowRicePantry(),
          home: const ShoppingScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Suggested for you (1)'), findsOneWidget);
      expect(find.text('1 kg left · buy 5 kg'), findsOneWidget);
      expect(shopping.addedDrafts, isEmpty);

      await tester.tap(find.byTooltip('Add Rice to the list'));
      await tester.pumpAndSettle();

      expect(shopping.addedDrafts, hasLength(1));
      final ShoppingEntryDraft draft = shopping.addedDrafts.single;
      expect(draft.itemId, 'i1');
      expect(draft.quantity, 5);
      expect(draft.addedReason, AddedReason.lowStock);
      // Once on the list, it is no longer suggested.
      expect(find.textContaining('Suggested for you'), findsNothing);
      expect(find.text('Rice'), findsOneWidget);
    });

    testWidgets('Add all adds every suggestion', (WidgetTester tester) async {
      bigScreen(tester);
      final FakeShoppingRepository shopping = FakeShoppingRepository();
      final FakePantryRepository pantry = FakePantryRepository(
        items: <ItemWithBatches>[
          ItemWithBatches(
            item: makeItem(name: 'Rice', threshold: 2),
            batches: <StockBatch>[makeBatch(bought: 5, remaining: 1)],
          ),
          ItemWithBatches(
            item: makeItem(id: 'i2', name: 'Milk', categoryId: 'cat_dairy'),
            batches: <StockBatch>[
              makeBatch(id: 'b2', itemId: 'i2', bought: 1, remaining: 0),
            ],
          ),
        ],
      );
      await tester.pumpWidget(
        host(shopping: shopping, pantry: pantry, home: const ShoppingScreen()),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add all'));
      await tester.pumpAndSettle();

      expect(
        shopping.addedDrafts.map((ShoppingEntryDraft d) => d.name).toSet(),
        <String>{'Rice', 'Milk'},
      );
    });

    testWidgets('a suggestion can be dismissed', (WidgetTester tester) async {
      bigScreen(tester);
      final FakeShoppingRepository shopping = FakeShoppingRepository();
      await tester.pumpWidget(
        host(
          shopping: shopping,
          pantry: lowRicePantry(),
          home: const ShoppingScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Dismiss Rice'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Suggested for you'), findsNothing);
      expect(shopping.addedDrafts, isEmpty);
    });
  });

  testWidgets('shares the list as plain text', (WidgetTester tester) async {
    bigScreen(tester);
    final FakeShareService share = FakeShareService();
    await tester.pumpWidget(
      host(
        shopping: FakeShoppingRepository(
          entries: <ShoppingEntry>[
            makeEntry(id: 'e1', name: 'Rice', itemId: 'i1', quantity: 2),
            makeEntry(id: 'e2', name: 'Candles', unit: Unit.pcs, quantity: 4),
          ],
        ),
        pantry: stockedPantry(),
        share: share,
        home: const ShoppingScreen(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('List options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Share as text'));
    await tester.pumpAndSettle();

    expect(share.shared, hasLength(1));
    expect(
      share.shared.single.text,
      '*Weekly*\n'
      '\n'
      '*Grains & Rice*\n'
      '• Rice — 2 kg\n'
      '\n'
      '*Other*\n'
      '• Candles — 4 pcs',
    );
    expect(share.shared.single.subject, 'Weekly');
  });

  group('entry form', () {
    testWidgets('saves a free-text entry', (WidgetTester tester) async {
      bigScreen(tester);
      final FakeShoppingRepository shopping = FakeShoppingRepository();
      await tester.pumpWidget(
        host(
          shopping: shopping,
          pantry: stockedPantry(),
          home: const EntryFormScreen(listId: kDefaultListId),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'What do you need?'),
        'Candles',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Quantity'),
        '3',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      final ShoppingEntryDraft draft = shopping.addedDrafts.single;
      expect(draft.name, 'Candles');
      expect(draft.quantity, 3);
      expect(draft.itemId, isNull);
      expect(draft.listId, kDefaultListId);
      expect(draft.addedReason, AddedReason.manual);
    });

    testWidgets('a name that matches a pantry item links to it',
        (WidgetTester tester) async {
      bigScreen(tester);
      final FakeShoppingRepository shopping = FakeShoppingRepository();
      await tester.pumpWidget(
        host(
          shopping: shopping,
          pantry: stockedPantry(),
          home: const EntryFormScreen(listId: kDefaultListId),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'What do you need?'),
        'milk',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      final ShoppingEntryDraft draft = shopping.addedDrafts.single;
      expect(draft.itemId, 'i2');
      expect(draft.name, 'Milk');
    });

    testWidgets('requires a name and a quantity', (WidgetTester tester) async {
      bigScreen(tester);
      final FakeShoppingRepository shopping = FakeShoppingRepository();
      await tester.pumpWidget(
        host(
          shopping: shopping,
          pantry: stockedPantry(),
          home: const EntryFormScreen(listId: kDefaultListId),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a name'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'What do you need?'),
        'Candles',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Quantity'),
        '0',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(find.text('Enter a quantity greater than zero'), findsOneWidget);
      expect(shopping.addedDrafts, isEmpty);
    });
  });

  group('Done shopping screen', () {
    testWidgets('sends expiry, price and store, then finishes',
        (WidgetTester tester) async {
      bigScreen(tester);
      final FakeShoppingRepository shopping = FakeShoppingRepository();
      final ShoppingEntry rice = makeEntry(
        id: 'e1',
        name: 'Rice',
        itemId: 'i1',
        quantity: 2,
        checked: true,
      );
      await tester.pumpWidget(
        host(
          shopping: shopping,
          pantry: stockedPantry(),
          home: CheckoutScreen(
            list: const ShoppingList(
              id: kDefaultListId,
              name: 'Weekly',
              sortOrder: 0,
            ),
            entries: <ShoppingEntry>[rice],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Rice'), findsOneWidget);
      expect(find.text('2 kg'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Store (optional)'),
        'DMart',
      );
      await tester.tap(find.widgetWithText(ActionChip, '+1 week'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Price paid (₹, optional)'),
        '1,250',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Add 1 item to pantry'));
      await tester.pumpAndSettle();

      final call = shopping.checkoutCalls.single;
      expect(call.listId, kDefaultListId);
      expect(call.store, 'DMart');
      expect(call.lines.single.entryId, 'e1');
      expect(call.lines.single.expiryDate, DateTime(2026, 11, 11));
      expect(call.lines.single.price, 1250);
    });

    testWidgets('expiry and price can be skipped', (WidgetTester tester) async {
      bigScreen(tester);
      final FakeShoppingRepository shopping = FakeShoppingRepository();
      await tester.pumpWidget(
        host(
          shopping: shopping,
          pantry: stockedPantry(),
          home: CheckoutScreen(
            list: const ShoppingList(
              id: kDefaultListId,
              name: 'Weekly',
              sortOrder: 0,
            ),
            entries: <ShoppingEntry>[
              makeEntry(id: 'e1', name: 'Rice', checked: true),
              makeEntry(id: 'e2', name: 'Salt', checked: true),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Add 2 items to pantry'));
      await tester.pumpAndSettle();

      final call = shopping.checkoutCalls.single;
      expect(call.lines, hasLength(2));
      expect(call.lines.every((CheckoutLine l) => l.price == null), isTrue);
      expect(call.lines.every((CheckoutLine l) => l.expiryDate == null), isTrue);
    });

    testWidgets('rejects an invalid price', (WidgetTester tester) async {
      bigScreen(tester);
      final FakeShoppingRepository shopping = FakeShoppingRepository();
      await tester.pumpWidget(
        host(
          shopping: shopping,
          pantry: stockedPantry(),
          home: CheckoutScreen(
            list: const ShoppingList(
              id: kDefaultListId,
              name: 'Weekly',
              sortOrder: 0,
            ),
            entries: <ShoppingEntry>[
              makeEntry(id: 'e1', name: 'Rice', checked: true),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Price paid (₹, optional)'),
        'abc',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Add 1 item to pantry'));
      await tester.pumpAndSettle();

      expect(find.text('Enter a valid price'), findsOneWidget);
      expect(shopping.checkoutCalls, isEmpty);
    });
  });
}
