/// SQLite triggers that find the edits cloud sync has to send.
///
/// The pantry and shopping repositories write rows without knowing about sync.
/// Whenever such a write changes a synced row that was already marked
/// `synced`, these triggers mark it `pending` again. Inserts are `pending` by
/// default. The sync engine turns the triggers off (`sync_state.suppress = 1`)
/// while it applies documents that arrived from the cloud.
abstract final class SyncTriggers {
  /// Local tables whose rows are synced.
  static const List<String> syncedTables = <String>[
    'categories',
    'items',
    'stock_batches',
    'consumption_logs',
    'shopping_lists',
    'shopping_entries',
    'saved_recipes',
  ];

  static const String _notSuppressed =
      '(COALESCE((SELECT suppress FROM sync_state WHERE id = 1), 0) = 0)';

  /// Every statement to run, each safe to run twice.
  static List<String> statements() {
    final List<String> out = <String>[];
    for (final String table in syncedTables) {
      out.add(
        'CREATE TRIGGER IF NOT EXISTS sync_mark_$table AFTER UPDATE ON $table '
        "WHEN NEW.sync_status = OLD.sync_status AND NEW.sync_status <> 'pending' "
        'AND $_notSuppressed '
        'BEGIN '
        "UPDATE $table SET sync_status = 'pending' WHERE id = NEW.id; "
        'END',
      );
    }
    // Aliases and barcodes travel on their item's document, so changing them
    // makes the item pending.
    for (final String child in <String>['item_aliases', 'item_barcodes']) {
      out
        ..add(
          'CREATE TRIGGER IF NOT EXISTS sync_mark_${child}_ins '
          'AFTER INSERT ON $child WHEN $_notSuppressed '
          'BEGIN '
          "UPDATE items SET sync_status = 'pending' WHERE id = NEW.item_id; "
          'END',
        )
        ..add(
          'CREATE TRIGGER IF NOT EXISTS sync_mark_${child}_del '
          'AFTER DELETE ON $child WHEN $_notSuppressed '
          'BEGIN '
          "UPDATE items SET sync_status = 'pending' WHERE id = OLD.item_id; "
          'END',
        );
    }
    return out;
  }

  /// The one `sync_state` row.
  static const String seedState =
      'INSERT OR IGNORE INTO sync_state (id, household_id, user_id, suppress) '
      'VALUES (1, NULL, NULL, 0)';
}
