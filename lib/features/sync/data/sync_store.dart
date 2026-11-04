import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../pantry/data/database/app_database.dart';
import '../../shopping/domain/shopping_entities.dart' show kDefaultListId;
import '../domain/sync_documents.dart';
import '../domain/sync_merge.dart';
import '../domain/sync_models.dart';
import '../domain/sync_remote.dart';
import '../domain/sync_schema.dart';

/// A local row waiting to be sent, with what travels with it.
final class PendingRow {
  const PendingRow({
    required this.spec,
    required this.row,
    this.aliases = const <String>[],
    this.barcodes = const <String>[],
    this.base,
  });

  final SyncTableSpec spec;

  /// The raw column map.
  final Map<String, Object?> row;

  /// Items only.
  final List<String> aliases;
  final List<String> barcodes;

  /// Batches only: the remaining quantity the cloud last held, or null when
  /// this batch has never been synced.
  final double? base;

  String get id => row['id'] as String;

  /// Batches only: how much the remaining quantity changed since the cloud
  /// last held it.
  double get delta {
    if (!spec.isBatch || base == null) {
      return 0;
    }
    final num remaining = row['quantity_remaining'] as num;
    return SyncMerge.roundQuantity(remaining.toDouble() - base!);
  }
}

/// What applying one incoming document did.
final class ApplyOutcome {
  const ApplyOutcome({
    required this.id,
    required this.inserted,
    required this.removed,
    this.updatedBy,
    this.listId,
  });

  final String id;

  /// True when the row did not exist on this phone before.
  final bool inserted;

  /// True when the document is a soft delete.
  final bool removed;

  /// Who made the change in the cloud.
  final String? updatedBy;

  /// Shopping entries only: the list the entry is on.
  final String? listId;
}

/// All raw-SQL work of cloud sync on the local database: finding edits to
/// send, applying documents that arrived, and the small bookkeeping tables.
///
/// Rows are handled as raw column maps; see `SyncDocuments`.
class SyncStore {
  SyncStore(this._db, {DateTime Function()? clock, Uuid? uuid})
      : _clock = clock ?? DateTime.now,
        _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final DateTime Function() _clock;
  final Uuid _uuid;

  /// Cursor key: when the last purge of old deleted documents ran.
  static const String purgeKey = '_purge';

  /// Cursor key: the newest document an alert has been shown for.
  static const String alertKey = '_alerted';

  // ---------------------------------------------------------------------
  // Raw helpers
  // ---------------------------------------------------------------------

  static Variable<Object> _bind(Object? value) {
    if (value == null) {
      return const Variable<Object>(null);
    }
    if (value is int) {
      return Variable<int>(value);
    }
    if (value is double) {
      return Variable<double>(value);
    }
    if (value is bool) {
      return Variable<bool>(value);
    }
    return Variable<String>(value.toString());
  }

  Future<List<Map<String, Object?>>> _query(
    String sql, [
    List<Object?> args = const <Object?>[],
  ]) async {
    final List<QueryRow> rows = await _db
        .customSelect(
          sql,
          variables: <Variable<Object>>[for (final Object? a in args) _bind(a)],
        )
        .get();
    return <Map<String, Object?>>[
      for (final QueryRow row in rows) Map<String, Object?>.of(row.data),
    ];
  }

  Future<Map<String, Object?>?> _row(String table, String id) async {
    final List<Map<String, Object?>> rows =
        await _query('SELECT * FROM $table WHERE id = ?', <Object?>[id]);
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> _exec(String sql, [List<Object?> args = const <Object?>[]]) {
    return _db.customStatement(sql, args);
  }

  void _notify(Iterable<String> tables) {
    _db.notifyUpdates(<TableUpdate>{
      for (final String table in tables) TableUpdate(table),
    });
  }

  /// Runs [body] in one transaction with the change-capture triggers off, so
  /// what it writes is not mistaken for local edits.
  Future<void> _suppressed(
    Iterable<String> tables,
    Future<void> Function() body,
  ) {
    return _db.transaction<void>(() async {
      await _exec('UPDATE sync_state SET suppress = 1 WHERE id = 1');
      try {
        await body();
      } finally {
        await _exec('UPDATE sync_state SET suppress = 0 WHERE id = 1');
      }
      _notify(tables);
    });
  }

  static Iterable<String> _tablesOf(SyncTableSpec spec) => <String>[
        spec.table,
        if (spec.isItem) 'item_aliases',
        if (spec.isItem) 'item_barcodes',
      ];

  // ---------------------------------------------------------------------
  // Identity
  // ---------------------------------------------------------------------

  static SyncIdentity _identityOf(List<Map<String, Object?>> rows) {
    if (rows.isEmpty) {
      return SyncIdentity.none;
    }
    return SyncIdentity(
      householdId: rows.first['household_id'] as String?,
      userId: rows.first['user_id'] as String?,
    );
  }

  Future<SyncIdentity> identity() async {
    return _identityOf(
      await _query('SELECT household_id, user_id FROM sync_state WHERE id = 1'),
    );
  }

  Stream<SyncIdentity> watchIdentity() {
    return _db
        .customSelect(
          'SELECT household_id, user_id FROM sync_state WHERE id = 1',
          readsFrom: <ResultSetImplementation<dynamic, dynamic>>{_db.syncState},
        )
        .watch()
        .map(
          (List<QueryRow> rows) => _identityOf(
            <Map<String, Object?>>[
              for (final QueryRow row in rows) Map<String, Object?>.of(row.data),
            ],
          ),
        );
  }

  Future<void> setIdentity({String? householdId, String? userId}) async {
    await _exec(
      'UPDATE sync_state SET household_id = ?, user_id = ? WHERE id = 1',
      <Object?>[householdId, userId],
    );
    _notify(<String>['sync_state']);
  }

  // ---------------------------------------------------------------------
  // Sending
  // ---------------------------------------------------------------------

  /// Marks every row that belongs to no household (or to another one) as
  /// pending under [householdId], so it is uploaded.
  Future<void> assignHousehold(String householdId) async {
    for (final SyncTableSpec spec in SyncSchema.tables) {
      await _exec(
        'UPDATE ${spec.table} SET household_id = ?, sync_status = \'pending\' '
        'WHERE household_id IS NULL OR household_id <> ?',
        <Object?>[householdId, householdId],
      );
    }
    _notify(<String>[for (final SyncTableSpec s in SyncSchema.tables) s.table]);
  }

  /// Up to [limit] rows of [spec] waiting to be sent, oldest first.
  Future<List<PendingRow>> pendingRows(
    SyncTableSpec spec,
    String householdId, {
    int limit = 100,
  }) async {
    final List<Map<String, Object?>> rows = await _query(
      'SELECT * FROM ${spec.table} '
      'WHERE sync_status = \'pending\' AND household_id = ? '
      'ORDER BY updated_at, id LIMIT ?',
      <Object?>[householdId, limit],
    );
    final List<PendingRow> out = <PendingRow>[];
    for (final Map<String, Object?> row in rows) {
      out.add(await _pendingOf(spec, row));
    }
    return out;
  }

  Future<PendingRow> _pendingOf(
    SyncTableSpec spec,
    Map<String, Object?> row,
  ) async {
    final String id = row['id'] as String;
    if (spec.isItem) {
      return PendingRow(
        spec: spec,
        row: row,
        aliases: await _aliasesOf(id),
        barcodes: await _barcodesOf(id),
      );
    }
    if (spec.isBatch) {
      return PendingRow(spec: spec, row: row, base: await _baseOf(id));
    }
    return PendingRow(spec: spec, row: row);
  }

  Future<List<String>> _aliasesOf(String itemId) async {
    final List<Map<String, Object?>> rows = await _query(
      'SELECT alias FROM item_aliases WHERE item_id = ? ORDER BY alias',
      <Object?>[itemId],
    );
    return <String>[for (final Map<String, Object?> r in rows) r['alias'] as String];
  }

  Future<List<String>> _barcodesOf(String itemId) async {
    final List<Map<String, Object?>> rows = await _query(
      'SELECT barcode FROM item_barcodes WHERE item_id = ? ORDER BY barcode',
      <Object?>[itemId],
    );
    return <String>[
      for (final Map<String, Object?> r in rows) r['barcode'] as String,
    ];
  }

  Future<double?> _baseOf(String batchId) async {
    final List<Map<String, Object?>> rows = await _query(
      'SELECT base_remaining FROM sync_batch_bases WHERE batch_id = ?',
      <Object?>[batchId],
    );
    if (rows.isEmpty) {
      return null;
    }
    return (rows.first['base_remaining'] as num).toDouble();
  }

  Future<void> _setBase(String batchId, double quantity) {
    return _exec(
      'INSERT INTO sync_batch_bases (batch_id, base_remaining) VALUES (?, ?) '
      'ON CONFLICT(batch_id) DO UPDATE SET base_remaining = excluded.base_remaining',
      <Object?>[batchId, quantity],
    );
  }

  /// The document to send for [pending].
  PushDoc toPushDoc(PendingRow pending, String householdId, String userId) {
    return PushDoc(
      id: pending.id,
      fields: SyncDocuments.toRemote(
        pending.spec,
        pending.row,
        householdId: householdId,
        userId: userId,
        aliases: pending.aliases,
        barcodes: pending.barcodes,
      ),
      delta: pending.delta,
    );
  }

  /// Records that [pending] was sent and the cloud now holds [result].
  ///
  /// The row is marked synced only if it has not been edited since it was
  /// read; an edit made while the push was running stays pending. Then the
  /// cloud's version is applied (it may differ: a newer cloud copy wins).
  Future<ApplyOutcome?> completePush(
    PendingRow pending,
    Map<String, Object?> result,
  ) async {
    ApplyOutcome? outcome;
    final SyncTableSpec spec = pending.spec;
    await _suppressed(<String>[..._tablesOf(spec), 'sync_batch_bases'], () async {
      final Map<String, Object?>? current = await _row(spec.table, pending.id);
      if (current != null) {
        if (spec.isBatch) {
          await _setBase(
            pending.id,
            (pending.row['quantity_remaining'] as num).toDouble(),
          );
        }
        if (await _unchanged(pending, current)) {
          await _exec(
            'UPDATE ${spec.table} SET sync_status = \'synced\' WHERE id = ?',
            <Object?>[pending.id],
          );
        }
      }
      outcome = await _applyDoc(spec, result);
    });
    return outcome;
  }

  Future<bool> _unchanged(
    PendingRow pending,
    Map<String, Object?> current,
  ) async {
    for (final SyncColumn column in pending.spec.columns) {
      if (current[column.sql] != pending.row[column.sql]) {
        return false;
      }
    }
    if (pending.spec.isItem) {
      final List<String> aliases = await _aliasesOf(pending.id);
      final List<String> barcodes = await _barcodesOf(pending.id);
      if (!_sameList(aliases, pending.aliases) ||
          !_sameList(barcodes, pending.barcodes)) {
        return false;
      }
    }
    return true;
  }

  static bool _sameList(List<String> a, List<String> b) {
    if (a.length != b.length) {
      return false;
    }
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }

  // ---------------------------------------------------------------------
  // Receiving
  // ---------------------------------------------------------------------

  /// Applies documents that arrived from the cloud. A document that cannot be
  /// stored (missing or malformed fields) is skipped.
  Future<List<ApplyOutcome>> applyRemote(
    SyncTableSpec spec,
    List<RemoteDoc> docs,
  ) async {
    final List<ApplyOutcome> outcomes = <ApplyOutcome>[];
    if (docs.isEmpty) {
      return outcomes;
    }
    await _suppressed(<String>[..._tablesOf(spec), 'sync_batch_bases'], () async {
      for (final RemoteDoc doc in docs) {
        try {
          final ApplyOutcome? outcome = await _applyDoc(spec, doc.data);
          if (outcome != null) {
            outcomes.add(outcome);
          }
        } on Object {
          // One document that cannot be stored must not stop the others.
        }
      }
    });
    return outcomes;
  }

  Future<ApplyOutcome?> _applyDoc(
    SyncTableSpec spec,
    Map<String, Object?> doc,
  ) async {
    final Map<String, Object?> remote;
    try {
      remote = SyncDocuments.toLocal(spec, doc);
    } on FormatException {
      return null;
    }
    final String id = remote['id'] as String;
    final bool removed = (remote['is_deleted'] as int) == 1;
    final String? updatedBy = remote['updated_by'] as String?;
    final String? listId = spec.table == 'shopping_entries'
        ? remote['list_id'] as String?
        : null;

    final Map<String, Object?>? existing = await _row(spec.table, id);
    final double? remoteQuantity =
        spec.isBatch ? (remote['quantity_remaining'] as num).toDouble() : null;

    if (existing == null) {
      await _upsert(spec, remote, 'synced');
      if (spec.isItem) {
        await _replaceChildren(
          id,
          SyncDocuments.aliasesOf(doc),
          SyncDocuments.barcodesOf(doc),
        );
      }
      if (remoteQuantity != null) {
        await _setBase(id, remoteQuantity);
      }
      return ApplyOutcome(
        id: id,
        inserted: true,
        removed: removed,
        updatedBy: updatedBy,
        listId: listId,
      );
    }

    final bool pending = existing['sync_status'] == 'pending';
    final int localUpdated = (existing['updated_at'] as num).toInt();
    final int remoteUpdated = (remote['updated_at'] as num).toInt();
    final bool keep = SyncMerge.keepLocal(
      localPending: pending,
      localUpdatedAt: localUpdated,
      remoteUpdatedAt: remoteUpdated,
    );

    double? merged;
    if (remoteQuantity != null) {
      merged = SyncMerge.mergeQuantity(
        remote: remoteQuantity,
        local: (existing['quantity_remaining'] as num).toDouble(),
        base: await _baseOf(id),
      );
    }

    if (keep) {
      final double? localQuantity = existing['quantity_remaining'] == null
          ? null
          : (existing['quantity_remaining'] as num).toDouble();
      if (merged != null && merged != localQuantity) {
        await _exec(
          'UPDATE stock_batches SET quantity_remaining = ? WHERE id = ?',
          <Object?>[merged, id],
        );
      }
    } else {
      if (merged != null) {
        remote['quantity_remaining'] = merged;
      }
      // Anything this phone still owes the cloud (a quantity difference)
      // keeps the row pending.
      final bool owes = remoteQuantity != null && merged != remoteQuantity;
      await _upsert(spec, remote, owes ? 'pending' : 'synced');
      if (spec.isItem) {
        await _replaceChildren(
          id,
          SyncDocuments.aliasesOf(doc),
          SyncDocuments.barcodesOf(doc),
        );
      }
    }
    if (remoteQuantity != null) {
      await _setBase(id, remoteQuantity);
    }
    return ApplyOutcome(
      id: id,
      inserted: false,
      removed: removed,
      updatedBy: updatedBy,
      listId: listId,
    );
  }

  Future<void> _upsert(
    SyncTableSpec spec,
    Map<String, Object?> values,
    String status,
  ) {
    final List<String> columns = <String>[
      for (final SyncColumn c in spec.columns) c.sql,
      'sync_status',
    ];
    final String placeholders =
        List<String>.filled(columns.length, '?').join(', ');
    final String assignments = <String>[
      for (final String c in columns)
        if (c != 'id') '$c = excluded.$c',
    ].join(', ');
    return _exec(
      'INSERT INTO ${spec.table} (${columns.join(', ')}) VALUES ($placeholders) '
      'ON CONFLICT(id) DO UPDATE SET $assignments',
      <Object?>[
        for (final SyncColumn c in spec.columns) values[c.sql],
        status,
      ],
    );
  }

  Future<void> _replaceChildren(
    String itemId,
    List<String> aliases,
    List<String> barcodes,
  ) async {
    final int now = _clock().millisecondsSinceEpoch;
    await _exec('DELETE FROM item_aliases WHERE item_id = ?', <Object?>[itemId]);
    for (final String alias in aliases) {
      await _exec(
        'INSERT INTO item_aliases (id, item_id, alias, created_at) '
        'VALUES (?, ?, ?, ?)',
        <Object?>[_uuid.v4(), itemId, alias, now],
      );
    }
    await _exec('DELETE FROM item_barcodes WHERE item_id = ?', <Object?>[itemId]);
    for (final String barcode in barcodes) {
      await _exec(
        'INSERT INTO item_barcodes (id, item_id, barcode, created_at) '
        'VALUES (?, ?, ?, ?)',
        <Object?>[_uuid.v4(), itemId, barcode, now],
      );
    }
  }

  // ---------------------------------------------------------------------
  // Cursors
  // ---------------------------------------------------------------------

  Future<int> cursor(String key) async {
    final List<Map<String, Object?>> rows = await _query(
      'SELECT last_millis FROM sync_cursors WHERE collection = ?',
      <Object?>[key],
    );
    return rows.isEmpty ? 0 : (rows.first['last_millis'] as num).toInt();
  }

  /// Moves the cursor forward (never back).
  Future<void> advanceCursor(String key, int millis) async {
    await _exec(
      'INSERT INTO sync_cursors (collection, last_millis) VALUES (?, ?) '
      'ON CONFLICT(collection) DO UPDATE SET '
      'last_millis = MAX(last_millis, excluded.last_millis)',
      <Object?>[key, millis],
    );
  }

  Future<void> resetCursors() async {
    await _exec('DELETE FROM sync_cursors');
  }

  // ---------------------------------------------------------------------
  // Household members (cache)
  // ---------------------------------------------------------------------

  Future<void> replaceMembers(List<Member> members) async {
    await _db.transaction<void>(() async {
      await _exec('DELETE FROM household_members');
      for (final Member member in members) {
        await _exec(
          'INSERT INTO household_members (user_id, display_name, role) '
          'VALUES (?, ?, ?)',
          <Object?>[member.userId, member.displayName, member.role.name],
        );
      }
      _notify(<String>['household_members']);
    });
  }

  Stream<List<Member>> watchMembers() {
    return _db
        .customSelect(
          'SELECT user_id, display_name, role FROM household_members '
          'ORDER BY role DESC, display_name',
          readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
            _db.householdMembers,
          },
        )
        .watch()
        .map(
          (List<QueryRow> rows) => <Member>[
            for (final QueryRow row in rows)
              Member(
                userId: row.data['user_id'] as String,
                displayName: row.data['display_name'] as String,
                role: MemberRole.parse(row.data['role'] as String?),
              ),
          ],
        );
  }

  /// User id to display name.
  Future<Map<String, String>> memberNames() async {
    final List<Map<String, Object?>> rows =
        await _query('SELECT user_id, display_name FROM household_members');
    return <String, String>{
      for (final Map<String, Object?> r in rows)
        r['user_id'] as String: r['display_name'] as String,
    };
  }

  /// The name of a shopping list, or null.
  Future<String?> listName(String listId) async {
    final List<Map<String, Object?>> rows = await _query(
      'SELECT name FROM shopping_lists WHERE id = ?',
      <Object?>[listId],
    );
    return rows.isEmpty ? null : rows.first['name'] as String?;
  }

  // ---------------------------------------------------------------------
  // Status and housekeeping
  // ---------------------------------------------------------------------

  static const String _pendingSql = 'SELECT ('
      "(SELECT COUNT(*) FROM categories WHERE sync_status = 'pending') + "
      "(SELECT COUNT(*) FROM items WHERE sync_status = 'pending') + "
      "(SELECT COUNT(*) FROM stock_batches WHERE sync_status = 'pending') + "
      "(SELECT COUNT(*) FROM consumption_logs WHERE sync_status = 'pending') + "
      "(SELECT COUNT(*) FROM shopping_lists WHERE sync_status = 'pending') + "
      "(SELECT COUNT(*) FROM shopping_entries WHERE sync_status = 'pending')"
      ') AS c';

  /// How many rows are waiting to be sent. Emits again on every change.
  Stream<int> watchPendingCount() {
    return _db
        .customSelect(
          _pendingSql,
          readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
            _db.categories,
            _db.items,
            _db.stockBatches,
            _db.consumptionLogs,
            _db.shoppingLists,
            _db.shoppingEntries,
          },
        )
        .watch()
        .map((List<QueryRow> rows) => (rows.first.data['c'] as num).toInt());
  }

  Future<int> pendingCount() async {
    final List<Map<String, Object?>> rows = await _query(_pendingSql);
    return (rows.first['c'] as num).toInt();
  }

  /// Whether the pantry or any shopping list holds something.
  Future<bool> hasLocalData() async {
    final List<Map<String, Object?>> rows = await _query(
      'SELECT ((SELECT COUNT(*) FROM items WHERE is_deleted = 0) + '
      '(SELECT COUNT(*) FROM shopping_entries WHERE is_deleted = 0)) AS c',
    );
    return (rows.first['c'] as num).toInt() > 0;
  }

  /// Removes the pantry and shopping data from this phone (categories and the
  /// default list stay). Nothing is sent to the cloud.
  Future<void> clearLocalData() async {
    await _suppressed(
      <String>[
        'items',
        'item_aliases',
        'item_barcodes',
        'stock_batches',
        'consumption_logs',
        'shopping_lists',
        'shopping_entries',
        'sync_batch_bases',
        'sync_cursors',
      ],
      () async {
        await _exec('DELETE FROM consumption_logs');
        await _exec('DELETE FROM stock_batches');
        await _exec('DELETE FROM item_aliases');
        await _exec('DELETE FROM item_barcodes');
        await _exec('DELETE FROM shopping_entries');
        await _exec('DELETE FROM items');
        await _exec('DELETE FROM sync_batch_bases');
        await _exec(
          'DELETE FROM shopping_lists WHERE id <> ?',
          <Object?>[kDefaultListId],
        );
        await _exec('DELETE FROM sync_cursors');
      },
    );
  }

  /// Removes soft-deleted rows that were last changed before [beforeMillis]
  /// and are already in the cloud. Returns how many rows went.
  Future<int> purgeLocalDeleted(int beforeMillis) async {
    int removed = 0;
    await _suppressed(
      <String>[
        for (final SyncTableSpec s in SyncSchema.tables) s.table,
        'item_aliases',
        'item_barcodes',
        'sync_batch_bases',
      ],
      () async {
        for (final SyncTableSpec spec in SyncSchema.tables) {
          final List<Map<String, Object?>> due = await _query(
            'SELECT COUNT(*) AS c FROM ${spec.table} '
            'WHERE is_deleted = 1 AND sync_status = \'synced\' AND updated_at < ?',
            <Object?>[beforeMillis],
          );
          removed += (due.first['c'] as num).toInt();
          await _exec(
            'DELETE FROM ${spec.table} '
            'WHERE is_deleted = 1 AND sync_status = \'synced\' AND updated_at < ?',
            <Object?>[beforeMillis],
          );
        }
        await _exec(
          'DELETE FROM item_aliases WHERE item_id NOT IN (SELECT id FROM items)',
        );
        await _exec(
          'DELETE FROM item_barcodes WHERE item_id NOT IN (SELECT id FROM items)',
        );
        await _exec(
          'DELETE FROM sync_batch_bases '
          'WHERE batch_id NOT IN (SELECT id FROM stock_batches)',
        );
      },
    );
    return removed;
  }
}
