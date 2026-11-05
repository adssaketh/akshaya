import '../../../core/util/date_only.dart';
import 'consumption_type.dart';
import 'item_kind.dart';
import 'storage_location.dart';
import 'unit.dart';
import 'waste_reason.dart';

/// Editable product category. The id is stable for the default categories
/// (for example `cat_vegetables`) so devices that sync later agree on them.
final class Category {
  const Category({
    required this.id,
    required this.name,
    required this.iconKey,
    required this.sortOrder,
  });

  final String id;
  final String name;

  /// Key resolved to an icon in the presentation layer.
  final String iconKey;
  final int sortOrder;
}

/// A product definition (what the thing is), not a purchase of it.
final class Item {
  const Item({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.defaultUnit,
    required this.aliases,
    required this.isEssential,
    required this.defaultStorageLocation,
    required this.createdAt,
    required this.updatedAt,
    this.brand,
    this.barcode,
    this.imagePath,
    this.notes,
    this.lowStockThreshold,
    this.kind = ItemKind.stocked,
    this.shelfLifeDays,
  });

  final String id;

  /// Canonical English name.
  final String name;
  final String? brand;
  final String? barcode;
  final String categoryId;
  final Unit defaultUnit;
  final String? imagePath;
  final String? notes;

  /// Other names in any language or script ("బియ్యం", "biyyam", "chawal").
  final List<String> aliases;

  /// Low-stock when the total remaining is at or below this (default unit).
  final double? lowStockThreshold;
  final bool isEssential;
  final StorageLocation defaultStorageLocation;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Stocked (bought), cooked (leftovers) or homemade.
  final ItemKind kind;

  /// Days the food keeps in [defaultStorageLocation], for cooked and homemade
  /// items. Null uses the default for the kind (see `ShelfLife`).
  final int? shelfLifeDays;

  /// Cooked food that is eaten within days.
  bool get isLeftover => kind == ItemKind.cooked;
}

/// One purchase of an item. Each purchase is a separate batch so expiry and
/// price are tracked per purchase.
final class StockBatch {
  const StockBatch({
    required this.id,
    required this.itemId,
    required this.quantityBought,
    required this.quantityRemaining,
    required this.unit,
    required this.purchaseDate,
    required this.storageLocation,
    required this.createdAt,
    this.expiryDate,
    this.openedDate,
    this.useWithinDaysAfterOpening,
    this.price,
    this.store,
    this.containerLabel,
    this.checkBy,
  });

  final String id;
  final String itemId;
  final double quantityBought;
  final double quantityRemaining;
  final Unit unit;
  final DateTime purchaseDate;

  /// Printed expiry date, if any.
  final DateTime? expiryDate;
  final DateTime? openedDate;
  final int? useWithinDaysAfterOpening;

  /// Total price paid for the whole batch, in rupees.
  final double? price;
  final String? store;
  final StorageLocation storageLocation;
  final DateTime createdAt;

  /// What the food is kept in ("steel dabba", "blue box"), if recorded.
  final String? containerLabel;

  /// A day to look at homemade food again, if the person asked for one.
  final DateTime? checkBy;

  /// The earlier of the printed expiry and "opened date + use within days".
  DateTime? get effectiveExpiry {
    final DateTime? opened = openedDate;
    final int? within = useWithinDaysAfterOpening;
    final DateTime? printed = expiryDate;

    DateTime? afterOpening;
    if (opened != null && within != null) {
      afterOpening = addDays(opened, within);
    }

    if (printed == null) {
      return afterOpening;
    }
    if (afterOpening == null) {
      return printed;
    }
    return afterOpening.isBefore(printed) ? afterOpening : printed;
  }

  /// Price per one [target] unit, or null when there is no price or the batch
  /// unit cannot be converted to [target].
  double? unitPrice(Unit target) {
    final double? total = price;
    if (total == null || !unit.isCompatibleWith(target)) {
      return null;
    }
    final double quantity = unit.convertTo(quantityBought, target);
    if (quantity <= 0) {
      return null;
    }
    return total / quantity;
  }
}

/// A record of stock leaving the pantry.
final class ConsumptionEntry {
  const ConsumptionEntry({
    required this.id,
    required this.batchId,
    required this.itemId,
    required this.quantityUsed,
    required this.unit,
    required this.date,
    required this.type,
    this.wasteReason,
  });

  final String id;
  final String batchId;
  final String itemId;

  /// Amount that left the batch, in [unit] (the batch's unit). Negative only
  /// for an [ConsumptionType.adjustment] that raised the stock.
  final double quantityUsed;
  final Unit unit;
  final DateTime date;
  final ConsumptionType type;

  /// Why the food was thrown away, when the person said. Null for logs made
  /// before reasons existed and for anything that is not waste.
  final WasteReason? wasteReason;

  /// "2 kg" for use and waste; "+1 kg" or "-1 kg" for an adjustment.
  String get amountLabel {
    if (type != ConsumptionType.adjustment) {
      return unit.format(quantityUsed);
    }
    if (quantityUsed < 0) {
      return '+${unit.format(-quantityUsed)}';
    }
    return '-${unit.format(quantityUsed)}';
  }
}

/// An item together with its active (not deleted) batches.
final class ItemWithBatches {
  const ItemWithBatches({required this.item, required this.batches});

  final Item item;
  final List<StockBatch> batches;
}

/// Everything needed to create an item.
final class ItemDraft {
  const ItemDraft({
    required this.name,
    required this.categoryId,
    required this.defaultUnit,
    this.brand,
    this.barcode,
    this.imagePath,
    this.notes,
    this.aliases = const <String>[],
    this.lowStockThreshold,
    this.isEssential = false,
    this.defaultStorageLocation = StorageLocation.pantry,
    this.kind = ItemKind.stocked,
    this.shelfLifeDays,
  });

  final String name;
  final String categoryId;
  final Unit defaultUnit;
  final String? brand;
  final String? barcode;
  final String? imagePath;
  final String? notes;
  final List<String> aliases;
  final double? lowStockThreshold;
  final bool isEssential;
  final StorageLocation defaultStorageLocation;
  final ItemKind kind;
  final int? shelfLifeDays;
}

/// Everything needed to record a purchase.
final class BatchDraft {
  const BatchDraft({
    required this.itemId,
    required this.quantityBought,
    required this.unit,
    required this.purchaseDate,
    required this.storageLocation,
    this.quantityRemaining,
    this.expiryDate,
    this.openedDate,
    this.useWithinDaysAfterOpening,
    this.price,
    this.store,
    this.containerLabel,
    this.checkBy,
  });

  final String itemId;
  final double quantityBought;

  /// Defaults to [quantityBought] when null (a full, unopened purchase).
  final double? quantityRemaining;
  final Unit unit;
  final DateTime purchaseDate;
  final DateTime? expiryDate;
  final DateTime? openedDate;
  final int? useWithinDaysAfterOpening;
  final double? price;
  final String? store;
  final StorageLocation storageLocation;
  final String? containerLabel;
  final DateTime? checkBy;
}

/// What a deletion changed, so it can be undone.
final class DeleteToken {
  const DeleteToken({required this.itemId, required this.batchIds});

  final String itemId;

  /// Batches that were deleted together with the item.
  final List<String> batchIds;
}

/// One batch deduction made by a use/waste action.
final class AppliedDeduction {
  const AppliedDeduction({
    required this.batchId,
    required this.logId,
    required this.amount,
    required this.unit,
  });

  final String batchId;
  final String logId;

  /// Amount taken from the batch, in the batch's [unit].
  final double amount;
  final Unit unit;
}

/// What a use/waste action changed, so it can be undone.
final class UseResult {
  const UseResult({
    required this.itemId,
    required this.quantity,
    required this.unit,
    required this.type,
    required this.applied,
  });

  final String itemId;

  /// Total amount, in [unit] (the unit the person asked for).
  final double quantity;
  final Unit unit;
  final ConsumptionType type;
  final List<AppliedDeduction> applied;
}
