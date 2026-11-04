/// What a push should write, and what the document looks like afterwards.
final class PushDecision {
  const PushDecision({required this.write, required this.result});

  /// Fields to store (the server adds `syncedAt`), or null when the cloud copy
  /// is already right and nothing has to be written.
  final Map<String, Object?>? write;

  /// The document as it is in the cloud after this push.
  final Map<String, Object?> result;
}

/// Conflict rules, as pure functions.
///
/// - Every document: last write wins, by `updatedAt` (milliseconds). A tie goes
///   to the phone that is pushing.
/// - A stock batch's remaining quantity is merged by *difference*: what this
///   phone used since it last synced is added to whatever the cloud holds
///   now, so two people using the same stock at the same time both count.
abstract final class SyncMerge {
  /// Quantities are kept to three decimals, like the database.
  static double roundQuantity(double value) =>
      (value * 1000).roundToDouble() / 1000;

  /// A pending local row is kept over an incoming document when the local edit
  /// is at least as new.
  static bool keepLocal({
    required bool localPending,
    required int localUpdatedAt,
    required int remoteUpdatedAt,
  }) {
    return localPending && localUpdatedAt >= remoteUpdatedAt;
  }

  /// The remaining quantity after merging: the cloud's amount plus what this
  /// phone changed since the cloud amount was last known ([base]). When the
  /// base is unknown the phone is assumed to have changed nothing. Never
  /// below zero.
  static double mergeQuantity({
    required double remote,
    required double local,
    required double? base,
  }) {
    final double difference = base == null ? 0 : local - base;
    final double merged = roundQuantity(remote + difference);
    return merged < 0 ? 0 : merged;
  }

  /// Decides a push of [local] (a document made by `SyncDocuments.toRemote`)
  /// against the document currently in the cloud ([remote], null when there is
  /// none). [delta] is the change in a batch's remaining quantity since the
  /// last sync; pass 0 for every other kind of document.
  static PushDecision decidePush({
    required Map<String, Object?> local,
    required Map<String, Object?>? remote,
    required bool isBatch,
    required double delta,
  }) {
    if (remote == null) {
      return PushDecision(write: local, result: local);
    }

    final int localUpdated = _asInt(local['updatedAt']);
    final int remoteUpdated = _asInt(remote['updatedAt']);
    final bool localWins = localUpdated >= remoteUpdated;

    if (!isBatch) {
      return localWins
          ? PushDecision(write: local, result: local)
          : PushDecision(write: null, result: remote);
    }

    final double remoteQuantity = _asDouble(remote['quantityRemaining']);
    final double merged = mergeQuantity(
      remote: remoteQuantity,
      local: remoteQuantity + delta,
      base: remoteQuantity,
    );

    if (localWins) {
      final Map<String, Object?> doc = <String, Object?>{
        ...local,
        'quantityRemaining': merged,
      };
      return PushDecision(write: doc, result: doc);
    }

    // The cloud copy is newer, so its other fields win; only this phone's use
    // of the stock is added to it.
    if (delta == 0) {
      return PushDecision(write: null, result: remote);
    }
    final Map<String, Object?> doc = <String, Object?>{
      ...remote,
      'quantityRemaining': merged,
      'updatedBy': local['updatedBy'],
    };
    doc.remove('syncedAt');
    return PushDecision(write: doc, result: doc);
  }

  /// Seconds to wait before the next attempt after [failures] failures in a
  /// row: 30 s, 1 min, 2 min, ... never more than 15 minutes.
  static Duration retryDelay(int failures) {
    final int step = failures < 1 ? 0 : failures - 1;
    final int seconds = 30 * (1 << (step > 5 ? 5 : step));
    return Duration(seconds: seconds > 900 ? 900 : seconds);
  }

  /// Whether a soft-deleted document last changed at [updatedAtMillis] is old
  /// enough to be removed for good.
  static bool isPurgeable({
    required int updatedAtMillis,
    required int nowMillis,
    int retainDays = 30,
  }) {
    return nowMillis - updatedAtMillis > retainDays * Duration.millisecondsPerDay;
  }

  static int _asInt(Object? value) => value is num ? value.toInt() : 0;

  static double _asDouble(Object? value) =>
      value is num ? value.toDouble() : 0;
}
