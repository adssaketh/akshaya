import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/clock.dart';
import '../../pantry/domain/stock_logic.dart';
import '../../pantry/presentation/providers.dart';
import '../../settings/presentation/providers.dart';
import '../domain/food_rescue.dart';
import '../domain/freeze_rules.dart';

/// The person's own freezing days (the built-in rules until they load).
final Provider<FreezeSettings> freezeSettingsProvider =
    Provider<FreezeSettings>((Ref ref) {
  final Map<String, String> stored =
      ref.watch(settingsMapProvider).value ?? const <String, String>{};
  return FreezeSettings.fromMap(stored);
});

/// Everything worth acting on today: expired, expiring, leftovers and opened
/// packs. Empty until the pantry has loaded.
final Provider<List<RescueEntry>> foodRescueProvider =
    Provider<List<RescueEntry>>((Ref ref) {
  final List<ItemStock> stocks =
      ref.watch(pantryStocksProvider).value ?? const <ItemStock>[];
  return FoodRescue.build(
    stocks: stocks,
    today: ref.watch(todayProvider),
    warningDays: ref.watch(expiryWarningDaysProvider),
    freeze: ref.watch(freezeSettingsProvider),
  );
});
