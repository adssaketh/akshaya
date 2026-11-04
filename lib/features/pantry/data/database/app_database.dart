// The domain enums, converters and SyncStatus are only referenced by the
// generated part file (app_database.g.dart), so the analyzer may see them as
// unused here.
// ignore_for_file: unused_import

import 'package:drift/drift.dart';

import '../../../scanning/data/database/scanning_tables.dart';
import '../../../settings/data/database/settings_tables.dart';
import '../../../shopping/data/database/shopping_tables.dart';
import '../../../shopping/domain/shopping_entities.dart'
    show kDefaultListId, kDefaultListName;
import '../../../shopping/domain/shopping_enums.dart';
import '../../domain/consumption_type.dart';
import '../../domain/default_categories.dart';
import '../../domain/storage_location.dart';
import '../../domain/unit.dart';
import 'converters.dart';
import 'sync_status.dart';
import 'tables.dart';

part 'app_database.g.dart';

/// Akshaya's local SQLite database (the source of truth for the UI).
///
/// Schema history:
///  - v1 (Phase 1): categories, items, item_aliases, stock_batches,
///    consumption_logs.
///  - v2 (Phase 2): shopping_lists, shopping_entries (+ the default list).
///  - v3 (Phase 3): item_barcodes (existing `items.barcode` values are copied
///    in), product_cache (Open Food Facts answers).
///  - v4 (Phase 4): app_settings (local key/value settings, never synced).
///
/// Later phases add tables through migrations in [migration]; never edit a
/// released version in place.
@DriftDatabase(
  tables: <Type>[
    Categories,
    Items,
    ItemAliases,
    StockBatches,
    ConsumptionLogs,
    ShoppingLists,
    ShoppingEntries,
    ItemBarcodes,
    ProductCache,
    AppSettings,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
        await _seedCategories();
        await _seedDefaultList();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          await m.createTable(shoppingLists);
          await m.createTable(shoppingEntries);
          // Same indexes a fresh install gets from createAll().
          await customStatement(
            'CREATE INDEX IF NOT EXISTS shopping_entries_list_idx '
            'ON shopping_entries (list_id)',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS shopping_entries_item_idx '
            'ON shopping_entries (item_id)',
          );
          await _seedDefaultList();
        }
        if (from < 3) {
          await m.createTable(itemBarcodes);
          await m.createTable(productCache);
          await customStatement(
            'CREATE INDEX IF NOT EXISTS item_barcodes_barcode_idx '
            'ON item_barcodes (barcode)',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS item_barcodes_item_idx '
            'ON item_barcodes (item_id)',
          );
          // Barcodes typed in earlier versions live in items.barcode; make
          // them answer to scans too. That column stays as the item's main
          // barcode.
          await customStatement(
            'INSERT INTO item_barcodes (id, item_id, barcode, created_at) '
            'SELECT lower(hex(randomblob(16))), id, trim(barcode), created_at '
            "FROM items WHERE barcode IS NOT NULL AND trim(barcode) <> ''",
          );
        }
        if (from < 4) {
          // The alert worker may open the database before the app does, so
          // this must be safe to run twice (createTable is IF NOT EXISTS).
          await m.createTable(appSettings);
        }
      },
    );
  }

  /// The list every install starts with (fixed id, so synced devices agree).
  Future<void> _seedDefaultList() async {
    final DateTime now = DateTime.now();
    await into(shoppingLists).insert(
      ShoppingListsCompanion.insert(
        id: kDefaultListId,
        name: kDefaultListName,
        sortOrder: 0,
        createdAt: now,
        updatedAt: now,
      ),
      mode: InsertMode.insertOrIgnore,
    );
  }

  Future<void> _seedCategories() async {
    final DateTime now = DateTime.now();
    await batch((Batch b) {
      b.insertAll(categories, <CategoriesCompanion>[
        for (int i = 0; i < kDefaultCategories.length; i++)
          CategoriesCompanion.insert(
            id: kDefaultCategories[i].id,
            name: kDefaultCategories[i].name,
            iconKey: kDefaultCategories[i].iconKey,
            sortOrder: i,
            createdAt: now,
            updatedAt: now,
          ),
      ]);
    });
  }
}
