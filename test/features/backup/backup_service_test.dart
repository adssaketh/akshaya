import 'dart:convert';

import 'package:akshaya/features/backup/data/backup_service.dart';
import 'package:akshaya/features/backup/domain/backup_csv.dart';
import 'package:akshaya/features/backup/domain/csv.dart';
import 'package:akshaya/features/pantry/data/database/app_database.dart';
import 'package:akshaya/features/pantry/data/drift_pantry_repository.dart';
import 'package:akshaya/features/pantry/domain/entities.dart';
import 'package:akshaya/features/pantry/domain/failures.dart';
import 'package:akshaya/features/pantry/domain/storage_location.dart';
import 'package:akshaya/features/pantry/domain/unit.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase source;
  late AppDatabase target;
  late DriftPantryRepository sourceRepo;
  late DriftPantryRepository targetRepo;
  int counter = 0;

  setUp(() async {
    counter = 0;
    source = AppDatabase(NativeDatabase.memory());
    target = AppDatabase(NativeDatabase.memory());
    sourceRepo = DriftPantryRepository(
      source,
      clock: () => DateTime(2026, 11, 4, 10),
      idGenerator: () => 'id-${counter++}',
    );
    targetRepo = DriftPantryRepository(
      target,
      clock: () => DateTime(2026, 11, 1, 10),
      idGenerator: () => 'tid-${counter++}',
    );
    final Item rice = await sourceRepo.addItem(
      const ItemDraft(
        name: 'Rice',
        categoryId: 'cat_grains',
        defaultUnit: Unit.kg,
        aliases: <String>['biyyam'],
        barcode: '8901262010013',
      ),
    );
    await sourceRepo.addBatch(
      BatchDraft(
        itemId: rice.id,
        quantityBought: 5,
        unit: Unit.kg,
        purchaseDate: DateTime(2026, 11, 1),
        storageLocation: StorageLocation.pantry,
        price: 300,
        store: 'DMart',
      ),
    );
  });

  tearDown(() async {
    await source.close();
    await target.close();
  });

  test('a backup restores into an empty database', () async {
    final List<int> bytes = await BackupService(source).exportBytes();
    final ImportSummary summary = await BackupService(target).importBytes(bytes);
    expect(summary.added, greaterThan(0));

    final List<ItemWithBatches> items = await targetRepo.watchItems().first;
    final ItemWithBatches rice =
        items.firstWhere((ItemWithBatches r) => r.item.name == 'Rice');
    expect(rice.item.aliases, contains('biyyam'));
    expect(rice.batches.single.price, 300);
    expect(rice.batches.single.store, 'DMart');
    expect(rice.batches.single.purchaseDate, DateTime(2026, 11, 1));
  });

  test('importing the same file twice changes nothing the second time',
      () async {
    final List<int> bytes = await BackupService(source).exportBytes();
    await BackupService(target).importBytes(bytes);
    final ImportSummary again = await BackupService(target).importBytes(bytes);
    expect(again.added, 0);
    expect(again.updated, 0);
    expect(again.skipped, greaterThan(0));
  });

  test('a newer row in the file replaces an older one, not the reverse',
      () async {
    final List<int> bytes = await BackupService(source).exportBytes();
    await BackupService(target).importBytes(bytes);

    // Edit on the phone after the backup was made.
    final Map<String, Object?> data = jsonDecode(utf8.decode(bytes))
        as Map<String, Object?>;
    final Map<String, Object?> tables = data['tables']! as Map<String, Object?>;
    final List<Object?> items = tables['items']! as List<Object?>;
    final Map<String, Object?> row = items
        .cast<Map<String, Object?>>()
        .firstWhere((Map<String, Object?> r) => r['name'] == 'Rice');

    row['notes'] = 'older note';
    row['updated_at'] = (row['updated_at']! as int) - 1000;
    ImportSummary s = await BackupService(target).importData(data);
    expect(s.updated, 0, reason: 'older file keeps the phone version');

    row['notes'] = 'newer note';
    row['updated_at'] = (row['updated_at']! as int) + 5000;
    s = await BackupService(target).importData(data);
    expect(s.updated, 1);
    final List<ItemWithBatches> now = await targetRepo.watchItems().first;
    expect(
      now.firstWhere((ItemWithBatches r) => r.item.name == 'Rice').item.notes,
      'newer note',
    );
  });

  test('a file that is not a backup is rejected', () async {
    expect(
      () => BackupService(target).importBytes(utf8.encode('not json')),
      throwsA(isA<InvalidInputFailure>()),
    );
    expect(
      () => BackupService(target).importBytes(utf8.encode('{"a":1}')),
      throwsA(isA<InvalidInputFailure>()),
    );
  });

  test('a backup from a newer version is rejected', () async {
    expect(
      () => BackupService(target).importData(<String, Object?>{
        'format': BackupService.formatName,
        'version': 99,
        'tables': <String, Object?>{},
      }),
      throwsA(isA<InvalidInputFailure>()),
    );
  });

  test('a damaged row changes nothing', () async {
    final Map<String, Object?> data = await BackupService(source).exportData();
    final Map<String, Object?> tables = data['tables']! as Map<String, Object?>;
    final List<Object?> batches = tables['stock_batches']! as List<Object?>;
    (batches.first! as Map<String, Object?>).remove('quantity_bought');
    await expectLater(
      BackupService(target).importData(data),
      throwsA(isA<InvalidInputFailure>()),
    );
    final List<ItemWithBatches> items = await targetRepo.watchItems().first;
    expect(
      items.where((ItemWithBatches r) => r.item.name == 'Rice'),
      isEmpty,
      reason: 'the whole import rolls back',
    );
  });

  test('the export leaves out local-only columns', () async {
    final Map<String, Object?> data = await BackupService(source).exportData();
    final List<Object?> items =
        (data['tables']! as Map<String, Object?>)['items']! as List<Object?>;
    final Map<String, Object?> first = items.first! as Map<String, Object?>;
    expect(first.containsKey('sync_status'), isFalse);
    expect(first.containsKey('household_id'), isFalse);
  });

  group('CSV', () {
    test('quotes commas, quotes and newlines', () {
      expect(
        Csv.encode(<List<Object?>>[
          <Object?>['a,b', 'say "hi"', 'x\ny', 3, 2.5, null],
        ]),
        '"a,b","say ""hi""","x\ny",3,2.5,\r\n',
      );
    });

    test('defuses spreadsheet formulas', () {
      expect(Csv.encode(<List<Object?>>[<Object?>['=SUM(A1)']]), "'=SUM(A1)\r\n");
    });

    test('pantry CSV has a row per batch', () async {
      final List<ItemWithBatches> items = await sourceRepo.watchItems().first;
      final List<Category> cats = await sourceRepo.watchCategories().first;
      final List<String> lines =
          BackupCsv.pantry(items, cats).trim().split('\r\n');
      expect(lines.first, startsWith('Item,Brand,Category'));
      expect(lines.length, 2);
      expect(lines.last, contains('Rice'));
      expect(lines.last, contains('Grains & Rice'));
      expect(lines.last, contains('2026-11-01'));
    });
  });
}
