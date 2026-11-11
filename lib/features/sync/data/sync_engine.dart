import 'dart:async';
import 'dart:math' as math;


import '../../../core/diagnostics/diag.dart';
import '../domain/change_digest.dart';
import '../domain/sync_merge.dart';
import '../domain/sync_models.dart';
import '../domain/sync_remote.dart';
import '../domain/sync_schema.dart';
import 'sync_store.dart';

/// Reports Firestore documents read and written, for the usage estimate.
typedef SyncUsageSink = void Function({int reads, int writes});

/// Called with changes other household members made.
typedef SyncChangeListener = void Function(List<RemoteChange> changes);

/// Keeps the local database and the household's Firestore documents in step.
///
/// - Local edits (rows marked `pending` by the database triggers) are pushed
///   in small transactions; each document is compared with the cloud copy
///   (last write wins), and a batch's remaining quantity is merged by
///   difference.
/// - What others change arrives through one query per collection that asks
///   only for documents stored after the last one received, as a live
///   listener while the app is open and as a one-off fetch in [syncNow].
/// - Quota, offline and permission problems never lose data: rows stay
///   pending and the push is retried with a growing delay.
class SyncEngine {
  SyncEngine({
    required this.store,
    required this.remote,
    DateTime Function()? clock,
    this.onChanges,
    this.onUsage,
    this.onDenied,
  }) : _clock = clock ?? DateTime.now;

  final SyncStore store;
  final SyncRemote remote;
  final DateTime Function() _clock;
  final SyncChangeListener? onChanges;
  final SyncUsageSink? onUsage;

  /// Called when the cloud refuses this account (usually: removed from the
  /// household).
  final Future<void> Function()? onDenied;

  static const int _pageSize = 300;

  String? _householdId;
  String? _userId;
  bool _listening = false;
  final List<StreamSubscription<List<RemoteDoc>>> _subscriptions =
      <StreamSubscription<List<RemoteDoc>>>[];
  Future<void> _applyQueue = Future<void>.value();
  bool _busy = false;
  bool _runAgain = false;
  int _failures = 0;

  /// Collections the published security rules refuse for this account (for
  /// example one added by a newer app version whose rules were not deployed).
  /// They are skipped so the rest keeps syncing; cleared on each [syncNow].
  final Set<String> _refused = <String>{};
  Timer? _retry;
  bool _disposed = false;

  SyncStatusInfo _info = const SyncStatusInfo();
  final StreamController<SyncStatusInfo> _statusController =
      StreamController<SyncStatusInfo>.broadcast();

  /// The current state of the sync indicator.
  SyncStatusInfo get status => _info;

  /// Emits whenever [status] changes.
  Stream<SyncStatusInfo> get statusStream => _statusController.stream;

  bool get isAttached => _householdId != null;

  // ---------------------------------------------------------------------
  // Attaching
  // ---------------------------------------------------------------------

  /// Starts syncing [householdId] as [userId]. Does nothing when already
  /// attached to the same pair. With [resetCursors] everything in the
  /// household is downloaded again (use it when the household changes).
  Future<void> attach({
    required String householdId,
    required String userId,
    bool resetCursors = false,
  }) async {
    if (_householdId == householdId && _userId == userId && !resetCursors) {
      return;
    }
    await _stopListening();
    _householdId = householdId;
    _userId = userId;
    _failures = 0;
    if (resetCursors) {
      await store.resetCursors();
      // Documents that are already in the household are not "news".
      await store.advanceCursor(
        SyncStore.alertKey,
        _clock().millisecondsSinceEpoch,
      );
    }
    await store.assignHousehold(householdId);
    _setPhase(SyncPhase.idle);
    await startListening();
    unawaited(syncNow());
  }

  /// Stops syncing (sign-out, household left, sync switched off). Local data
  /// is not touched.
  Future<void> detach() async {
    _retry?.cancel();
    await _stopListening();
    _householdId = null;
    _userId = null;
    _failures = 0;
    _setInfo(SyncStatusInfo(lastSyncedAt: _info.lastSyncedAt));
  }

  /// Marks the account as no longer part of the household.
  Future<void> markRemoved() async {
    _retry?.cancel();
    await _stopListening();
    _householdId = null;
    _userId = null;
    _setInfo(
      const SyncStatusInfo(
        phase: SyncPhase.removed,
        message: 'You are no longer a member of this household.',
      ),
    );
  }

  /// Stops the live listeners (the app went to the background). Pushing still
  /// works through [syncNow].
  Future<void> pauseListening() => _stopListening();

  /// Starts the live listeners again and catches up.
  Future<void> resumeListening() async {
    if (_householdId == null) {
      return;
    }
    await startListening();
    unawaited(syncNow());
  }

  Future<void> dispose() async {
    _disposed = true;
    _retry?.cancel();
    await _stopListening();
    await _statusController.close();
  }

  // ---------------------------------------------------------------------
  // Listening
  // ---------------------------------------------------------------------

  /// One live query per collection, each starting after the newest document
  /// already received. Idle while there is no connection.
  Future<void> startListening() async {
    final String? household = _householdId;
    if (household == null || _listening) {
      return;
    }
    _listening = true;
    for (final SyncTableSpec spec in SyncSchema.tables) {
      if (_refused.contains(spec.collection)) {
        continue;
      }
      final int since = await store.cursor(spec.collection);
      if (!_listening || _householdId != household) {
        return;
      }
      _subscriptions.add(
        remote.watch(household, spec.collection, since).listen(
              (List<RemoteDoc> docs) => unawaited(_enqueue(spec, docs)),
              onError: (Object error, StackTrace stack) =>
                  unawaited(_onListenError(error, spec.collection)),
            ),
      );
    }
  }

  Future<void> _stopListening() async {
    _listening = false;
    final List<StreamSubscription<List<RemoteDoc>>> subs =
        List<StreamSubscription<List<RemoteDoc>>>.of(_subscriptions);
    _subscriptions.clear();
    for (final StreamSubscription<List<RemoteDoc>> sub in subs) {
      await sub.cancel();
    }
  }

  Future<void> _onListenError(Object error, String collection) async {
    if (error is SyncException && error.kind == SyncErrorKind.denied) {
      // One refused collection must not stop the others; syncNow decides
      // whether the whole account is refused.
      _refused.add(collection);
      if (_refused.length >= SyncSchema.tables.length) {
        await _handleDenied();
      }
    } else if (error is SyncException && error.kind == SyncErrorKind.quota) {
      _setPhase(SyncPhase.quotaReached, message: error.message);
    }
    // Other listener errors (a dropped connection) are retried by Firestore.
  }

  Future<void> _handleDenied() async {
    final Future<void> Function()? callback = onDenied;
    if (callback != null) {
      await callback();
    } else {
      _setPhase(
        SyncPhase.error,
        message: 'The server refused the sync. Sign in again.',
      );
    }
  }

  // ---------------------------------------------------------------------
  // Receiving
  // ---------------------------------------------------------------------

  Future<void> _enqueue(SyncTableSpec spec, List<RemoteDoc> docs) {
    final Future<void> next =
        _applyQueue.then<void>((_) => _applyDocs(spec, docs)).catchError(
      (Object error, StackTrace stack) {
        Diag.error('sync', 'Applying synced documents failed', error: error, stack: stack);
      },
    );
    _applyQueue = next;
    return next;
  }

  Future<void> _applyDocs(SyncTableSpec spec, List<RemoteDoc> docs) async {
    if (docs.isEmpty) {
      return;
    }
    final String? uid = _userId;
    final int alerted = await store.cursor(SyncStore.alertKey);
    final List<ApplyOutcome> outcomes = await store.applyRemote(spec, docs);

    int newest = 0;
    for (final RemoteDoc doc in docs) {
      newest = math.max(newest, doc.syncedAtMillis);
    }
    await store.advanceCursor(spec.collection, newest);
    onUsage?.call(reads: docs.length, writes: 0);

    final SyncChangeListener? listener = onChanges;
    final bool alertable =
        spec.collection == 'entries' || spec.collection == 'batches';
    if (listener != null && uid != null && alertable && alerted > 0) {
      final Map<String, RemoteDoc> byId = <String, RemoteDoc>{
        for (final RemoteDoc doc in docs) doc.id: doc,
      };
      final List<RemoteChange> changes = <RemoteChange>[];
      for (final ApplyOutcome outcome in outcomes) {
        final RemoteDoc? doc = byId[outcome.id];
        final String? author = outcome.updatedBy;
        if (doc == null || author == null || author == uid) {
          continue;
        }
        if (doc.syncedAtMillis <= alerted) {
          continue;
        }
        if (!outcome.inserted && !outcome.removed) {
          continue;
        }
        final String? listId = outcome.listId;
        changes.add(
          RemoteChange(
            collection: spec.collection,
            userId: author,
            removed: outcome.removed,
            listName: listId == null ? null : await store.listName(listId),
          ),
        );
      }
      if (changes.isNotEmpty) {
        listener(changes);
      }
    }
    await store.advanceCursor(SyncStore.alertKey, newest);
  }

  // ---------------------------------------------------------------------
  // Syncing
  // ---------------------------------------------------------------------

  /// Sends every pending edit, then fetches whatever changed in the cloud.
  /// Safe to call at any time; a call while a sync is running schedules one
  /// more pass when it ends.
  Future<void> syncNow() async {
    final String? household = _householdId;
    final String? user = _userId;
    if (household == null || user == null || _disposed) {
      return;
    }
    if (_busy) {
      _runAgain = true;
      return;
    }
    _busy = true;
    _retry?.cancel();
    _setPhase(SyncPhase.syncing);
    bool ok = false;
    _refused.clear();
    try {
      await store.assignHousehold(household);
      await _pushAll(household, user);
      await _pullAll(household);
      await _purgeIfDue(household);
      _failures = 0;
      ok = true;
      if (_refused.length >= SyncSchema.tables.length) {
        // Every collection refused: the account is no longer a member.
        await _onFailure(
          const SyncException(
            SyncErrorKind.denied,
            'The server refused the sync. You may have been removed from the '
            'household.',
          ),
        );
        return;
      }
      _setInfo(
        SyncStatusInfo(
          phase: SyncPhase.synced,
          lastSyncedAt: _clock(),
          pending: await store.pendingCount(),
          message: refusedCollectionsMessage(_refused),
        ),
      );
    } on SyncException catch (error) {
      await _onFailure(error);
    } on Object catch (error, stack) {
      Diag.error('sync', 'Sync failed', error: error, stack: stack);
      await _onFailure(
        const SyncException(
          SyncErrorKind.other,
          'Sync did not finish. It will try again.',
        ),
      );
    } finally {
      _busy = false;
    }
    if (ok && _runAgain && _householdId != null) {
      _runAgain = false;
      unawaited(syncNow());
    } else {
      _runAgain = false;
    }
  }

  Future<void> _pushAll(String household, String user) async {
    for (final SyncTableSpec spec in SyncSchema.tables) {
      if (_refused.contains(spec.collection)) {
        continue;
      }
      for (int pass = 0; pass < 50; pass++) {
        final List<PendingRow> rows =
            await store.pendingRows(spec, household, limit: 100);
        if (rows.isEmpty) {
          break;
        }
        final List<PushDoc> docs = <PushDoc>[
          for (final PendingRow row in rows)
            store.toPushDoc(row, household, user),
        ];
        final List<PushOutcome> outcomes;
        try {
          outcomes = await remote.push(
            household,
            spec.collection,
            docs,
            isBatch: spec.isBatch,
          );
        } on SyncException catch (error) {
          if (error.kind != SyncErrorKind.denied) {
            rethrow;
          }
          _refused.add(spec.collection);
          break;
        }
        final Map<String, PushOutcome> byId = <String, PushOutcome>{
          for (final PushOutcome outcome in outcomes) outcome.id: outcome,
        };
        onUsage?.call(
          reads: docs.length,
          writes: outcomes.where((PushOutcome o) => o.written).length,
        );
        int completed = 0;
        for (final PendingRow row in rows) {
          final PushOutcome? outcome = byId[row.id];
          if (outcome == null) {
            continue;
          }
          await store.completePush(row, outcome.result);
          completed++;
        }
        if (completed == 0) {
          break;
        }
      }
    }
  }

  Future<void> _pullAll(String household) async {
    for (final SyncTableSpec spec in SyncSchema.tables) {
      if (_refused.contains(spec.collection)) {
        continue;
      }
      for (int page = 0; page < 100; page++) {
        final int since = await store.cursor(spec.collection);
        final List<RemoteDoc> docs;
        try {
          docs = await remote.fetchSince(
            household,
            spec.collection,
            since,
            limit: _pageSize,
          );
        } on SyncException catch (error) {
          if (error.kind != SyncErrorKind.denied) {
            rethrow;
          }
          _refused.add(spec.collection);
          break;
        }
        if (docs.isEmpty) {
          break;
        }
        await _enqueue(spec, docs);
        int newest = 0;
        for (final RemoteDoc doc in docs) {
          newest = math.max(newest, doc.syncedAtMillis);
        }
        if (docs.length < _pageSize || newest <= since) {
          break;
        }
      }
    }
  }

  /// Once a day: removes documents deleted more than 30 days ago from the
  /// cloud and from this phone.
  Future<void> _purgeIfDue(String household) async {
    final int now = _clock().millisecondsSinceEpoch;
    final int last = await store.cursor(SyncStore.purgeKey);
    if (now - last < Duration.millisecondsPerDay) {
      return;
    }
    final int cutoff = now - 30 * Duration.millisecondsPerDay;
    try {
      for (final SyncTableSpec spec in SyncSchema.tables) {
        if (_refused.contains(spec.collection)) {
          continue;
        }
        final int removed =
            await remote.purgeDeleted(household, spec.collection, cutoff);
        onUsage?.call(reads: removed, writes: removed);
      }
      await store.purgeLocalDeleted(cutoff);
      await store.advanceCursor(SyncStore.purgeKey, now);
    } on SyncException catch (error, stack) {
      // Tidying up is not worth failing a sync over; it runs again later.
      Diag.warn('sync', 'Purge skipped', error: error, stack: stack);
    }
  }

  Future<void> _onFailure(SyncException error) async {
    _failures++;
    final int pending = await store.pendingCount();
    switch (error.kind) {
      case SyncErrorKind.offline:
        _setInfo(
          _info.copyWith(
            phase: SyncPhase.offline,
            message: error.message,
            pending: pending,
          ),
        );
      case SyncErrorKind.quota:
        _setInfo(
          _info.copyWith(
            phase: SyncPhase.quotaReached,
            message: error.message,
            pending: pending,
          ),
        );
      case SyncErrorKind.denied:
        _setInfo(
          _info.copyWith(
            phase: SyncPhase.error,
            message: error.message,
            pending: pending,
          ),
        );
        await _handleDenied();
        return;
      case SyncErrorKind.signedOut:
      case SyncErrorKind.other:
        _setInfo(
          _info.copyWith(
            phase: SyncPhase.error,
            message: error.message,
            pending: pending,
          ),
        );
    }
    if (_householdId == null || _disposed) {
      return;
    }
    final Duration delay = error.kind == SyncErrorKind.quota
        ? const Duration(hours: 1)
        : SyncMerge.retryDelay(_failures);
    _retry?.cancel();
    _retry = Timer(delay, () => unawaited(syncNow()));
  }

  // ---------------------------------------------------------------------
  // Status
  // ---------------------------------------------------------------------

  void _setInfo(SyncStatusInfo info) {
    if (info.phase != _info.phase) {
      final String? why = info.message;
      Diag.info(
        'sync',
        'Status ${_info.phase.name} -> ${info.phase.name} '
            '(${info.pending} pending)${why == null ? '' : ': $why'}',
      );
    }
    _info = info;
    if (!_statusController.isClosed) {
      _statusController.add(info);
    }
  }

  void _setPhase(SyncPhase phase, {String? message}) {
    _setInfo(
      _info.copyWith(
        phase: phase,
        message: message,
        clearMessage: message == null,
      ),
    );
  }
}

/// Plain-English note for collections the cloud rules refuse, or null when
/// none were. Shown next to the sync status.
String? refusedCollectionsMessage(Set<String> refused) {
  if (refused.isEmpty) {
    return null;
  }
  const Map<String, String> names = <String, String>{
    'categories': 'categories',
    'items': 'items',
    'batches': 'stock batches',
    'shoppingLists': 'shopping lists',
    'entries': 'shopping entries',
    'logs': 'usage history',
    'recipes': 'saved recipes',
    'mealPlan': 'meal plan',
    'trips': 'trips',
    'takeaways': 'takeaway meals',
  };
  final List<String> labels = <String>[
    for (final String c in refused) names[c] ?? c,
  ]..sort();
  return 'Not syncing: ${labels.join(', ')}. Publish the latest '
      'firestore.rules to fix this.';
}
