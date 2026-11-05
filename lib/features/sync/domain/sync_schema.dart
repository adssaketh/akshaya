/// How a column is stored in SQLite and sent to Firestore.
enum SyncColumnKind { text, integer, real, boolean }

/// "quantity_remaining" -> "quantityRemaining": the Firestore field name of a
/// SQLite column.
String snakeToCamel(String snake) {
  final StringBuffer out = StringBuffer();
  bool upper = false;
  for (final int unit in snake.codeUnits) {
    final String ch = String.fromCharCode(unit);
    if (ch == '_') {
      upper = true;
    } else {
      out.write(upper ? ch.toUpperCase() : ch);
      upper = false;
    }
  }
  return out.toString();
}

/// One synced column of a table.
final class SyncColumn {
  const SyncColumn(this.sql, this.kind, {this.required = false});

  /// SQLite column name (snake case).
  final String sql;
  final SyncColumnKind kind;

  /// True when the column is NOT NULL locally, so a document without it
  /// cannot be stored.
  final bool required;

  /// Firestore field name.
  String get field => snakeToCamel(sql);
}

/// Tables that need extra handling.
enum SyncTableKind {
  /// A plain row.
  plain,

  /// Items carry their aliases and barcodes as arrays on the document.
  item,

  /// Stock batches merge their remaining quantity by difference, so two
  /// people using the same stock at once never overwrite each other.
  batch,
}

/// One local table and the Firestore collection it travels in
/// (`households/{id}/{collection}`).
final class SyncTableSpec {
  const SyncTableSpec({
    required this.table,
    required this.collection,
    required this.columns,
    this.kind = SyncTableKind.plain,
  });

  final String table;
  final String collection;

  /// Every synced column, including the shared ones. `sync_status` is local
  /// only and `image_path` is a path on this phone, so neither is listed.
  final List<SyncColumn> columns;
  final SyncTableKind kind;

  bool get isBatch => kind == SyncTableKind.batch;

  bool get isItem => kind == SyncTableKind.item;

  /// Firestore field names of [columns].
  List<String> get fields => <String>[for (final SyncColumn c in columns) c.field];
}

/// The synced tables (schema from Phase 1 to 4, recipes from Phase 7 and the
/// meal plan from Phase 12) and their documents.
abstract final class SyncSchema {
  static const List<SyncColumn> _shared = <SyncColumn>[
    SyncColumn('id', SyncColumnKind.text, required: true),
    SyncColumn('household_id', SyncColumnKind.text),
    SyncColumn('created_at', SyncColumnKind.integer, required: true),
    SyncColumn('updated_at', SyncColumnKind.integer, required: true),
    SyncColumn('updated_by', SyncColumnKind.text),
    SyncColumn('is_deleted', SyncColumnKind.boolean, required: true),
  ];

  static const SyncTableSpec categories = SyncTableSpec(
    table: 'categories',
    collection: 'categories',
    columns: <SyncColumn>[
      ..._shared,
      SyncColumn('name', SyncColumnKind.text, required: true),
      SyncColumn('icon_key', SyncColumnKind.text, required: true),
      SyncColumn('sort_order', SyncColumnKind.integer, required: true),
    ],
  );

  static const SyncTableSpec items = SyncTableSpec(
    table: 'items',
    collection: 'items',
    kind: SyncTableKind.item,
    columns: <SyncColumn>[
      ..._shared,
      SyncColumn('name', SyncColumnKind.text, required: true),
      SyncColumn('brand', SyncColumnKind.text),
      SyncColumn('barcode', SyncColumnKind.text),
      SyncColumn('category_id', SyncColumnKind.text, required: true),
      SyncColumn('default_unit', SyncColumnKind.text, required: true),
      SyncColumn('notes', SyncColumnKind.text),
      SyncColumn('low_stock_threshold', SyncColumnKind.real),
      SyncColumn('is_essential', SyncColumnKind.boolean, required: true),
      SyncColumn('default_storage_location', SyncColumnKind.text, required: true),
      // Phase 9. Optional, so documents from older apps still load.
      SyncColumn('kind', SyncColumnKind.text),
      SyncColumn('shelf_life_days', SyncColumnKind.integer),
    ],
  );

  static const SyncTableSpec batches = SyncTableSpec(
    table: 'stock_batches',
    collection: 'batches',
    kind: SyncTableKind.batch,
    columns: <SyncColumn>[
      ..._shared,
      SyncColumn('item_id', SyncColumnKind.text, required: true),
      SyncColumn('quantity_bought', SyncColumnKind.real, required: true),
      SyncColumn('quantity_remaining', SyncColumnKind.real, required: true),
      SyncColumn('unit', SyncColumnKind.text, required: true),
      SyncColumn('purchase_date', SyncColumnKind.text, required: true),
      SyncColumn('expiry_date', SyncColumnKind.text),
      SyncColumn('opened_date', SyncColumnKind.text),
      SyncColumn('use_within_days_after_opening', SyncColumnKind.integer),
      SyncColumn('price', SyncColumnKind.real),
      SyncColumn('store', SyncColumnKind.text),
      SyncColumn('storage_location', SyncColumnKind.text, required: true),
      // Phase 9. Optional, so documents from older apps still load.
      SyncColumn('container_label', SyncColumnKind.text),
      SyncColumn('check_by', SyncColumnKind.text),
    ],
  );

  static const SyncTableSpec logs = SyncTableSpec(
    table: 'consumption_logs',
    collection: 'logs',
    columns: <SyncColumn>[
      ..._shared,
      SyncColumn('batch_id', SyncColumnKind.text, required: true),
      SyncColumn('item_id', SyncColumnKind.text, required: true),
      SyncColumn('quantity_used', SyncColumnKind.real, required: true),
      SyncColumn('unit', SyncColumnKind.text, required: true),
      SyncColumn('date', SyncColumnKind.integer, required: true),
      SyncColumn('type', SyncColumnKind.text, required: true),
    ],
  );

  static const SyncTableSpec shoppingLists = SyncTableSpec(
    table: 'shopping_lists',
    collection: 'shoppingLists',
    columns: <SyncColumn>[
      ..._shared,
      SyncColumn('name', SyncColumnKind.text, required: true),
      SyncColumn('sort_order', SyncColumnKind.integer, required: true),
    ],
  );

  static const SyncTableSpec entries = SyncTableSpec(
    table: 'shopping_entries',
    collection: 'entries',
    columns: <SyncColumn>[
      ..._shared,
      SyncColumn('list_id', SyncColumnKind.text, required: true),
      SyncColumn('item_id', SyncColumnKind.text),
      SyncColumn('name', SyncColumnKind.text, required: true),
      SyncColumn('quantity', SyncColumnKind.real, required: true),
      SyncColumn('unit', SyncColumnKind.text, required: true),
      SyncColumn('is_checked', SyncColumnKind.boolean, required: true),
      SyncColumn('added_reason', SyncColumnKind.text, required: true),
      SyncColumn('priority', SyncColumnKind.text, required: true),
      SyncColumn('notes', SyncColumnKind.text),
      SyncColumn('recurrence', SyncColumnKind.text, required: true),
      SyncColumn('due_on', SyncColumnKind.text),
      // Phase 11. Optional, so documents from older apps still load.
      SyncColumn('repeat_every_days', SyncColumnKind.integer),
    ],
  );

  /// Recipes the household kept (Phase 7). Ingredients and steps travel as
  /// JSON text inside the document.
  static const SyncTableSpec recipes = SyncTableSpec(
    table: 'saved_recipes',
    collection: 'recipes',
    columns: <SyncColumn>[
      ..._shared,
      SyncColumn('title', SyncColumnKind.text, required: true),
      SyncColumn('cuisine', SyncColumnKind.text),
      SyncColumn('time_minutes', SyncColumnKind.integer, required: true),
      SyncColumn('servings', SyncColumnKind.integer, required: true),
      SyncColumn('diet', SyncColumnKind.text, required: true),
      SyncColumn('ingredients_json', SyncColumnKind.text, required: true),
      SyncColumn('steps_json', SyncColumnKind.text, required: true),
      SyncColumn('source', SyncColumnKind.text, required: true),
      SyncColumn('saved_at', SyncColumnKind.integer, required: true),
    ],
  );

  /// The weekly meal plan (Phase 12). The recipe and the prep reminders
  /// travel as JSON text inside the document. Every column except the shared
  /// ones is optional on the way in where a missing value has a safe meaning,
  /// so a document from a newer app still loads.
  static const SyncTableSpec mealPlan = SyncTableSpec(
    table: 'meal_plan_entries',
    collection: 'mealPlan',
    columns: <SyncColumn>[
      ..._shared,
      SyncColumn('plan_date', SyncColumnKind.text, required: true),
      SyncColumn('slot', SyncColumnKind.text, required: true),
      SyncColumn('title', SyncColumnKind.text, required: true),
      SyncColumn('recipe_json', SyncColumnKind.text),
      SyncColumn('leftover_item_id', SyncColumnKind.text),
      SyncColumn('is_cooked', SyncColumnKind.boolean, required: true),
      SyncColumn('prep_json', SyncColumnKind.text),
    ],
  );

  /// Push and pull order: things other rows point at come first.
  static const List<SyncTableSpec> tables = <SyncTableSpec>[
    categories,
    items,
    shoppingLists,
    batches,
    entries,
    logs,
    recipes,
    mealPlan,
  ];

  /// The spec for a Firestore collection name, or null.
  static SyncTableSpec? byCollection(String collection) {
    for (final SyncTableSpec spec in tables) {
      if (spec.collection == collection) {
        return spec;
      }
    }
    return null;
  }

  /// Firestore collection names, in [tables] order.
  static List<String> get collections =>
      <String>[for (final SyncTableSpec s in tables) s.collection];
}
