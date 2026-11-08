import 'entities.dart';
import 'storage_location.dart';

/// Small "same item, one thing changed" copies used by the move actions.
extension ItemMoves on Item {
  Item _copy({
    String? categoryId,
    StorageLocation? location,
    bool? essential,
  }) {
    return Item(
      id: id,
      name: name,
      brand: brand,
      barcode: barcode,
      categoryId: categoryId ?? this.categoryId,
      defaultUnit: defaultUnit,
      imagePath: imagePath,
      notes: notes,
      aliases: aliases,
      lowStockThreshold: lowStockThreshold,
      isEssential: essential ?? isEssential,
      defaultStorageLocation: location ?? defaultStorageLocation,
      createdAt: createdAt,
      updatedAt: updatedAt,
      kind: kind,
      shelfLifeDays: shelfLifeDays,
    );
  }

  /// This item in another category.
  Item inCategory(String newCategoryId) => _copy(categoryId: newCategoryId);

  /// This item with another usual storage place.
  Item keptIn(StorageLocation location) => _copy(location: location);

  /// This item marked (or unmarked) as an essential.
  Item asEssential({required bool essential}) => _copy(essential: essential);
}

extension StockBatchMoves on StockBatch {
  /// This batch stored somewhere else.
  StockBatch storedIn(StorageLocation location) {
    return StockBatch(
      id: id,
      itemId: itemId,
      quantityBought: quantityBought,
      quantityRemaining: quantityRemaining,
      unit: unit,
      purchaseDate: purchaseDate,
      expiryDate: expiryDate,
      openedDate: openedDate,
      useWithinDaysAfterOpening: useWithinDaysAfterOpening,
      price: price,
      store: store,
      storageLocation: location,
      createdAt: createdAt,
      containerLabel: containerLabel,
      checkBy: checkBy,
    );
  }
}
