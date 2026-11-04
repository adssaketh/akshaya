// The domain enums, converters and SyncStatus are only referenced by the
// generated part file (app_database.g.dart), so the analyzer may see them as
// unused here.
// ignore_for_file: unused_import

import 'package:drift/drift.dart';

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
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 2;

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
