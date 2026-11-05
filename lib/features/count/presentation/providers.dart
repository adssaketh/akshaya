import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/clock.dart';
import '../../../core/util/date_only.dart';
import '../../pantry/domain/entities.dart';
import '../../pantry/domain/stock_count.dart';
import '../../pantry/presentation/providers.dart';
import '../../settings/presentation/providers.dart';
import '../domain/count_session.dart';
import '../domain/count_settings.dart';

/// The monthly reminder settings and the date of the last finished count.
/// Equal values do not notify, so usage counters written to the same settings
/// table never rebuild anything that watches this.
final Provider<CountSettings> countSettingsProvider =
    Provider<CountSettings>((Ref ref) {
  final Map<String, String> stored =
      ref.watch(settingsMapProvider).value ?? const <String, String>{};
  return CountSettings.fromMap(stored);
});

/// The count that was left half-way, read from the saved settings, or null.
final Provider<CountSession?> savedCountProvider =
    Provider<CountSession?>((Ref ref) {
  final Map<String, String> stored =
      ref.watch(settingsMapProvider).value ?? const <String, String>{};
  return CountSession.decode(stored[CountSettingKeys.session]);
});

/// The count being worked through right now (null when none is open).
final NotifierProvider<CountSessionNotifier, CountSession?>
    countSessionProvider =
    NotifierProvider<CountSessionNotifier, CountSession?>(
  CountSessionNotifier.new,
);

class CountSessionNotifier extends Notifier<CountSession?> {
  @override
  CountSession? build() => null;

  /// Begins a new count of [scope], forgetting any saved one.
  void start(CountScope scope) {
    state = CountSession(scope: scope, startedOn: ref.read(todayProvider));
    _save();
  }

  /// Carries on with a saved count.
  void resume(CountSession session) {
    state = session;
  }

  /// Remembers the answer for one item.
  void record(CountOutcome outcome) {
    final CountSession? current = state;
    if (current == null) {
      return;
    }
    state = current.withOutcome(outcome);
    _save();
  }

  /// Puts an item off until later in this count.
  void skip(String itemId) {
    final CountSession? current = state;
    if (current == null) {
      return;
    }
    state = current.withSkipped(itemId);
    _save();
  }

  /// Takes an item back into the queue (Undo).
  void undo(String itemId) {
    final CountSession? current = state;
    if (current == null) {
      return;
    }
    state = current.without(itemId);
    _save();
  }

  /// Brings every skipped item back into the queue.
  void reviewSkipped() {
    final CountSession? current = state;
    if (current == null) {
      return;
    }
    state = CountSession(
      scope: current.scope,
      startedOn: current.startedOn,
      outcomes: current.outcomes,
    );
    _save();
  }

  /// Marks the count finished: records today as the last count and forgets
  /// the saved progress. The session stays open for the summary screen until
  /// [close].
  Future<void> finish() async {
    try {
      final repo = ref.read(settingsRepositoryProvider);
      await repo.writeAll(<String, String>{
        CountSettingKeys.lastCompletedOn: formatIsoDate(ref.read(todayProvider)),
      });
      await repo.remove(CountSettingKeys.session);
    } on Object catch (error) {
      debugPrint('Could not save the count: $error');
    }
  }

  /// Throws away a saved count.
  Future<void> discard() async {
    state = null;
    try {
      await ref.read(settingsRepositoryProvider).remove(CountSettingKeys.session);
    } on Object catch (error) {
      debugPrint('Could not discard the count: $error');
    }
  }

  /// Closes the summary.
  void close() {
    state = null;
  }

  void _save() {
    final CountSession? current = state;
    if (current == null) {
      return;
    }
    // Progress is a convenience: a failure here must never block counting.
    unawaited(
      ref
          .read(settingsRepositoryProvider)
          .writeAll(<String, String>{
            CountSettingKeys.session: current.encode(),
          })
          .catchError((Object error) {
        debugPrint('Could not save count progress: $error');
      }),
    );
  }
}

/// Everything the current count covers, by name (answered items included).
final Provider<AsyncValue<List<CountLine>>> countLinesProvider =
    Provider<AsyncValue<List<CountLine>>>((Ref ref) {
  final CountSession? session = ref.watch(countSessionProvider);
  final AsyncValue<List<ItemWithBatches>> items =
      ref.watch(itemsStreamProvider);
  if (session == null) {
    return const AsyncValue<List<CountLine>>.data(<CountLine>[]);
  }
  return items.whenData(
    (List<ItemWithBatches> records) =>
        CountPlanner.lines(records, session.scope),
  );
});

/// Lines that still need an answer: not answered and not put off.
final Provider<AsyncValue<List<CountLine>>> countQueueProvider =
    Provider<AsyncValue<List<CountLine>>>((Ref ref) {
  final CountSession? session = ref.watch(countSessionProvider);
  final AsyncValue<List<CountLine>> lines = ref.watch(countLinesProvider);
  return lines.whenData(
    (List<CountLine> all) => <CountLine>[
      for (final CountLine l in all)
        if (session == null || !session.isDone(l.item.id)) l,
    ],
  );
});
