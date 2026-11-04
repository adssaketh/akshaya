import 'package:drift/drift.dart';

import '../../../pantry/data/database/converters.dart';
import '../../../pantry/data/database/tables.dart';
import '../../../pantry/domain/unit.dart';
import '../../domain/shopping_enums.dart';

/// Named shopping lists ("Weekly", "DMart"). Added in schema v2.
@DataClassName('ShoppingListRow')
class ShoppingLists extends Table with SyncColumns {
  TextColumn get name => text().withLength(min: 1, max: 60)();

  IntColumn get sortOrder => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// One thing to buy on a list. Added in schema v2.
@DataClassName('ShoppingEntryRow')
@TableIndex(name: 'shopping_entries_list_idx', columns: {#listId})
@TableIndex(name: 'shopping_entries_item_idx', columns: {#itemId})
class ShoppingEntries extends Table with SyncColumns {
  TextColumn get listId => text()();

  /// The pantry item this restocks; null for a free-text entry.
  TextColumn get itemId => text().nullable()();

  /// English display name.
  TextColumn get name => text().withLength(min: 1, max: 120)();

  RealColumn get quantity => real()();

  TextColumn get unit => textEnum<Unit>()();

  BoolColumn get isChecked => boolean().withDefault(const Constant(false))();

  TextColumn get addedReason => textEnum<AddedReason>()
      .withDefault(const Constant('manual'))();

  TextColumn get priority => textEnum<ShoppingPriority>()
      .withDefault(const Constant('normal'))();

  TextColumn get notes => text().nullable()();

  TextColumn get recurrence =>
      textEnum<Recurrence>().withDefault(const Constant('none'))();

  /// For repeating entries: the day the entry is back on the list.
  TextColumn get dueOn =>
      text().map(const DateOnlyConverter()).nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
