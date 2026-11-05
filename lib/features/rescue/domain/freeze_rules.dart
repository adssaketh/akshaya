import 'dart:convert';

import '../../../core/util/date_only.dart';
import '../../pantry/domain/default_categories.dart';
import '../../pantry/domain/entities.dart';
import '../../pantry/domain/shelf_life.dart';
import '../../pantry/domain/storage_location.dart';

/// Key under which the per-category freezing days are stored (see
/// `SettingsRepository`). The value is JSON: `{"cat_dairy": 45, "cat_oils": 0}`
/// where 0 means "do not offer Freeze for this category".
const String kFreezeDaysSettingKey = 'rescue.freeze_days';

/// Longest freezing time that can be set, in days (two years).
const int kMaxFreezeDays = 730;

/// How many days frozen food of each category keeps, and which categories
/// are never offered Freeze. Pure Dart.
abstract final class FreezeDefaults {
  /// Days used for a category the app has no rule for (one the person
  /// added).
  static const int unknownCategoryDays = 30;

  /// Days by default category id. A category that is missing here has no
  /// rule; a null value means Freeze is not offered for it.
  static const Map<String, int?> byCategory = <String, int?>{
    'cat_vegetables': 60,
    'cat_fruits': 60,
    'cat_dairy': 60,
    'cat_grains': 180,
    'cat_dals': 180,
    'cat_spices': 365,
    'cat_oils': null,
    'cat_snacks': 90,
    'cat_beverages': null,
    'cat_bakery': 90,
    'cat_frozen': 90,
    'cat_meat_eggs': 90,
    'cat_cleaning': null,
    'cat_personal_care': null,
    kDefaultCategoryId: 30,
  };

  /// The built-in rule for [categoryId]: days, or null when Freeze is not
  /// offered.
  static int? daysFor(String categoryId) {
    if (byCategory.containsKey(categoryId)) {
      return byCategory[categoryId];
    }
    return unknownCategoryDays;
  }
}

/// The person's own freezing days, on top of [FreezeDefaults].
final class FreezeSettings {
  const FreezeSettings({this.overrides = const <String, int>{}});

  /// Reads the setting from stored text, ignoring anything unreadable.
  factory FreezeSettings.fromMap(Map<String, String> values) {
    final String? text = values[kFreezeDaysSettingKey];
    if (text == null || text.isEmpty) {
      return const FreezeSettings();
    }
    try {
      final Object? decoded = jsonDecode(text);
      if (decoded is! Map<String, dynamic>) {
        return const FreezeSettings();
      }
      final Map<String, int> result = <String, int>{};
      for (final MapEntry<String, dynamic> e in decoded.entries) {
        final Object? v = e.value;
        if (v is int && v >= 0 && v <= kMaxFreezeDays) {
          result[e.key] = v;
        }
      }
      return FreezeSettings(overrides: result);
    } on FormatException {
      return const FreezeSettings();
    }
  }

  /// Category id to days; 0 means Freeze is not offered.
  final Map<String, int> overrides;

  /// Days frozen food of [categoryId] keeps, or null when Freeze is not
  /// offered for it.
  int? daysFor(String categoryId) {
    final int? own = overrides[categoryId];
    if (own != null) {
      return own == 0 ? null : own;
    }
    return FreezeDefaults.daysFor(categoryId);
  }

  /// Whether the person changed [categoryId] from the built-in rule.
  bool isCustom(String categoryId) => overrides.containsKey(categoryId);

  /// Sets [categoryId] to [days] (1 to [kMaxFreezeDays]); null means "do not
  /// offer Freeze".
  FreezeSettings withDays(String categoryId, int? days) {
    final int stored =
        days == null ? 0 : days.clamp(1, kMaxFreezeDays).toInt();
    return FreezeSettings(
      overrides: <String, int>{...overrides, categoryId: stored},
    );
  }

  /// Goes back to the built-in rule for [categoryId].
  FreezeSettings reset(String categoryId) {
    final Map<String, int> next = <String, int>{...overrides}
      ..remove(categoryId);
    return FreezeSettings(overrides: next);
  }

  /// The text form stored by the settings repository.
  Map<String, String> toMap() {
    return <String, String>{kFreezeDaysSettingKey: jsonEncode(overrides)};
  }

  @override
  bool operator ==(Object other) {
    if (other is! FreezeSettings || other.overrides.length != overrides.length) {
      return false;
    }
    for (final MapEntry<String, int> e in overrides.entries) {
      if (other.overrides[e.key] != e.value) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode {
    final List<String> keys = overrides.keys.toList()..sort();
    return Object.hashAll(<Object>[
      for (final String key in keys) ...<Object>[key, overrides[key]!],
    ]);
  }
}

/// What freezing one batch changes.
final class FreezePlan {
  const FreezePlan({
    required this.frozen,
    required this.days,
    required this.newExpiry,
  });

  /// The batch as it should be saved: kept in the freezer with the new date.
  final StockBatch frozen;

  /// Days the food keeps in the freezer.
  final int days;

  /// The date to use it by after freezing.
  final DateTime newExpiry;
}

/// The Freeze action: what it needs and what it does. Pure Dart.
abstract final class Freezer {
  /// Days [item] keeps in the freezer, or null when Freeze is not offered.
  /// Food made at home follows its shelf life; bought food follows the
  /// category rule.
  static int? daysFor(Item item, FreezeSettings settings) {
    if (item.kind.isMadeAtHome) {
      return ShelfLife.daysForItem(item, StorageLocation.freezer);
    }
    return settings.daysFor(item.categoryId);
  }

  /// Whether Freeze is offered for [batch] on [today]: it holds stock, is not
  /// in the freezer already, has not passed its date (freezing does not make
  /// expired food safe) and the category allows it.
  static bool canFreeze({
    required Item item,
    required StockBatch batch,
    required FreezeSettings settings,
    required DateTime today,
  }) {
    if (batch.quantityRemaining <= 0 ||
        batch.storageLocation == StorageLocation.freezer) {
      return false;
    }
    final DateTime? expiry = batch.effectiveExpiry;
    if (expiry != null && expiry.isBefore(dateOnly(today))) {
      return false;
    }
    return daysFor(item, settings) != null;
  }

  /// Moves [batch] to the freezer and sets its date to the later of its
  /// printed date and `today + days`. Freezing stops the "use within days
  /// after opening" clock, so that limit is cleared (the opened date stays).
  /// Null when [canFreeze] is false.
  static FreezePlan? plan({
    required Item item,
    required StockBatch batch,
    required FreezeSettings settings,
    required DateTime today,
  }) {
    if (!canFreeze(
      item: item,
      batch: batch,
      settings: settings,
      today: today,
    )) {
      return null;
    }
    final int days = daysFor(item, settings)!;
    final DateTime candidate = addDays(dateOnly(today), days);
    final DateTime? printed = batch.expiryDate;
    final DateTime newExpiry =
        printed != null && printed.isAfter(candidate) ? printed : candidate;
    final StockBatch frozen = StockBatch(
      id: batch.id,
      itemId: batch.itemId,
      quantityBought: batch.quantityBought,
      quantityRemaining: batch.quantityRemaining,
      unit: batch.unit,
      purchaseDate: batch.purchaseDate,
      storageLocation: StorageLocation.freezer,
      createdAt: batch.createdAt,
      expiryDate: newExpiry,
      openedDate: batch.openedDate,
      useWithinDaysAfterOpening: null,
      price: batch.price,
      store: batch.store,
      containerLabel: batch.containerLabel,
      checkBy: batch.checkBy,
    );
    return FreezePlan(frozen: frozen, days: days, newExpiry: newExpiry);
  }
}
