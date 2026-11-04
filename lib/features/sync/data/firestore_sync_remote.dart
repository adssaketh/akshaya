import 'package:cloud_firestore/cloud_firestore.dart';

import '../../ai/data/firebase_runtime.dart';
import '../domain/sync_merge.dart';
import '../domain/sync_remote.dart';
import 'firebase_errors.dart';

/// [SyncRemote] on Cloud Firestore (Spark plan).
///
/// Documents live at `households/{householdId}/{collection}/{id}` and carry a
/// server-stamped `syncedAt`, which is what "changed since last time" queries
/// use. Pushes are transactions, so a push needs a connection and fails
/// cleanly when there is none (the app's own queue retries it).
class FirestoreSyncRemote implements SyncRemote {
  FirestoreSyncRemote(this._runtime);

  final FirebaseRuntime _runtime;

  static const Duration _timeout = Duration(seconds: 20);

  /// Documents per transaction: well under Firestore's limit of 500 writes.
  static const int _chunk = 20;

  Future<FirebaseFirestore> _firestore() async {
    await _runtime.ensureReady();
    return FirebaseFirestore.instance;
  }

  CollectionReference<Map<String, dynamic>> _collection(
    FirebaseFirestore firestore,
    String householdId,
    String collection,
  ) {
    return firestore
        .collection('households')
        .doc(householdId)
        .collection(collection);
  }

  static Map<String, Object?> _plain(Map<String, dynamic> data) {
    final Map<String, Object?> out = <String, Object?>{};
    data.forEach((String key, dynamic value) {
      if (key == 'syncedAt') {
        return;
      }
      out[key] = value is Timestamp ? value.millisecondsSinceEpoch : value;
    });
    return out;
  }

  static int? _syncedAt(Map<String, dynamic> data) {
    final dynamic value = data['syncedAt'];
    return value is Timestamp ? value.millisecondsSinceEpoch : null;
  }

  @override
  Stream<List<RemoteDoc>> watch(
    String householdId,
    String collection,
    int sinceMillis,
  ) async* {
    try {
      final FirebaseFirestore firestore = await _firestore();
      final Query<Map<String, dynamic>> query =
          _collection(firestore, householdId, collection)
              .where(
                'syncedAt',
                isGreaterThan: Timestamp.fromMillisecondsSinceEpoch(sinceMillis),
              )
              .orderBy('syncedAt');
      await for (final QuerySnapshot<Map<String, dynamic>> snapshot
          in query.snapshots()) {
        final List<RemoteDoc> docs = <RemoteDoc>[];
        for (final DocumentChange<Map<String, dynamic>> change
            in snapshot.docChanges) {
          if (change.type == DocumentChangeType.removed) {
            continue;
          }
          final DocumentSnapshot<Map<String, dynamic>> doc = change.doc;
          // A document this phone is still writing has no server time yet.
          if (doc.metadata.hasPendingWrites) {
            continue;
          }
          final Map<String, dynamic>? data = doc.data();
          final int? syncedAt = data == null ? null : _syncedAt(data);
          if (data == null || syncedAt == null) {
            continue;
          }
          docs.add(
            RemoteDoc(id: doc.id, data: _plain(data), syncedAtMillis: syncedAt),
          );
        }
        if (docs.isNotEmpty) {
          yield docs;
        }
      }
    } on Object catch (error) {
      throw mapSyncError(error);
    }
  }

  @override
  Future<List<RemoteDoc>> fetchSince(
    String householdId,
    String collection,
    int sinceMillis, {
    int limit = 300,
  }) async {
    try {
      final FirebaseFirestore firestore = await _firestore();
      final QuerySnapshot<Map<String, dynamic>> snapshot =
          await _collection(firestore, householdId, collection)
              .where(
                'syncedAt',
                isGreaterThan: Timestamp.fromMillisecondsSinceEpoch(sinceMillis),
              )
              .orderBy('syncedAt')
              .limit(limit)
              .get(const GetOptions(source: Source.server))
              .timeout(_timeout);
      final List<RemoteDoc> docs = <RemoteDoc>[];
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
          in snapshot.docs) {
        final Map<String, dynamic> data = doc.data();
        final int? syncedAt = _syncedAt(data);
        if (syncedAt == null) {
          continue;
        }
        docs.add(
          RemoteDoc(id: doc.id, data: _plain(data), syncedAtMillis: syncedAt),
        );
      }
      return docs;
    } on Object catch (error) {
      throw mapSyncError(error);
    }
  }

  @override
  Future<List<PushOutcome>> push(
    String householdId,
    String collection,
    List<PushDoc> docs, {
    required bool isBatch,
  }) async {
    final List<PushOutcome> outcomes = <PushOutcome>[];
    try {
      final FirebaseFirestore firestore = await _firestore();
      final CollectionReference<Map<String, dynamic>> ref =
          _collection(firestore, householdId, collection);
      for (int start = 0; start < docs.length; start += _chunk) {
        final List<PushDoc> chunk = docs.sublist(
          start,
          start + _chunk > docs.length ? docs.length : start + _chunk,
        );
        final List<PushOutcome> done =
            await firestore.runTransaction<List<PushOutcome>>(
          (Transaction transaction) async {
            // Reads first, then writes, as Firestore requires.
            final List<DocumentSnapshot<Map<String, dynamic>>> snapshots =
                <DocumentSnapshot<Map<String, dynamic>>>[];
            for (final PushDoc doc in chunk) {
              snapshots.add(await transaction.get(ref.doc(doc.id)));
            }
            final List<PushOutcome> results = <PushOutcome>[];
            for (int i = 0; i < chunk.length; i++) {
              final PushDoc doc = chunk[i];
              final DocumentSnapshot<Map<String, dynamic>> snapshot =
                  snapshots[i];
              final Map<String, dynamic>? data = snapshot.data();
              final PushDecision decision = SyncMerge.decidePush(
                local: doc.fields,
                remote: snapshot.exists && data != null ? _plain(data) : null,
                isBatch: isBatch,
                delta: doc.delta,
              );
              final Map<String, Object?>? write = decision.write;
              if (write != null) {
                transaction.set(ref.doc(doc.id), <String, dynamic>{
                  ...write,
                  'syncedAt': FieldValue.serverTimestamp(),
                });
              }
              results.add(
                PushOutcome(
                  id: doc.id,
                  result: decision.result,
                  written: write != null,
                ),
              );
            }
            return results;
          },
          timeout: _timeout,
          maxAttempts: 3,
        );
        outcomes.addAll(done);
      }
      return outcomes;
    } on Object catch (error) {
      throw mapSyncError(error);
    }
  }

  @override
  Future<int> purgeDeleted(
    String householdId,
    String collection,
    int olderThanMillis,
  ) async {
    try {
      final FirebaseFirestore firestore = await _firestore();
      final QuerySnapshot<Map<String, dynamic>> snapshot =
          await _collection(firestore, householdId, collection)
              .where('isDeleted', isEqualTo: true)
              .where('updatedAt', isLessThan: olderThanMillis)
              .limit(200)
              .get(const GetOptions(source: Source.server))
              .timeout(_timeout);
      if (snapshot.docs.isEmpty) {
        return 0;
      }
      final WriteBatch batch = firestore.batch();
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
          in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit().timeout(_timeout);
      return snapshot.docs.length;
    } on Object catch (error) {
      throw mapSyncError(error);
    }
  }
}
