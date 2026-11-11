import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/clock.dart';
import '../../ai/domain/ai_failures.dart';
import '../../ai/presentation/providers.dart';
import '../../pantry/domain/entities.dart';
import '../../pantry/domain/stock_logic.dart';
import '../../pantry/presentation/providers.dart';
import '../../report/domain/nutrition_table.dart';
import '../../settings/presentation/providers.dart';
import '../data/drift_takeaway_repository.dart';
import '../data/firebase_estimate_backend.dart';
import '../domain/food_estimate.dart';
import '../domain/food_estimate_service.dart';
import '../domain/takeaway_models.dart';
import '../domain/takeaway_repository.dart';

final Provider<TakeawayRepository> takeawayRepositoryProvider =
    Provider<TakeawayRepository>((Ref ref) {
      return DriftTakeawayRepository(
        ref.watch(appDatabaseProvider),
        clock: ref.watch(clockProvider),
      );
    });

/// Every takeaway, newest day first.
final StreamProvider<List<TakeawayMeal>> takeawaysProvider =
    StreamProvider<List<TakeawayMeal>>((Ref ref) {
      return ref.watch(takeawayRepositoryProvider).watchAll();
    });

/// The estimates saved on this phone, by [estimateKey] of the food name. They
/// are kept in the local settings, so each dish is asked about once.
final Provider<Map<String, FoodEstimate>> foodEstimatesProvider =
    Provider<Map<String, FoodEstimate>>((Ref ref) {
      final Map<String, String> stored =
          ref.watch(settingsMapProvider).value ?? const <String, String>{};
      final Map<String, FoodEstimate> out = <String, FoodEstimate>{};
      stored.forEach((String key, String value) {
        if (!key.startsWith(kEstimateKeyPrefix)) {
          return;
        }
        final FoodEstimate? estimate = FoodEstimate.decode(value);
        if (estimate != null) {
          out[key.substring(kEstimateKeyPrefix.length)] = estimate;
        }
      });
      return out;
    });

final Provider<FoodEstimateBackend> foodEstimateBackendProvider =
    Provider<FoodEstimateBackend>((Ref ref) {
      return FirebaseEstimateBackend(ref.watch(firebaseRuntimeProvider));
    });

/// The food estimate service, or null while the AI gate loads.
final Provider<FoodEstimateService?> foodEstimateServiceProvider =
    Provider<FoodEstimateService?>((Ref ref) {
      final guard = ref.watch(aiCommandServiceProvider);
      if (guard == null) {
        return null;
      }
      return FoodEstimateService(
        guard: guard,
        backend: ref.watch(foodEstimateBackendProvider),
      );
    });

/// Which takeaways are having their ingredients worked out right now.
final NotifierProvider<TakeawayBusyNotifier, Set<String>> takeawayBusyProvider =
    NotifierProvider<TakeawayBusyNotifier, Set<String>>(
      TakeawayBusyNotifier.new,
    );

class TakeawayBusyNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => const <String>{};

  void start(String id) => state = <String>{...state, id};

  void finish(String id) => state = <String>{
    for (final String s in state)
      if (s != id) s,
  };
}

/// Works out ingredients and nutrition with Gemini and remembers the answer.
///
/// An estimate is asked for once per dish name: a saved one (on this phone or
/// on a takeaway synced from another device) is reused. Every request goes
/// through the shared AI gate and daily cap, and makes one attempt.
final class FoodEstimator {
  FoodEstimator(this._ref);

  final Ref _ref;
  final Map<String, Future<FoodEstimate>> _inFlight =
      <String, Future<FoodEstimate>>{};

  /// A saved estimate for [name], or null.
  FoodEstimate? cached(String name) {
    final String key = estimateKey(name);
    final FoodEstimate? saved = _ref.read(foodEstimatesProvider)[key];
    if (saved != null) {
      return saved;
    }
    final List<TakeawayMeal> meals =
        _ref.read(takeawaysProvider).value ?? const <TakeawayMeal>[];
    for (final TakeawayMeal meal in meals) {
      if (meal.estimate != null && estimateKey(meal.name) == key) {
        return meal.estimate;
      }
    }
    return null;
  }

  /// The estimate for [name]: saved, or asked from Gemini and then saved.
  /// Throws an [AiFailure] when Gemini cannot be used or gives nothing usable.
  Future<FoodEstimate> estimate(String name) {
    final String key = estimateKey(name);
    final FoodEstimate? hit = cached(name);
    if (hit != null) {
      return Future<FoodEstimate>.value(hit);
    }
    final Future<FoodEstimate>? running = _inFlight[key];
    if (running != null) {
      return running;
    }
    final Future<FoodEstimate> future = _fetch(name);
    _inFlight[key] = future;
    unawaited(
      future.then<void>(
        (FoodEstimate _) {
          _inFlight.remove(key);
        },
        onError: (Object _) {
          _inFlight.remove(key);
        },
      ),
    );
    return future;
  }

  Future<FoodEstimate> _fetch(String name) async {
    final FoodEstimateService? service = _ref.read(
      foodEstimateServiceProvider,
    );
    if (service == null) {
      throw const AiServiceFailure();
    }
    final FoodEstimate result = await service.estimate(name);
    await _ref.read(settingsRepositoryProvider).writeAll(<String, String>{
      estimateSettingKey(name): result.encode(),
    });
    return result;
  }

  /// Works out the estimate for [meal] and saves it on the takeaway, so every
  /// device shows the same numbers. Throws an [AiFailure].
  Future<void> fillTakeaway(TakeawayMeal meal) async {
    if (meal.estimate != null) {
      return;
    }
    final TakeawayBusyNotifier busy = _ref.read(takeawayBusyProvider.notifier);
    busy.start(meal.id);
    try {
      final FoodEstimate estimate = await this.estimate(meal.name);
      await _ref.read(takeawayRepositoryProvider).setEstimate(
        meal.id,
        estimate,
      );
    } finally {
      busy.finish(meal.id);
    }
  }
}

final Provider<FoodEstimator> foodEstimatorProvider = Provider<FoodEstimator>(
  (Ref ref) => FoodEstimator(ref),
);

/// Looks up pantry foods the built-in nutrition table does not know, in the
/// background and a few at a time, so the eating report can count them by
/// their ingredients. Nothing is asked when AI is off or used up for today.
final class PantryEstimateWatcher {
  PantryEstimateWatcher(this._ref, {this.pause = const Duration(minutes: 15)});

  final Ref _ref;
  final Duration pause;

  /// Most foods asked about in one run of the app, so the shared daily cap is
  /// kept for voice commands and report reviews.
  static const int maxPerSession = 6;

  /// Categories that are never food.
  static const Set<String> _nonFood = <String>{
    'cat_cleaning',
    'cat_personal_care',
  };

  final Map<String, String> _pending = <String, String>{};
  final Set<String> _tried = <String>{};
  int _asked = 0;
  bool _running = false;
  bool _disposed = false;
  DateTime? _pausedUntil;

  /// True when the table does not know [item] and no estimate is saved.
  static bool needsEstimate(Item item, Map<String, FoodEstimate> known) {
    if (_nonFood.contains(item.categoryId)) {
      return false;
    }
    if (estimateKey(item.name).isEmpty) {
      return false;
    }
    if (findFoodEnergy(item.name, item.aliases) != null) {
      return false;
    }
    return !known.containsKey(estimateKey(item.name));
  }

  void consider(List<ItemStock> stocks) {
    if (_disposed || _asked >= maxPerSession) {
      return;
    }
    final Map<String, FoodEstimate> known = _ref.read(foodEstimatesProvider);
    for (final ItemStock stock in stocks) {
      final Item item = stock.item;
      final String key = estimateKey(item.name);
      if (!needsEstimate(item, known) ||
          _tried.contains(key) ||
          _pending.containsKey(key)) {
        continue;
      }
      _pending[key] = item.name;
    }
    unawaited(_run());
  }

  Future<void> _run() async {
    if (_running || _pending.isEmpty) {
      return;
    }
    final DateTime? until = _pausedUntil;
    if (until != null && _ref.read(clockProvider)().isBefore(until)) {
      return;
    }
    _running = true;
    try {
      while (!_disposed && _pending.isNotEmpty && _asked < maxPerSession) {
        final FoodEstimateService? service = _ref.read(
          foodEstimateServiceProvider,
        );
        if (service == null || !(await service.availability()).isReady) {
          _pausedUntil = _ref.read(clockProvider)().add(pause);
          break;
        }
        final MapEntry<String, String> next = _pending.entries.first;
        _pending.remove(next.key);
        _asked++;
        _tried.add(next.key);
        try {
          await _ref.read(foodEstimatorProvider).estimate(next.value);
        } on AiInvalidResponseFailure {
          // Nothing usable for this name: not asked again in this run.
        } on AiFailure {
          // Offline, quota or service trouble: try again later, not now.
          _tried.remove(next.key);
          _pausedUntil = _ref.read(clockProvider)().add(pause);
          break;
        } on Object {
          // Anything else is ignored; the food is simply not counted yet.
        }
        await Future<void>.delayed(const Duration(seconds: 2));
      }
    } finally {
      _running = false;
    }
  }

  void dispose() => _disposed = true;
}

/// Keeps [PantryEstimateWatcher] running while the app is open. Watched from
/// the app shell.
final Provider<void> pantryEstimateWatcherProvider = Provider<void>((Ref ref) {
  final PantryEstimateWatcher watcher = PantryEstimateWatcher(ref);
  ref.onDispose(watcher.dispose);
  ref.listen<AsyncValue<List<ItemStock>>>(pantryStocksProvider, (
    AsyncValue<List<ItemStock>>? previous,
    AsyncValue<List<ItemStock>> next,
  ) {
    final List<ItemStock>? list = next.value;
    if (list != null) {
      watcher.consider(list);
    }
  }, fireImmediately: true);
});
