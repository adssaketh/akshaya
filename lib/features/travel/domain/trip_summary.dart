import '../../../core/util/date_only.dart';
import '../../../core/util/quantity.dart';
import '../../pantry/domain/entities.dart';
import '../../shopping/domain/shopping_entities.dart';
import 'trip_models.dart';

/// What changed while the household was away. Pure Dart.
final class TripSummary {
  const TripSummary({
    required this.trip,
    required this.expiredItems,
    required this.repeatingBack,
  });

  final Trip trip;

  /// Names of items with stock that expired during the trip, sorted.
  final List<String> expiredItems;

  /// Repeating shopping items that are back on the list now.
  final int repeatingBack;

  bool get isQuiet => expiredItems.isEmpty && repeatingBack == 0;

  /// "Welcome back from Goa".
  String get title {
    final String name = trip.name.trim();
    return name.isEmpty ? 'Welcome back' : 'Welcome back from $name';
  }

  /// One line per thing that changed; a single line when nothing did.
  String get body {
    final List<String> lines = <String>[];
    final int expired = expiredItems.length;
    if (expired > 0) {
      lines.add(
        expired == 1
            ? '1 item expired while you were away'
            : '$expired items expired while you were away',
      );
    }
    if (repeatingBack > 0) {
      lines.add(
        repeatingBack == 1
            ? '1 repeating item is back on your list'
            : '$repeatingBack repeating items are back on your list',
      );
    }
    if (lines.isEmpty) {
      lines.add('Nothing expired while you were away.');
    }
    return lines.join('\n');
  }
}

/// Builds a [TripSummary]. Pure Dart.
abstract final class TripSummaryBuilder {
  /// The summary of [trip] from the pantry and lists as they are now.
  ///
  /// An item counts as expired during the trip when a batch with stock has an
  /// effective expiry from the leaving day up to the day before the return.
  /// Repeating entries count when they are not ticked and were due by the
  /// return day.
  static TripSummary build({
    required Trip trip,
    required List<ItemWithBatches> items,
    required List<ShoppingEntry> entries,
  }) {
    final Set<String> names = <String>{};
    for (final ItemWithBatches record in items) {
      for (final StockBatch batch in record.batches) {
        if (isZeroQty(batch.quantityRemaining)) {
          continue;
        }
        final DateTime? expiry = batch.effectiveExpiry;
        if (expiry == null) {
          continue;
        }
        final DateTime day = dateOnly(expiry);
        if (!day.isBefore(trip.start) && day.isBefore(trip.end)) {
          names.add(record.item.name);
          break;
        }
      }
    }
    int repeating = 0;
    for (final ShoppingEntry entry in entries) {
      if (entry.isChecked || !entry.recurrence.repeats) {
        continue;
      }
      final DateTime? due = entry.dueOn;
      if (due == null || !due.isAfter(trip.end)) {
        repeating++;
      }
    }
    final List<String> sorted = names.toList()
      ..sort((String a, String b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return TripSummary(
      trip: trip,
      expiredItems: sorted,
      repeatingBack: repeating,
    );
  }
}
