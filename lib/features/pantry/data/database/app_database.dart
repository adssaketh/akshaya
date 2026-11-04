// The domain enums, converters and SyncStatus are only referenced by the
// generated part file (app_database.g.dart), so the analyzer may see them as
// unused here.
// ignore_for_file: unused_import

import 'package:drift/drift.dart';

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
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
        await _seedCategories();
      },
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
