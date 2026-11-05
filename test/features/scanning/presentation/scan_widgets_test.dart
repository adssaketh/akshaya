import 'package:akshaya/core/design/design.dart';
import 'package:akshaya/features/pantry/domain/entities.dart';
import 'package:akshaya/features/pantry/domain/unit.dart';
import 'package:akshaya/features/pantry/presentation/add_item_screen.dart';
import 'package:akshaya/features/pantry/presentation/providers.dart';
import 'package:akshaya/features/settings/presentation/providers.dart';
import 'package:akshaya/features/scanning/domain/product_info.dart';
import 'package:akshaya/features/scanning/domain/scan_service.dart';
import 'package:akshaya/features/scanning/presentation/barcode_scan_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../pantry/domain/test_data.dart';
import '../../pantry/presentation/fake_repository.dart';
import '../../settings/fake_settings_repository.dart';

Widget host(FakePantryRepository repo, Widget home) {
  return ProviderScope(
    overrides: [
      pantryRepositoryProvider.overrideWithValue(repo),
      settingsRepositoryProvider.overrideWithValue(FakeSettingsRepository()),
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

  group('typing a barcode', () {
    Future<void> openDialog(WidgetTester tester, void Function(String?) onResult) {
      return tester.pumpWidget(
        MaterialApp(
          theme: AkshayaTheme.light(),
          home: Builder(
            builder: (BuildContext context) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () async => onResult(await askForBarcode(context)),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('catches a mistyped digit', (WidgetTester tester) async {
      String? result = 'unset';
      await openDialog(tester, (String? code) => result = code);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '4006381333932');
      await tester.tap(find.text('Use this code'));
      await tester.pumpAndSettle();

      expect(find.textContaining('do not form a valid barcode'), findsOneWidget);
      expect(result, 'unset', reason: 'the dialog stays open');
    });

    testWidgets('asks for the right number of digits',
        (WidgetTester tester) async {
      await openDialog(tester, (String? _) {});
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '12345');
      await tester.tap(find.text('Use this code'));
      await tester.pumpAndSettle();

      expect(find.textContaining('8, 12, 13 or 14 digits'), findsOneWidget);
    });

    testWidgets('returns the canonical code', (WidgetTester tester) async {
      String? result;
      await openDialog(tester, (String? code) => result = code);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // A UPC-A code comes back as EAN-13.
      await tester.enterText(find.byType(TextField), '036000291452');
      await tester.tap(find.text('Use this code'));
      await tester.pumpAndSettle();

      expect(result, '0036000291452');
    });

    testWidgets('cancel returns nothing', (WidgetTester tester) async {
      String? result = 'unset';
      await openDialog(tester, (String? code) => result = code);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(result, isNull);
    });
  });

  group('add item after a scan', () {
    testWidgets('fills the form from Open Food Facts and saves the barcode',
        (WidgetTester tester) async {
      bigScreen(tester);
      final FakePantryRepository repo = FakePantryRepository();
      await tester.pumpWidget(
        host(
          repo,
          const AddItemScreen(
            initialScan: ScanNewProduct(
              barcode: '8901262010013',
              info: ProductInfo(
                name: 'Salted Butter',
                brand: 'Amul',
                quantityText: '500 g',
                categoryTags: <String>['en:butters'],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Salted Butter'), findsOneWidget);
      expect(find.text('Amul'), findsOneWidget);
      expect(find.text('8901262010013'), findsOneWidget);
      expect(find.text('500'), findsOneWidget);
      expect(find.textContaining('Filled in from Open Food Facts'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      final ItemDraft draft = repo.addedItems.single;
      expect(draft.name, 'Salted Butter');
      expect(draft.brand, 'Amul');
      expect(draft.barcode, '8901262010013');
      expect(draft.categoryId, 'cat_dairy');
      expect(draft.defaultUnit, Unit.g);
      expect(repo.addedBatches.single.quantityBought, 500);
      expect(repo.addedBatches.single.unit, Unit.g);
    });

    testWidgets('a barcode that was not found still gets saved',
        (WidgetTester tester) async {
      bigScreen(tester);
      final FakePantryRepository repo = FakePantryRepository();
      await tester.pumpWidget(
        host(
          repo,
          const AddItemScreen(
            initialScan: ScanNewProduct(
              barcode: '4006381333931',
              notice: ScanNotice.notFound,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('does not know this barcode'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Item name'),
        'Village Jaggery',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Quantity'),
        '1',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(repo.addedItems.single.name, 'Village Jaggery');
      expect(repo.addedItems.single.barcode, '4006381333931');
    });

    testWidgets('says so when the lookup could not run',
        (WidgetTester tester) async {
      bigScreen(tester);
      await tester.pumpWidget(
        host(
          FakePantryRepository(),
          const AddItemScreen(
            initialScan: ScanNewProduct(
              barcode: '4006381333931',
              notice: ScanNotice.offline,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Could not reach Open Food Facts'), findsOneWidget);
    });

    testWidgets('a barcode already in the pantry adds stock to that item',
        (WidgetTester tester) async {
      bigScreen(tester);
      final Item butter = makeItem(id: 'i7', name: 'Butter', unit: Unit.g);
      final FakePantryRepository repo = FakePantryRepository(
        items: <ItemWithBatches>[
          ItemWithBatches(item: butter, batches: const <StockBatch>[]),
        ],
      );
      await tester.pumpWidget(
        host(repo, AddItemScreen(initialScan: ScanKnownItem(butter))),
      );
      await tester.pumpAndSettle();

      expect(find.text('Add stock'), findsOneWidget);
      expect(find.text('Butter'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextFormField, 'Quantity'), '250');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(repo.addedItems, isEmpty);
      expect(repo.addedBatches.single.itemId, 'i7');
      expect(repo.addedBatches.single.quantityBought, 250);
      expect(repo.addedBarcodes, isEmpty);
    });

    testWidgets('a scanned barcode is linked when the name matches an item',
        (WidgetTester tester) async {
      bigScreen(tester);
      final Item butter = makeItem(id: 'i7', name: 'Butter', unit: Unit.g);
      final FakePantryRepository repo = FakePantryRepository(
        items: <ItemWithBatches>[
          ItemWithBatches(item: butter, batches: const <StockBatch>[]),
        ],
      );
      await tester.pumpWidget(
        host(
          repo,
          const AddItemScreen(
            initialScan: ScanNewProduct(
              barcode: '8901262010013',
              info: ProductInfo(name: 'Butter', quantityText: '100 g'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(repo.addedItems, isEmpty, reason: 'adds stock, not a duplicate');
      expect(repo.addedBarcodes.single, ('i7', '8901262010013'));
      expect(repo.addedBatches.single.itemId, 'i7');
      expect(repo.addedBatches.single.quantityBought, 100);
    });
  });
}
