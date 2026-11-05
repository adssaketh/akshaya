import 'package:akshaya/core/design/design.dart' show StatusKind;

import '../../pantry/domain/entities.dart';
import '../../pantry/domain/stock_logic.dart';
import '../../shopping/domain/shopping_entities.dart';
import '../../shopping/domain/shopping_suggestions.dart';
import 'alert_settings.dart';
import 'alert_snoozes.dart';

/// What the daily alert is about on one calendar day. Pure data: the same
/// rules as the Pantry statuses and the Shopping suggestions, so the alert
/// never disagrees with what the person sees in the app.
final class AlertDigest {
  const AlertDigest({
    required this.expired,
    required this.expiringToday,
    required this.expiringSoon,
    required this.lowStock,
    required this.warningDays,
  });

  /// Stock past its date, most overdue first.
  final List<ItemStock> expired;

  /// Stock whose date is the day itself.
  final List<ItemStock> expiringToday;

  /// Stock expiring from tomorrow up to [warningDays] days ahead, soonest
  /// first.
  final List<ItemStock> expiringSoon;

  /// Items that ran out or are at or below their low-stock level and are not
  /// on a shopping list yet.
  final List<ShoppingSuggestion> lowStock;

  final int warningDays;

  bool get isEmpty =>
      expired.isEmpty &&
      expiringToday.isEmpty &&
      expiringSoon.isEmpty &&
      lowStock.isEmpty;
}

abstract final class AlertDigestBuilder {
  /// Works out the digest for [today].
  ///
  /// Items with several batches count once, by their nearest expiry (the same
  /// way the Pantry list shows them). Low stock leaves out items that are
  /// already on a shopping list, and items whose stock is all past its date
  /// (those are in [AlertDigest.expired]).
  ///
  /// Items in [snoozes] are left out of every list. The settings can switch
  /// off the expired, expiring and low-stock parts one by one.
  static AlertDigest build({
    required List<ItemWithBatches> items,
    required List<ShoppingEntry> entries,
    required DateTime today,
    required AlertSettings settings,
    AlertSnoozes snoozes = const AlertSnoozes(),
  }) {
    final List<ItemStock> stocks = <ItemStock>[
      for (final ItemWithBatches record in items)
        StockLogic.summarize(
          record,
          today: today,
          warningDays: settings.warningDays,
        ),
    ];

    final List<ItemStock> expired = <ItemStock>[];
    final List<ItemStock> expiringToday = <ItemStock>[];
    final List<ItemStock> expiringSoon = <ItemStock>[];
    for (final ItemStock stock in stocks) {
      if (snoozes.hides(stock.item.id, today)) {
        continue;
      }
      switch (stock.status) {
        case StatusKind.expired:
          expired.add(stock);
        case StatusKind.expiring:
          if (_days(stock) <= 0) {
            expiringToday.add(stock);
          } else {
            expiringSoon.add(stock);
          }
        case StatusKind.fresh:
        case StatusKind.lowStock:
        case StatusKind.outOfStock:
          break;
      }
    }
    expired.sort(_byDaysThenName);
    expiringToday.sort(_byDaysThenName);
    expiringSoon.sort(_byDaysThenName);

    final List<ShoppingSuggestion> lowStock = settings.lowStock
        ? <ShoppingSuggestion>[
            for (final ShoppingSuggestion s in ShoppingSuggestions.compute(
              stocks: stocks,
              entries: entries,
              today: today,
            ))
              if (s.reason != SuggestionReason.expired &&
                  !snoozes.hides(s.item.id, today))
                s,
          ]
        : const <ShoppingSuggestion>[];

    return AlertDigest(
      expired: settings.expired ? expired : const <ItemStock>[],
      expiringToday: settings.expiring ? expiringToday : const <ItemStock>[],
      expiringSoon: settings.expiring ? expiringSoon : const <ItemStock>[],
      lowStock: lowStock,
      warningDays: settings.warningDays,
    );
  }

  static int _days(ItemStock stock) => stock.daysToExpiry ?? 0;

  static int _byDaysThenName(ItemStock a, ItemStock b) {
    final int byDays = _days(a).compareTo(_days(b));
    if (byDays != 0) {
      return byDays;
    }
    return a.item.name.toLowerCase().compareTo(b.item.name.toLowerCase());
  }
}
