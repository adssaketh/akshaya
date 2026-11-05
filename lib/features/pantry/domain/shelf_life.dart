import '../../../core/util/date_only.dart';
import 'entities.dart';
import 'item_kind.dart';
import 'storage_location.dart';

/// How long cooked and homemade food keeps. Pure Dart.
///
/// Every location has a default for each kind. An item can carry its own
/// number of days; that number applies to the place the item is usually kept
/// (`defaultStorageLocation`), and any other place falls back to the default.
abstract final class ShelfLife {
  /// Longest shelf life accepted, in days (ten years).
  static const int maxDays = 3650;

  /// Days a [kind] of food keeps in [location] when nothing else is known, or
  /// null for stocked items (they carry a printed date instead).
  static int? defaultDays(ItemKind kind, StorageLocation location) {
    switch (kind) {
      case ItemKind.stocked:
        return null;
      case ItemKind.cooked:
        switch (location) {
          case StorageLocation.fridge:
            return 2;
          case StorageLocation.freezer:
            return 30;
          case StorageLocation.pantry:
          case StorageLocation.other:
            return 1;
        }
      case ItemKind.homemade:
        switch (location) {
          case StorageLocation.fridge:
            return 30;
          case StorageLocation.freezer:
            return 180;
          case StorageLocation.pantry:
            return 90;
          case StorageLocation.other:
            return 30;
        }
    }
  }

  /// Days for food of [kind] kept in [location]: [own] when it is set and
  /// [location] is [usualLocation], otherwise the default. Null for stocked
  /// items.
  static int? daysFor({
    required ItemKind kind,
    required StorageLocation location,
    int? own,
    StorageLocation? usualLocation,
  }) {
    if (kind.isStocked) {
      return null;
    }
    if (own != null && own > 0 && location == usualLocation) {
      return own;
    }
    return defaultDays(kind, location);
  }

  /// The same for an existing [item].
  static int? daysForItem(Item item, StorageLocation location) {
    return daysFor(
      kind: item.kind,
      location: location,
      own: item.shelfLifeDays,
      usualLocation: item.defaultStorageLocation,
    );
  }

  /// The date food made on [madeOn] should be used by, or null for stocked
  /// items.
  static DateTime? expiryFor({
    required ItemKind kind,
    required StorageLocation location,
    required DateTime madeOn,
    int? own,
    StorageLocation? usualLocation,
  }) {
    final int? days = daysFor(
      kind: kind,
      location: location,
      own: own,
      usualLocation: usualLocation,
    );
    return days == null ? null : addDays(madeOn, days);
  }

  /// "2 days", "1 day".
  static String label(int days) => days == 1 ? '1 day' : '$days days';
}
