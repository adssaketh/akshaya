import 'package:akshaya/features/pantry/domain/entities.dart';
import 'package:akshaya/features/pantry/domain/storage_location.dart';
import 'package:akshaya/features/pantry/domain/unit.dart';

final DateTime kToday = DateTime(2026, 11, 4);

Item makeItem({
  String id = 'i1',
  String name = 'Rice',
  Unit unit = Unit.kg,
  double? threshold,
  List<String> aliases = const <String>[],
  String? brand,
  String categoryId = 'cat_grains',
}) {
  return Item(
    id: id,
    name: name,
    brand: brand,
    categoryId: categoryId,
    defaultUnit: unit,
    aliases: aliases,
    lowStockThreshold: threshold,
    isEssential: false,
    defaultStorageLocation: StorageLocation.pantry,
    createdAt: kToday,
    updatedAt: kToday,
  );
}

StockBatch makeBatch({
  String id = 'b1',
  String itemId = 'i1',
  double bought = 1,
  double? remaining,
  Unit unit = Unit.kg,
  DateTime? expiry,
  DateTime? opened,
  int? within,
  DateTime? purchase,
  StorageLocation location = StorageLocation.pantry,
  DateTime? createdAt,
}) {
  return StockBatch(
    id: id,
    itemId: itemId,
    quantityBought: bought,
    quantityRemaining: remaining ?? bought,
    unit: unit,
    purchaseDate: purchase ?? DateTime(2026, 10, 1),
    expiryDate: expiry,
    openedDate: opened,
    useWithinDaysAfterOpening: within,
    storageLocation: location,
    createdAt: createdAt ?? DateTime(2026, 10, 1),
  );
}
