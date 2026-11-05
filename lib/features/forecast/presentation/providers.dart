import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/clock.dart';
import '../../insights/presentation/providers.dart';
import '../../pantry/domain/entities.dart';
import '../../pantry/domain/stock_logic.dart';
import '../../pantry/presentation/providers.dart';
import '../../settings/presentation/providers.dart';
import '../../shopping/domain/shopping_entities.dart';
import '../../shopping/presentation/providers.dart';
import '../domain/consumption_forecast.dart';
import '../domain/purchase_history.dart';
import '../domain/repeat_learning.dart';
import '../domain/what_to_buy.dart';

/// Forecast of every stocked item, keyed by item id. Worked out on the phone
/// from the use log; nothing is stored.
final Provider<Map<String, ItemForecast>> forecastsProvider =
    Provider<Map<String, ItemForecast>>((Ref ref) {
  final List<ItemWithBatches> records =
      ref.watch(itemsStreamProvider).value ?? const <ItemWithBatches>[];
  final List<ConsumptionEntry> logs =
      ref.watch(allHistoryProvider).value ?? const <ConsumptionEntry>[];
  final DateTime today = ref.watch(todayProvider);
  return ConsumptionForecast.forAll(records, logs, today);
});

/// One item's forecast, or null. A row that watches this rebuilds only when
/// its own forecast changes.
final forecastProvider = Provider.family<ItemForecast?, String>(
  (Ref ref, String itemId) {
    return ref.watch(
      forecastsProvider.select((Map<String, ItemForecast> m) => m[itemId]),
    );
  },
);

/// Batches Count mode created for stock found on the shelf: not purchases.
final Provider<Set<String>> adjustmentBatchIdsProvider =
    Provider<Set<String>>((Ref ref) {
  final List<ConsumptionEntry> logs =
      ref.watch(allHistoryProvider).value ?? const <ConsumptionEntry>[];
  return PurchaseHistory.adjustmentBatchIds(logs);
});

/// What to buy for a given horizon (days), soonest to run out first. Items
/// already on a shopping list are left out.
final buyRecommendationsProvider =
    Provider.family<List<BuyRecommendation>, int>((Ref ref, int horizonDays) {
  final List<ItemStock> stocks =
      ref.watch(pantryStocksProvider).value ?? const <ItemStock>[];
  final List<ShoppingEntry> entries =
      ref.watch(shoppingEntriesProvider).value ?? const <ShoppingEntry>[];
  return WhatToBuy.compute(
    stocks: stocks,
    forecasts: ref.watch(forecastsProvider),
    entries: entries,
    horizonDays: horizonDays,
    excludedBatchIds: ref.watch(adjustmentBatchIdsProvider),
  );
});

/// The horizon the "What should I buy?" screen is showing, in days.
final NotifierProvider<BuyHorizonNotifier, int> buyHorizonProvider =
    NotifierProvider<BuyHorizonNotifier, int>(BuyHorizonNotifier.new);

class BuyHorizonNotifier extends Notifier<int> {
  @override
  int build() => WhatToBuy.defaultHorizonDays;

  void choose(int days) => state = days;
}

/// The stored text of the dismissed schedule suggestions. Watching only this
/// setting means other settings writes (usage counters) do not rebuild
/// anything that depends on it.
final Provider<String?> _dismissedSchedulesRawProvider =
    Provider<String?>((Ref ref) {
  return ref.watch(
    settingsMapProvider.select(
      (AsyncValue<Map<String, String>> v) =>
          v.value?[ScheduleDismissals.settingKey],
    ),
  );
});

/// Schedule changes suggested for repeating shopping entries.
final Provider<List<ScheduleSuggestion>> scheduleSuggestionsProvider =
    Provider<List<ScheduleSuggestion>>((Ref ref) {
  final List<ShoppingEntry> entries =
      ref.watch(shoppingEntriesProvider).value ?? const <ShoppingEntry>[];
  final List<ItemWithBatches> records =
      ref.watch(itemsStreamProvider).value ?? const <ItemWithBatches>[];
  final String? raw = ref.watch(_dismissedSchedulesRawProvider);
  return RepeatLearning.compute(
    entries: <ShoppingEntry>[
      for (final ShoppingEntry e in entries)
        if (e.recurrence.repeats) e,
    ],
    records: records,
    excludedBatchIds: ref.watch(adjustmentBatchIdsProvider),
    dismissed: ScheduleDismissals.parse(raw),
  );
});
