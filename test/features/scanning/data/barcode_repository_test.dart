import 'dart:io';

import 'package:akshaya/features/pantry/data/database/app_database.dart';
import 'package:akshaya/features/pantry/data/drift_pantry_repository.dart';
import 'package:akshaya/features/pantry/domain/entities.dart';
import 'package:akshaya/features/pantry/domain/failures.dart';
import 'package:akshaya/features/pantry/domain/unit.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late DriftPantryRepository repo;
  int counter = 0;

  setUp(() {
    counter = 0;
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftPantryRepository(
      db,
      clock: () => DateTime(2026, 11, 4, 10),
      idGenerator: () => 'id-${counter++}',
    );
  });

  tearDown(() => db.close());

  ItemDraft draft(String name, {String? barcode}) {
    return ItemDraft(
      name: name,
      categoryId: 'cat_grains',
      defaultUnit: Unit.kg,
      barcode: barcode,
    );
  }

  group('main barcode', () {
    test('is stored in canonical form and found under either spelling',
        () async {
      final Item butter = await repo.addItem(draft('Butter', barcode: '036000291452'));

      expect(butter.barcode, '0036000291452');
      expect((await repo.findItemByBarcode('0036000291452'))!.id, butter.id);
      expect((await repo.findItemByBarcode('036000291452'))!.id, butter.id);
    });

    test('returns null for an unknown or empty barcode', () async {
      await repo.addItem(draft('Butter', barcode: '4006381333931'));
      expect(await repo.findItemByBarcode('4006381333948'), isNull);
      expect(await repo.findItemByBarcode('  '), isNull);
    });

    test('a deleted item stops answering and frees its barcode', () async {
      final Item old = await repo.addItem(draft('Old', barcode: '4006381333931'));
      await repo.deleteItem(old.id);

      expect(await repo.findItemByBarcode('4006381333931'), isNull);
      final Item fresh = await repo.addItem(draft('Fresh', barcode: '4006381333931'));
      expect((await repo.findItemByBarcode('4006381333931'))!.id, fresh.id);
    });

    test('changing it moves the barcode to the new value', () async {
      final Item item = await repo.addItem(draft('Rice', barcode: '4006381333931'));

      await repo.updateItem(Item(
        id: item.id,
        name: item.name,
        barcode: '036000291452',
        categoryId: item.categoryId,
        defaultUnit: item.defaultUnit,
        aliases: item.aliases,
        isEssential: item.isEssential,
        defaultStorageLocation: item.defaultStorageLocation,
        createdAt: item.createdAt,
        updatedAt: item.updatedAt,
      ));

      expect(await repo.findItemByBarcode('4006381333931'), isNull);
      expect((await repo.findItemByBarcode('036000291452'))!.id, item.id);
    });

    test('cannot be changed to one that belongs to another item', () async {
      await repo.addItem(draft('Butter', barcode: '4006381333931'));
      final Item rice = await repo.addItem(draft('Rice'));

      await expectLater(
        repo.updateItem(Item(
          id: rice.id,
          name: rice.name,
          barcode: '4006381333931',
          categoryId: rice.categoryId,
          defaultUnit: rice.defaultUnit,
          aliases: rice.aliases,
          isEssential: rice.isEssential,
          defaultStorageLocation: rice.defaultStorageLocation,
          createdAt: rice.createdAt,
          updatedAt: rice.updatedAt,
        )),
        throwsA(isA<DuplicateBarcodeFailure>()),
      );
    });
  });

  group('addBarcode', () {
    test('lets one item answer to several barcodes', () async {
      final Item rice = await repo.addItem(draft('Rice', barcode: '4006381333931'));

      await repo.addBarcode(rice.id, '036000291452');

      expect((await repo.findItemByBarcode('4006381333931'))!.id, rice.id);
      expect((await repo.findItemByBarcode('036000291452'))!.id, rice.id);
    });

    test('the first barcode an item gets becomes its main barcode', () async {
      final Item rice = await repo.addItem(draft('Rice'));
      expect(rice.barcode, isNull);

      await repo.addBarcode(rice.id, '4006381333931');
      final Item? reloaded = await repo.findItemByBarcode('4006381333931');
      expect(reloaded!.barcode, '4006381333931');

      await repo.addBarcode(rice.id, '036000291452');
      final Item? still = await repo.findItemByBarcode('036000291452');
      expect(still!.barcode, '4006381333931', reason: 'main one is unchanged');
    });

    test('adding the same barcode again is harmless', () async {
      final Item rice = await repo.addItem(draft('Rice', barcode: '4006381333931'));

      await repo.addBarcode(rice.id, '4006381333931');
      await repo.addBarcode(rice.id, '4006381333931');

      final int rows = (await db.select(db.itemBarcodes).get()).length;
      expect(rows, 1);
    });

    test('refuses a barcode that belongs to another item', () async {
      await repo.addItem(draft('Butter', barcode: '4006381333931'));
      final Item rice = await repo.addItem(draft('Rice'));

      await expectLater(
        repo.addBarcode(rice.id, '4006381333931'),
        throwsA(isA<DuplicateBarcodeFailure>()),
      );
      await expectLater(
        repo.addBarcode(rice.id, '   '),
        throwsA(isA<InvalidInputFailure>()),
      );
    });

    test('refuses an item that does not exist', () async {
      await expectLater(
        repo.addBarcode('nope', '4006381333931'),
        throwsA(isA<NotFoundFailure>()),
      );
    });
  });

  group('schema v3', () {
    test('upgrades a version 2 database and keeps earlier barcodes', () async {
      final Directory dir = await Directory.systemTemp.createTemp('akshaya_v3');
      addTearDown(() => dir.delete(recursive: true));
      final File file = File('${dir.path}/upgrade.db');

      // Make a database that looks like Phase 2 left it: a barcode typed in
      // the old single column (not in canonical form), no barcode tables.
      final AppDatabase before = AppDatabase(NativeDatabase(file));
      final DriftPantryRepository oldRepo = DriftPantryRepository(before);
      final Item rice = await oldRepo.addItem(draft('Rice', barcode: '4006381333931'));
      await before.customStatement(
        "UPDATE items SET barcode = '036000291452' WHERE id = '${rice.id}'",
      );
      await before.customStatement('DROP TABLE item_barcodes');
      await before.customStatement('DROP TABLE product_cache');
      await before.customStatement('PRAGMA user_version = 2');
      await before.close();

      final AppDatabase upgraded = AppDatabase(NativeDatabase(file));
      addTearDown(upgraded.close);
      final DriftPantryRepository repo = DriftPantryRepository(upgraded);

      // The old barcode answers to scans, in either spelling.
      expect((await repo.findItemByBarcode('0036000291452'))!.id, rice.id);
      expect((await repo.findItemByBarcode('036000291452'))!.id, rice.id);

      // The new tables work.
      await repo.addBarcode(rice.id, '4006381333931');
      expect((await repo.findItemByBarcode('4006381333931'))!.id, rice.id);
      await upgraded.customSelect('SELECT * FROM product_cache').get();

      final List<String> indexes = (await upgraded
              .customSelect(
                "SELECT name FROM sqlite_master WHERE type = 'index' "
                "AND name LIKE 'item_barcodes_%' ORDER BY name",
              )
              .get())
          .map((row) => row.read<String>('name'))
          .toList();
      expect(indexes, <String>[
        'item_barcodes_barcode_idx',
        'item_barcodes_item_idx',
      ]);
    });
  });
}
