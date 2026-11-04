import 'package:akshaya/features/sync/domain/sync_merge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('mergeQuantity', () {
    test('adds this phone\'s change to the cloud amount', () {
      // Both phones started at 5; the cloud says 4 (someone used 1); this
      // phone used 2 (now 3). Together they used 3, leaving 2.
      expect(
        SyncMerge.mergeQuantity(remote: 4, local: 3, base: 5),
        2,
      );
    });

    test('never goes below zero', () {
      expect(SyncMerge.mergeQuantity(remote: 1, local: 0, base: 5), 0);
    });

    test('without a base the phone is assumed to have changed nothing', () {
      expect(SyncMerge.mergeQuantity(remote: 4, local: 9, base: null), 4);
    });

    test('rounds to three decimals', () {
      expect(
        SyncMerge.mergeQuantity(remote: 1, local: 0.1 + 0.2, base: 0),
        1.3,
      );
    });
  });

  group('keepLocal', () {
    test('keeps a pending edit that is as new as the incoming one', () {
      expect(
        SyncMerge.keepLocal(
          localPending: true,
          localUpdatedAt: 10,
          remoteUpdatedAt: 10,
        ),
        isTrue,
      );
    });

    test('takes the incoming document when it is newer or nothing is pending',
        () {
      expect(
        SyncMerge.keepLocal(
          localPending: true,
          localUpdatedAt: 9,
          remoteUpdatedAt: 10,
        ),
        isFalse,
      );
      expect(
        SyncMerge.keepLocal(
          localPending: false,
          localUpdatedAt: 99,
          remoteUpdatedAt: 10,
        ),
        isFalse,
      );
    });
  });

  group('decidePush', () {
    Map<String, Object?> doc(int updatedAt, {double remaining = 3}) =>
        <String, Object?>{
          'id': 'b1',
          'updatedAt': updatedAt,
          'updatedBy': 'me',
          'quantityRemaining': remaining,
          'name': 'local',
        };

    test('writes a document that is not in the cloud yet', () {
      final PushDecision d = SyncMerge.decidePush(
        local: doc(5),
        remote: null,
        isBatch: false,
        delta: 0,
      );
      expect(d.write, isNotNull);
    });

    test('last write wins for ordinary documents', () {
      final Map<String, Object?> newerRemote = <String, Object?>{
        ...doc(9),
        'name': 'remote',
      };
      final PushDecision lost = SyncMerge.decidePush(
        local: doc(5),
        remote: newerRemote,
        isBatch: false,
        delta: 0,
      );
      expect(lost.write, isNull);
      expect(lost.result['name'], 'remote');

      final PushDecision won = SyncMerge.decidePush(
        local: doc(9),
        remote: doc(9),
        isBatch: false,
        delta: 0,
      );
      expect(won.write?['name'], 'local');
    });

    test('a batch keeps both people\'s use of the stock', () {
      // Cloud: 4 (someone used 1). This phone used 2 since it last synced.
      final PushDecision d = SyncMerge.decidePush(
        local: doc(9, remaining: 3),
        remote: doc(5, remaining: 4),
        isBatch: true,
        delta: -2,
      );
      expect(d.write?['quantityRemaining'], 2);
    });

    test('a newer cloud batch only receives this phone\'s use', () {
      final Map<String, Object?> remote = <String, Object?>{
        ...doc(20, remaining: 4),
        'name': 'remote',
        'updatedBy': 'other',
      };
      final PushDecision d = SyncMerge.decidePush(
        local: doc(5, remaining: 3),
        remote: remote,
        isBatch: true,
        delta: -1,
      );
      expect(d.write?['quantityRemaining'], 3);
      expect(d.write?['name'], 'remote');
      expect(d.write?['updatedBy'], 'me');
    });

    test('a newer cloud batch with no change here writes nothing', () {
      final PushDecision d = SyncMerge.decidePush(
        local: doc(5),
        remote: doc(20, remaining: 4),
        isBatch: true,
        delta: 0,
      );
      expect(d.write, isNull);
    });
  });

  test('retryDelay grows and stops at 15 minutes', () {
    expect(SyncMerge.retryDelay(1), const Duration(seconds: 30));
    expect(SyncMerge.retryDelay(2), const Duration(minutes: 1));
    expect(SyncMerge.retryDelay(3), const Duration(minutes: 2));
    expect(SyncMerge.retryDelay(50), const Duration(minutes: 15));
  });

  test('isPurgeable needs more than 30 days', () {
    const int day = Duration.millisecondsPerDay;
    expect(
      SyncMerge.isPurgeable(updatedAtMillis: 0, nowMillis: 30 * day),
      isFalse,
    );
    expect(
      SyncMerge.isPurgeable(updatedAtMillis: 0, nowMillis: 30 * day + 1),
      isTrue,
    );
  });
}
