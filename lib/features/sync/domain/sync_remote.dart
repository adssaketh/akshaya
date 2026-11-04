/// A document as it arrives from the cloud.
final class RemoteDoc {
  const RemoteDoc({
    required this.id,
    required this.data,
    required this.syncedAtMillis,
  });

  final String id;

  /// Fields as plain values (numbers, text, booleans, lists). `syncedAt` is
  /// not in here; see [syncedAtMillis].
  final Map<String, Object?> data;

  /// When the server stored this version, in epoch milliseconds. Drives the
  /// "only what changed since last time" queries.
  final int syncedAtMillis;
}

/// A document to send.
final class PushDoc {
  const PushDoc({
    required this.id,
    required this.fields,
    this.delta = 0,
  });

  final String id;

  /// The document made by `SyncDocuments.toRemote`.
  final Map<String, Object?> fields;

  /// For stock batches: how much the remaining quantity changed on this phone
  /// since the last sync.
  final double delta;
}

/// What happened to one pushed document.
final class PushOutcome {
  const PushOutcome({
    required this.id,
    required this.result,
    required this.written,
  });

  final String id;

  /// The document as it is in the cloud after the push (no `syncedAt`).
  final Map<String, Object?> result;

  /// False when the cloud copy was newer and nothing was written.
  final bool written;
}

/// Everything the sync engine needs from the cloud. The real implementation
/// uses Cloud Firestore; tests use a fake.
///
/// Methods throw `SyncException` for connection, quota and permission
/// problems.
abstract interface class SyncRemote {
  /// Documents of [collection] stored after [sinceMillis], now and whenever
  /// they change. Each event lists only the documents that are new or
  /// changed, never ones this phone is still writing.
  Stream<List<RemoteDoc>> watch(
    String householdId,
    String collection,
    int sinceMillis,
  );

  /// One page of documents stored after [sinceMillis], oldest first.
  Future<List<RemoteDoc>> fetchSince(
    String householdId,
    String collection,
    int sinceMillis, {
    int limit = 300,
  });

  /// Writes [docs] (a few at a time, each compared with the cloud copy).
  Future<List<PushOutcome>> push(
    String householdId,
    String collection,
    List<PushDoc> docs, {
    required bool isBatch,
  });

  /// Deletes soft-deleted documents last changed before [olderThanMillis].
  /// Returns how many were removed.
  Future<int> purgeDeleted(
    String householdId,
    String collection,
    int olderThanMillis,
  );
}
