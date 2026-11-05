import 'dart:math' as math;

import '../../../core/util/date_only.dart';
import '../../pantry/domain/entities.dart';
import '../../shopping/domain/shopping_entities.dart';

/// "You usually buy this every ~10 days, but it repeats every week."
final class ScheduleSuggestion {
  const ScheduleSuggestion({
    required this.entry,
    required this.learnedDays,
    required this.currentDays,
    required this.purchases,
  });

  /// The repeating shopping entry the suggestion is about.
  final ShoppingEntry entry;

  /// The interval the purchase history shows, in days.
  final int learnedDays;

  /// The interval the entry repeats at now, in days.
  final int currentDays;

  /// Different purchase days the interval was learned from.
  final int purchases;

  /// "every 10 days".
  String get learnedLabel {
    return learnedDays == 1 ? 'every day' : 'every $learnedDays days';
  }
}

/// Learns how often a repeating entry's item is really bought. Pure Dart.
abstract final class RepeatLearning {
  /// Purchase days needed before an interval is learned (two gaps).
  static const int minPurchases = 3;

  /// Only the latest purchases count, so a changed habit is picked up.
  static const int maxGaps = 5;

  /// Intervals outside this range are not suggested.
  static const int minLearnedDays = 2;
  static const int maxLearnedDays = 180;

  /// Every gap must be within this share of the typical gap, or the habit is
  /// too irregular to suggest a schedule for.
  static const double regularLow = 0.5;
  static const double regularHigh = 2;

  /// The typical number of days between purchases, or null when there are too
  /// few purchases, the gaps are irregular or the result is out of range.
  /// Several purchases on one day count once.
  static int? learnedInterval(List<DateTime> purchaseDates) {
    final List<DateTime> days = <DateTime>{
      for (final DateTime d in purchaseDates) dateOnly(d),
    }.toList()
      ..sort();
    if (days.length < minPurchases) {
      return null;
    }
    final List<DateTime> recent = days.length > maxGaps + 1
        ? days.sublist(days.length - (maxGaps + 1))
        : days;
    final List<int> gaps = <int>[
      for (int i = 1; i < recent.length; i++)
        daysBetween(recent[i - 1], recent[i]),
    ];
    final List<int> sorted = List<int>.of(gaps)..sort();
    final int mid = sorted.length ~/ 2;
    final double median = sorted.length.isOdd
        ? sorted[mid].toDouble()
        : (sorted[mid - 1] + sorted[mid]) / 2;
    if (median <= 0) {
      return null;
    }
    for (final int gap in gaps) {
      if (gap < median * regularLow || gap > median * regularHigh) {
        return null;
      }
    }
    final int learned = median.round();
    if (learned < minLearnedDays || learned > maxLearnedDays) {
      return null;
    }
    return learned;
  }

  /// How different the learned interval has to be from the schedule before it
  /// is worth mentioning: a quarter of the schedule, and at least two days.
  static int differenceNeeded(int currentDays) {
    return math.max(2, (currentDays * 0.25).round());
  }

  /// Suggestions for repeating [entries]. The item behind an entry is its
  /// linked item, or the pantry item with the same name. [dismissed] maps an
  /// entry id to the interval the person turned down; it stays hidden until
  /// the learned interval moves by more than two days.
  static List<ScheduleSuggestion> compute({
    required List<ShoppingEntry> entries,
    required List<ItemWithBatches> records,
    Set<String> excludedBatchIds = const <String>{},
    Map<String, int> dismissed = const <String, int>{},
  }) {
    final Map<String, ItemWithBatches> byId = <String, ItemWithBatches>{
      for (final ItemWithBatches r in records) r.item.id: r,
    };
    final Map<String, ItemWithBatches> byName = <String, ItemWithBatches>{
      for (final ItemWithBatches r in records) _key(r.item.name): r,
    };

    final List<ScheduleSuggestion> out = <ScheduleSuggestion>[];
    for (final ShoppingEntry entry in entries) {
      final int? current = entry.intervalDays;
      if (current == null) {
        continue;
      }
      final String? itemId = entry.itemId;
      final ItemWithBatches? record =
          (itemId == null ? null : byId[itemId]) ?? byName[_key(entry.name)];
      if (record == null) {
        continue;
      }
      final List<DateTime> dates = <DateTime>[
        for (final StockBatch b in record.batches)
          if (!excludedBatchIds.contains(b.id)) b.purchaseDate,
      ];
      final int? learned = learnedInterval(dates);
      if (learned == null) {
        continue;
      }
      if ((learned - current).abs() < differenceNeeded(current)) {
        continue;
      }
      final int? turnedDown = dismissed[entry.id];
      if (turnedDown != null && (turnedDown - learned).abs() <= 2) {
        continue;
      }
      out.add(
        ScheduleSuggestion(
          entry: entry,
          learnedDays: learned,
          currentDays: current,
          purchases: <DateTime>{
            for (final DateTime d in dates) dateOnly(d),
          }.length,
        ),
      );
    }
    out.sort(
      (ScheduleSuggestion a, ScheduleSuggestion b) =>
          a.entry.name.toLowerCase().compareTo(b.entry.name.toLowerCase()),
    );
    return out;
  }

  static String _key(String name) => name.trim().toLowerCase();
}

/// Where schedule suggestions the person turned down are remembered. They live
/// in the phone's own settings (never synced) as `entryId:days` pairs.
abstract final class ScheduleDismissals {
  static const String settingKey = 'forecast.dismissed_schedules';

  /// Only the latest dismissals are kept.
  static const int maxStored = 50;

  /// Reads the stored text (the value of [settingKey]); anything unreadable is
  /// skipped.
  static Map<String, int> parse(String? raw) {
    final Map<String, int> out = <String, int>{};
    if (raw == null || raw.isEmpty) {
      return out;
    }
    for (final String pair in raw.split(',')) {
      final List<String> parts = pair.split(':');
      if (parts.length != 2 || parts[0].isEmpty) {
        continue;
      }
      final int? days = int.tryParse(parts[1]);
      if (days != null) {
        out[parts[0]] = days;
      }
    }
    return out;
  }

  /// The settings text for [dismissed], with [entryId] added or updated.
  static String encodeWith(
    Map<String, int> dismissed,
    String entryId,
    int learnedDays,
  ) {
    final Map<String, int> next = <String, int>{...dismissed}
      ..remove(entryId)
      ..[entryId] = learnedDays;
    final List<MapEntry<String, int>> pairs = next.entries.toList();
    final List<MapEntry<String, int>> kept = pairs.length > maxStored
        ? pairs.sublist(pairs.length - maxStored)
        : pairs;
    return kept
        .map((MapEntry<String, int> e) => '${e.key}:${e.value}')
        .join(',');
  }
}
