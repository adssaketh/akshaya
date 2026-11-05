import '../../../core/util/date_only.dart';
import '../../pantry/domain/entities.dart';
import '../../pantry/domain/stock_logic.dart';
import '../../rescue/domain/food_rescue.dart';
import '../../rescue/domain/freeze_rules.dart';
import 'trip_models.dart';

/// What to do with food that would go off while the household is away.
enum TravelAdvice {
  /// Use it before leaving: cook it or eat it.
  cookNow('Cook it now'),

  /// Move it to the freezer.
  freeze('Freeze it'),

  /// Pass it on to a neighbour or friend.
  giveAway('Give it away');

  const TravelAdvice(this.label);

  final String label;
}

/// One batch that will expire before the trip ends.
final class TravelRisk {
  const TravelRisk({
    required this.entry,
    required this.advice,
    required this.expiresOn,
    required this.beforeLeaving,
  });

  /// The batch, shaped like a Food rescue entry so Freeze and the other
  /// actions can be reused as they are.
  final RescueEntry entry;

  /// The suggestion to show first.
  final TravelAdvice advice;

  /// The batch's effective expiry.
  final DateTime expiresOn;

  /// True when it goes off on or before the leaving day.
  final bool beforeLeaving;

  Item get item => entry.item;

  StockBatch get batch => entry.batch;

  bool get canFreeze => entry.canFreeze;

  /// "Goes off 6 Nov, before you leave" or "Goes off 7 Nov, while you are
  /// away".
  String get reason {
    final String when = formatDateShort(expiresOn);
    return beforeLeaving
        ? 'Goes off $when, before you leave'
        : 'Goes off $when, while you are away';
  }

  /// "Fridge · 2 kg left".
  String get subtitle => entry.subtitle;
}

/// Finds the food that will not last until the household is back. Pure Dart.
abstract final class TravelPlanner {
  /// Every batch that still holds stock, has a date on or after [today] and
  /// expires before [Trip.end], soonest first.
  ///
  /// Food that is already expired is left out (it cannot be saved; Food
  /// rescue shows it) and so is food with no date.
  static List<TravelRisk> build({
    required Trip trip,
    required List<ItemStock> stocks,
    required DateTime today,
    required FreezeSettings freeze,
  }) {
    final DateTime day = dateOnly(today);
    final List<TravelRisk> out = <TravelRisk>[];
    for (final ItemStock stock in stocks) {
      for (final StockBatch batch in stock.inStock) {
        final DateTime? expiry = batch.effectiveExpiry;
        if (expiry == null) {
          continue;
        }
        final DateTime expires = dateOnly(expiry);
        if (expires.isBefore(day) || !expires.isBefore(trip.end)) {
          continue;
        }
        final int daysLeft = daysBetween(day, expires);
        final DateTime? openedOn = batch.openedDate;
        final bool canFreeze = Freezer.canFreeze(
          item: stock.item,
          batch: batch,
          settings: freeze,
          today: day,
        );
        final bool beforeLeaving = !expires.isAfter(trip.start);
        out.add(
          TravelRisk(
            entry: RescueEntry(
              stock: stock,
              batch: batch,
              group: daysLeft == 0 ? RescueGroup.today : RescueGroup.soon,
              daysLeft: daysLeft,
              openedDaysAgo:
                  openedOn == null ? null : daysBetween(openedOn, day),
              canFreeze: canFreeze,
            ),
            advice: adviceFor(
              trip: trip,
              today: day,
              expires: expires,
              canFreeze: canFreeze,
            ),
            expiresOn: expires,
            beforeLeaving: beforeLeaving,
          ),
        );
      }
    }
    out.sort((TravelRisk a, TravelRisk b) {
      final int byDate = a.expiresOn.compareTo(b.expiresOn);
      if (byDate != 0) {
        return byDate;
      }
      return a.item.name.toLowerCase().compareTo(b.item.name.toLowerCase());
    });
    return out;
  }

  /// The first suggestion for a batch that goes off on [expires].
  ///
  /// Still at home and it goes off before (or on) the leaving day: use it
  /// first. Otherwise freeze it when the category allows, else pass it on.
  static TravelAdvice adviceFor({
    required Trip trip,
    required DateTime today,
    required DateTime expires,
    required bool canFreeze,
  }) {
    final bool stillHome = dateOnly(today).isBefore(trip.start);
    if (stillHome && !expires.isAfter(trip.start)) {
      return TravelAdvice.cookNow;
    }
    return canFreeze ? TravelAdvice.freeze : TravelAdvice.giveAway;
  }
}
