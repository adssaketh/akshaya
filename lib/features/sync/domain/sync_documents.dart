import 'sync_schema.dart';

/// Turns database rows into Firestore documents and back.
///
/// Rows are handled as raw column maps (column name -> SQLite value), so dates
/// stay `yyyy-MM-dd` text, instants stay epoch milliseconds and enums stay
/// their stored text: the document holds exactly what the database holds.
abstract final class SyncDocuments {
  /// A Firestore document for [row]. Booleans become `bool`, the household id
  /// is the one the document is stored under and `updatedBy` is the person
  /// uploading it (every change in the local database was made on this phone).
  ///
  /// The server adds `syncedAt`; it is not part of the returned map.
  static Map<String, Object?> toRemote(
    SyncTableSpec spec,
    Map<String, Object?> row, {
    required String householdId,
    required String userId,
    List<String> aliases = const <String>[],
    List<String> barcodes = const <String>[],
  }) {
    final Map<String, Object?> doc = <String, Object?>{};
    for (final SyncColumn column in spec.columns) {
      doc[column.field] = _toRemoteValue(column.kind, row[column.sql]);
    }
    doc['householdId'] = householdId;
    doc['updatedBy'] = userId;
    if (spec.isItem) {
      doc['aliases'] = aliases;
      doc['barcodes'] = barcodes;
    }
    return doc;
  }

  /// A column map for [doc], ready to store. Throws a [FormatException] when a
  /// required field is missing or has the wrong type, so one bad document is
  /// skipped instead of breaking the whole sync.
  static Map<String, Object?> toLocal(
    SyncTableSpec spec,
    Map<String, Object?> doc,
  ) {
    final Map<String, Object?> row = <String, Object?>{};
    for (final SyncColumn column in spec.columns) {
      final Object? value = doc[column.field];
      if (value == null) {
        if (column.required) {
          throw FormatException('Missing ${column.field} in ${spec.collection}');
        }
        row[column.sql] = null;
        continue;
      }
      row[column.sql] = _toLocalValue(column, value);
    }
    return row;
  }

  /// The alias list of an item document (empty when absent or malformed).
  static List<String> aliasesOf(Map<String, Object?> doc) =>
      _stringList(doc['aliases']);

  /// The barcode list of an item document.
  static List<String> barcodesOf(Map<String, Object?> doc) =>
      _stringList(doc['barcodes']);

  static List<String> _stringList(Object? value) {
    if (value is! List) {
      return const <String>[];
    }
    return <String>[
      for (final Object? v in value)
        if (v is String && v.trim().isNotEmpty) v.trim(),
    ];
  }

  static Object? _toRemoteValue(SyncColumnKind kind, Object? raw) {
    if (raw == null) {
      return null;
    }
    switch (kind) {
      case SyncColumnKind.text:
        return raw.toString();
      case SyncColumnKind.integer:
        return raw is num ? raw.toInt() : int.parse(raw.toString());
      case SyncColumnKind.real:
        return raw is num ? raw.toDouble() : double.parse(raw.toString());
      case SyncColumnKind.boolean:
        if (raw is bool) {
          return raw;
        }
        if (raw is num) {
          return raw != 0;
        }
        final String text = raw.toString().toLowerCase();
        return text == '1' || text == 'true';
    }
  }

  static Object? _toLocalValue(SyncColumn column, Object value) {
    switch (column.kind) {
      case SyncColumnKind.text:
        if (value is! String) {
          throw FormatException('${column.field} must be text');
        }
        return value;
      case SyncColumnKind.integer:
        if (value is! num) {
          throw FormatException('${column.field} must be a number');
        }
        return value.toInt();
      case SyncColumnKind.real:
        if (value is! num) {
          throw FormatException('${column.field} must be a number');
        }
        return value.toDouble();
      case SyncColumnKind.boolean:
        if (value is! bool) {
          throw FormatException('${column.field} must be true or false');
        }
        return value ? 1 : 0;
    }
  }
}
