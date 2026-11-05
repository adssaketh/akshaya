import 'dart:convert';

import 'package:drift/drift.dart';

import '../../pantry/data/database/app_database.dart';
import '../../pantry/domain/failures.dart';

/// What an import changed.
final class ImportSummary {
  const ImportSummary({
    required this.added,
    required this.updated,
    required this.skipped,
  });

  final int added;
  final int updated;

  /// Rows the file had but the phone already had in a newer version.
  final int skipped;

  int get total => added + updated;
}

/// Full-backup export and merge-import over the local database.
///
/// The file is JSON: `{format, version, exportedAt, tables: {name: [row]}}`
/// where each row maps SQL column names to their stored values. Local-only
/// columns (`sync_status`, `household_id`) are left out. Settings, the
/// product cache, the recipe cache and sync bookkeeping are not backed up.
///
/// Import merges by id: a row is added when new, replaced when the file's
/// `updated_at` is newer, and left alone otherwise. Everything runs in one
/// transaction, so a bad file changes nothing.
class BackupService {
  BackupService(this._db, {DateTime Function()? now})
      : _now = now ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _now;

  static const String formatName = 'akshaya-backup';
  static const int formatVersion = 1;

  /// Tables in the order rows must be inserted (parents first).
  static const List<String> tables = <String>[
    'categories',
    'items',
    'item_aliases',
    'item_barcodes',
    'shopping_lists',
    'stock_batches',
    'consumption_logs',
    'shopping_entries',
    'saved_recipes',
    'meal_plan_entries',
  ];

  static const Set<String> _localOnly = <String>{'sync_status', 'household_id'};

  /// Largest file accepted, in bytes.
  static const int maxBytes = 50 * 1024 * 1024;

  /// Table name -> its column names, read from the schema.
  Future<Map<String, List<String>>> _columns() async {
    final Map<String, List<String>> out = <String, List<String>>{};
    for (final String table in tables) {
      final List<QueryRow> info =
          await _db.customSelect('PRAGMA table_info($table)').get();
      out[table] = <String>[
        for (final QueryRow r in info) r.read<String>('name'),
      ];
    }
    return out;
  }

  /// The whole backup as a JSON-encodable map.
  Future<Map<String, Object?>> exportData() async {
    final Map<String, List<String>> columns = await _columns();
    final Map<String, Object?> data = <String, Object?>{};
    for (final String table in tables) {
      final List<String> keep = <String>[
        for (final String c in columns[table]!)
          if (!_localOnly.contains(c)) c,
      ];
      final List<QueryRow> rows =
          await _db.customSelect('SELECT ${keep.join(', ')} FROM $table').get();
      data[table] = <Map<String, Object?>>[
        for (final QueryRow r in rows)
          <String, Object?>{for (final String c in keep) c: r.data[c]},
      ];
    }
    return <String, Object?>{
      'format': formatName,
      'version': formatVersion,
      'exportedAt': _now().toUtc().toIso8601String(),
      'tables': data,
    };
  }

  /// The backup as UTF-8 JSON bytes.
  Future<List<int>> exportBytes() async {
    return utf8.encode(
      const JsonEncoder.withIndent(' ').convert(await exportData()),
    );
  }

  /// Merges a backup file into the database.
  ///
  /// Throws [InvalidInputFailure] when the file is not a valid Akshaya backup;
  /// nothing is changed in that case.
  Future<ImportSummary> importBytes(List<int> bytes) async {
    if (bytes.length > maxBytes) {
      throw const InvalidInputFailure('That file is too large to be a backup.');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(bytes));
    } on FormatException {
      throw const InvalidInputFailure('That is not a valid backup file.');
    }
    return importData(decoded);
  }

  /// Merges already-decoded backup data. See [importBytes].
  Future<ImportSummary> importData(Object? decoded) async {
    if (decoded is! Map<String, Object?> ||
        decoded['format'] != formatName ||
        decoded['tables'] is! Map<String, Object?>) {
      throw const InvalidInputFailure('That is not an Akshaya backup file.');
    }
    final Object? version = decoded['version'];
    if (version is! int || version > formatVersion) {
      throw const InvalidInputFailure(
        'This backup was made by a newer version of Akshaya. Update the app first.',
      );
    }
    final Map<String, Object?> fileTables =
        decoded['tables']! as Map<String, Object?>;
    final Map<String, List<String>> columns = await _columns();

    // Validate the whole file before touching the database.
    final Map<String, List<Map<String, Object?>>> parsed =
        <String, List<Map<String, Object?>>>{};
    for (final String table in tables) {
      final Object? raw = fileTables[table];
      if (raw == null) {
        continue;
      }
      if (raw is! List<Object?>) {
        throw InvalidInputFailure('The "$table" section is not a list.');
      }
      final Set<String> allowed = <String>{
        for (final String c in columns[table]!)
          if (!_localOnly.contains(c)) c,
      };
      final List<Map<String, Object?>> rows = <Map<String, Object?>>[];
      for (final Object? row in raw) {
        if (row is! Map<String, Object?>) {
          throw InvalidInputFailure('A row in "$table" is not an object.');
        }
        final Object? id = row['id'];
        if (id is! String || id.isEmpty) {
          throw InvalidInputFailure('A row in "$table" has no id.');
        }
        final Map<String, Object?> clean = <String, Object?>{};
        for (final MapEntry<String, Object?> e in row.entries) {
          if (!allowed.contains(e.key)) {
            continue; // Unknown or local-only column: ignored.
          }
          final Object? v = e.value;
          if (v != null && v is! String && v is! num && v is! bool) {
            throw InvalidInputFailure(
              'A value in "$table.${e.key}" has an unsupported type.',
            );
          }
          clean[e.key] = v is bool ? (v ? 1 : 0) : v;
        }
        rows.add(clean);
      }
      parsed[table] = rows;
    }

    int added = 0;
    int updated = 0;
    int skipped = 0;
    try {
      await _db.transaction(() async {
        for (final String table in tables) {
          final List<Map<String, Object?>> rows =
              parsed[table] ?? const <Map<String, Object?>>[];
          final bool versioned = columns[table]!.contains('updated_at');
          for (final Map<String, Object?> row in rows) {
            final String id = row['id']! as String;
            final List<QueryRow> existing = await _db
                .customSelect(
                  'SELECT ${versioned ? 'updated_at' : 'id'} AS v '
                  'FROM $table WHERE id = ?',
                  variables: <Variable<Object>>[Variable<String>(id)],
                )
                .get();
            if (existing.isEmpty) {
              await _insert(table, row);
              added++;
              continue;
            }
            if (!versioned) {
              skipped++; // Aliases and barcodes never change once made.
              continue;
            }
            final int? have = existing.first.read<int?>('v');
            final Object? incoming = row['updated_at'];
            if (incoming is num && (have == null || incoming > have)) {
              await _update(table, row);
              updated++;
            } else {
              skipped++;
            }
          }
        }
      });
    } on InvalidInputFailure {
      rethrow;
    } on Object {
      throw const InvalidInputFailure(
        'The backup file is damaged or incomplete. Nothing was imported.',
      );
    }
    return ImportSummary(added: added, updated: updated, skipped: skipped);
  }

  Future<void> _insert(String table, Map<String, Object?> row) {
    final List<String> cols = row.keys.toList();
    return _db.customStatement(
      'INSERT INTO $table (${cols.join(', ')}) '
      'VALUES (${List<String>.filled(cols.length, '?').join(', ')})',
      <Object?>[for (final String c in cols) row[c]],
    );
  }

  Future<void> _update(String table, Map<String, Object?> row) {
    final List<String> cols = <String>[
      for (final String c in row.keys)
        if (c != 'id') c,
    ];
    return _db.customStatement(
      'UPDATE $table SET ${cols.map((String c) => '$c = ?').join(', ')} '
      'WHERE id = ?',
      <Object?>[for (final String c in cols) row[c], row['id']],
    );
  }
}
