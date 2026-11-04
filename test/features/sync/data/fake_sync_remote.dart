import 'dart:async';

import 'package:akshaya/features/sync/domain/sync_merge.dart';
import 'package:akshaya/features/sync/domain/sync_models.dart';
import 'package:akshaya/features/sync/domain/sync_remote.dart';

/// An in-memory stand-in for Firestore. Documents are stored per collection
/// with a growing fake `syncedAt`.
class FakeSyncRemote implements SyncRemote {
  final Map<String, Map<String, Map<String, Object?>>> docs =
      <String, Map<String, Map<String, Object?>>>{};
  final Map<String, Map<String, int>> stamps = <String, Map<String, int>>{};
  int _clock = 1000;

  /// When set, every call throws it.
  SyncException? failure;

  int pushCalls = 0;
  int fetchCalls = 0;
  final List<String> purged = <String>[];

  int get now => _clock;

  /// Stores [data] as if another phone had written it.
  /// With [at] the document is stamped with that time (epoch milliseconds).
  void put(String collection, Map<String, Object?> data, {int? at}) {
    final String id = data['id']! as String;
    docs.putIfAbsent(collection, () => <String, Map<String, Object?>>{})[id] =
        Map<String, Object?>.of(data);
    stamps.putIfAbsent(collection, () => <String, int>{})[id] = at ?? ++_clock;
  }

  Map<String, Object?>? get(String collection, String id) =>
      docs[collection]?[id];

  int count(String collection) => docs[collection]?.length ?? 0;

  @override
  Stream<List<RemoteDoc>> watch(
    String householdId,
    String collection,
    int sinceMillis,
  ) =>
      const Stream<List<RemoteDoc>>.empty();

  @override
  Future<List<RemoteDoc>> fetchSince(
    String householdId,
    String collection,
    int sinceMillis, {
    int limit = 300,
  }) async {
    fetchCalls++;
    final SyncException? error = failure;
    if (error != null) {
      throw error;
    }
    final List<RemoteDoc> out = <RemoteDoc>[];
    final Map<String, Map<String, Object?>> all =
        docs[collection] ?? <String, Map<String, Object?>>{};
    for (final MapEntry<String, Map<String, Object?>> e in all.entries) {
      final int stamp = stamps[collection]![e.key]!;
      if (stamp > sinceMillis) {
        out.add(
          RemoteDoc(
            id: e.key,
            data: Map<String, Object?>.of(e.value),
            syncedAtMillis: stamp,
          ),
        );
      }
    }
    out.sort((RemoteDoc a, RemoteDoc b) =>
        a.syncedAtMillis.compareTo(b.syncedAtMillis));
    return out.take(limit).toList();
  }

  @override
  Future<List<PushOutcome>> push(
    String householdId,
    String collection,
    List<PushDoc> pushDocs, {
    required bool isBatch,
  }) async {
    pushCalls++;
    final SyncException? error = failure;
    if (error != null) {
      throw error;
    }
    final List<PushOutcome> outcomes = <PushOutcome>[];
    for (final PushDoc doc in pushDocs) {
      final Map<String, Object?>? current = get(collection, doc.id);
      final PushDecision decision = SyncMerge.decidePush(
        local: doc.fields,
        remote: current,
        isBatch: isBatch,
        delta: doc.delta,
      );
      final Map<String, Object?>? write = decision.write;
      if (write != null) {
        put(collection, write);
      }
      outcomes.add(
        PushOutcome(
          id: doc.id,
          result: decision.result,
          written: write != null,
        ),
      );
    }
    return outcomes;
  }

  @override
  Future<int> purgeDeleted(
    String householdId,
    String collection,
    int olderThanMillis,
  ) async {
    purged.add(collection);
    return 0;
  }
}
