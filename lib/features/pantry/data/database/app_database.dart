// The domain enums, converters and SyncStatus are only referenced by the
// generated part file (app_database.g.dart), so the analyzer may see them as
// unused here.
// ignore_for_file: unused_import

import 'package:drift/drift.dart';

import '../../../../core/diagnostics/diag.dart';
import '../../../planner/data/database/planner_tables.dart';
import '../../../recipes/data/database/recipe_tables.dart';
import '../../../scanning/data/database/scanning_tables.dart';
import '../../../settings/data/database/settings_tables.dart';
import '../../../shopping/data/database/shopping_tables.dart';
import '../../../shopping/domain/shopping_entities.dart'
    show kDefaultListId, kDefaultListName;
import '../../../shopping/domain/shopping_enums.dart';
import '../../../sync/data/database/sync_tables.dart';
import '../../../sync/data/database/sync_triggers.dart';
import '../../../takeaway/data/database/takeaway_tables.dart';
import '../../../travel/data/database/trip_tables.dart';
import '../../domain/consumption_type.dart';
import '../../domain/default_categories.dart';
import '../../domain/item_kind.dart';
import '../../domain/storage_location.dart';
import '../../domain/unit.dart';
import '../../domain/waste_reason.dart';
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
///  - v5 (Phase 6): sync_state, sync_cursors, sync_batch_bases,
///    household_members (all local only) and the triggers that mark edited
///    rows as waiting to be synced.
///  - v6 (Phase 7): saved_recipes (synced, with its own sync trigger) and
///    recipe_cache (local only: the last AI recipe ideas).
///  - v7 (Phase 9): items.kind and items.shelf_life_days, stock_batches
///    .container_label and .check_by (all nullable, so older rows, backups and
///    synced documents stay valid; a missing kind means stocked).
///  - v8 (Phase 11): shopping_entries.repeat_every_days (nullable: a custom
///    repeat learned from purchase history; null keeps the built-in repeat).
///  - v9 (Phase 12): meal_plan_entries (synced, with its own sync trigger):
///    the weekly meal plan.
///  - v10 (Phase 13): consumption_logs.waste_reason (nullable).
///  - v11 (Phase 14): trips (synced, with its own sync trigger): travel mode.
///  - v12 (Phase 15): takeaway_meals (synced, with its own sync trigger):
///    food eaten from outside, counted in the eating report.
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
    SyncState,
    SyncCursors,
    SyncBatchBases,
    HouseholdMembers,
    SavedRecipes,
    RecipeCache,
    MealPlanEntries,
    Trips,
    TakeawayMeals,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// SQLite's `data_version` the last time [changedElsewhere] looked.
  int? _dataVersion;

  /// True when another connection to the file (a background task or a
  /// notification button run while the app was hidden) has saved changes since
  /// the last call. The first call always says yes, as nothing is known yet.
  ///
  /// `PRAGMA data_version` only moves for commits made by other connections,
  /// so the app's own writes never count.
  Future<bool> changedElsewhere() async {
    try {
      final QueryRow row =
          await customSelect('PRAGMA data_version').getSingle();
      final int version = row.data.values.first as int;
      final bool changed = _dataVersion == null || version != _dataVersion;
      _dataVersion = version;
      return changed;
    } on Object {
      return true;
    }
  }

  @override
  int get schemaVersion => 12;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        Diag.info('db', 'Creating a new database (v$schemaVersion)');
        await m.createAll();
        await _seedCategories();
        await _seedDefaultList();
        await _installSync();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        Diag.info('db', 'Upgrading the database from v$from to v$to');
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
        if (from < 5) {
          await m.createTable(syncState);
          await m.createTable(syncCursors);
          await m.createTable(syncBatchBases);
          await m.createTable(householdMembers);
        }
        if (from < 6) {
          await m.createTable(savedRecipes);
          await m.createTable(recipeCache);
          // The sync triggers cover every synced table, including
          // saved_recipes, so they are installed once all tables exist (this
          // also covers a jump from v4 straight to v6).
          await _installSync();
        }
        if (from < 7) {
          // Plain ALTER TABLE ... ADD COLUMN of nullable columns: existing
          // rows read as null (stocked, no shelf life, no container).
          // Each is skipped when the column is already there: the alert
          // worker may open the database before the app does, and test
          // fixtures build old databases from the current table classes.
          await _addColumnIfMissing(m, items, items.kind, 'kind');
          await _addColumnIfMissing(
            m,
            items,
            items.shelfLifeDays,
            'shelf_life_days',
          );
          await _addColumnIfMissing(
            m,
            stockBatches,
            stockBatches.containerLabel,
            'container_label',
          );
          await _addColumnIfMissing(
            m,
            stockBatches,
            stockBatches.checkBy,
            'check_by',
          );
        }
        if (from < 8) {
          // One nullable column, so existing entries keep their built-in
          // repeat. Skipped when already there (see the v7 note above).
          await _addColumnIfMissing(
            m,
            shoppingEntries,
            shoppingEntries.repeatEveryDays,
            'repeat_every_days',
          );
        }
        if (from < 9) {
          // One new table. Safe to run twice (createTable is IF NOT EXISTS),
          // because the alert worker may open the database before the app.
          await m.createTable(mealPlanEntries);
          await customStatement(
            'CREATE INDEX IF NOT EXISTS meal_plan_date_idx '
            'ON meal_plan_entries (plan_date)',
          );
          await _installSync();
        }
        if (from < 10) {
          // One nullable column, so existing logs keep reading as "no reason
          // recorded". Skipped when already there (see the v7 note above).
          await _addColumnIfMissing(
            m,
            consumptionLogs,
            consumptionLogs.wasteReason,
            'waste_reason',
          );
        }
        if (from < 11) {
          // One new table. Safe to run twice (createTable is IF NOT EXISTS),
          // because the alert worker may open the database before the app.
          await m.createTable(trips);
          await _installSync();
        }
        if (from < 12) {
          // One new table. Safe to run twice (createTable is IF NOT EXISTS),
          // because the alert worker may open the database before the app.
          await m.createTable(takeawayMeals);
          await customStatement(
            'CREATE INDEX IF NOT EXISTS takeaway_day_idx '
            'ON takeaway_meals (eaten_on)',
          );
          await _installSync();
        }
      },
    );
  }

  Future<void> _addColumnIfMissing(
    Migrator m,
    TableInfo<Table, dynamic> table,
    GeneratedColumn<Object> column,
    String columnName,
  ) async {
    final List<QueryRow> info = await customSelect(
      'PRAGMA table_info(${table.actualTableName})',
    ).get();
    final bool exists =
        info.any((QueryRow row) => row.read<String>('name') == columnName);
    if (!exists) {
      await m.addColumn(table, column);
    }
  }

  /// The sync bookkeeping row and the triggers that capture edits. Safe to run
  /// twice.
  Future<void> _installSync() async {
    await customStatement(SyncTriggers.seedState);
    // Only for tables that exist: an upgrade from an old version installs the
    // triggers in the step that adds saved_recipes, before a newer table
    // (such as meal_plan_entries) has been created.
    final List<QueryRow> tableRows = await customSelect(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    ).get();
    final Set<String> existing = <String>{
      for (final QueryRow row in tableRows) row.read<String>('name'),
    };
    for (final String statement
        in SyncTriggers.statements(onlyTables: existing)) {
      await customStatement(statement);
    }
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
