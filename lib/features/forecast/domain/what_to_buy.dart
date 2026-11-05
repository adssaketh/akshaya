import '../../../core/util/quantity.dart';
import '../../pantry/domain/entities.dart';
import '../../pantry/domain/stock_logic.dart';
import '../../pantry/domain/unit.dart';
import '../../shopping/domain/shopping_entities.dart';
import '../../shopping/domain/shopping_enums.dart';
import 'consumption_forecast.dart';
import 'purchase_history.dart';

/// One item predicted to run out soon, with how much to buy.
final class BuyRecommendation {
  const BuyRecommendation({
    required this.item,
    required this.forecast,
    required this.quantity,
    required this.packSize,
  });

  final Item item;
  final ItemForecast forecast;

  /// How much to buy, in the item's default unit: a whole number of packs.
  final double quantity;

  /// The pack size the person usually buys, in the item's default unit.
  final double packSize;

  Unit get unit => item.defaultUnit;

  /// "2 kg".
  String get quantityLabel => unit.format(quantity);

  /// "Runs out in ~3 days" or "Out of stock".
  String get reason => forecast.label;

  BuyRecommendation withQuantity(double newQuantity) {
    return BuyRecommendation(
      item: item,
      forecast: forecast,
      quantity: roundQty(newQuantity),
      packSize: packSize,
    );
  }

  /// The shopping entry to add. It is marked as low stock, the closest reason
  /// the list knows for "you are about to run out".
  ShoppingEntryDraft toDraft(String listId) {
    return ShoppingEntryDraft(
      listId: listId,
      itemId: item.id,
      name: item.name,
      quantity: quantity,
      unit: unit,
      addedReason: AddedReason.lowStock,
    );
  }
}

/// Works out the "What should I buy?" list. Pure Dart.
abstract final class WhatToBuy {
  /// Items predicted to run out within this many days are listed.
  static const int defaultHorizonDays = 7;

  /// The horizons the screen offers.
  static const List<int> horizonChoices = <int>[3, 7, 14, 30];

  /// What a purchase should cover at least, in days.
  static const int minCoverDays = 14;

  /// Days a purchase covers beyond the horizon, when that is longer than
  /// [minCoverDays].
  static const int coverBeyondHorizonDays = 7;

  /// Items whose stock is predicted to run out within [horizonDays], soonest
  /// first. Items already on a shopping list (matched by item, or by name for
  /// free-text entries) and items still learning are left out.
  ///
  /// The suggested quantity covers the larger of [minCoverDays] and the
  /// horizon plus a week, rounded up to whole packs of the size usually
  /// bought, and is never less than one pack.
  static List<BuyRecommendation> compute({
    required List<ItemStock> stocks,
    required Map<String, ItemForecast> forecasts,
    required List<ShoppingEntry> entries,
    int horizonDays = defaultHorizonDays,
    Set<String> excludedBatchIds = const <String>{},
  }) {
    final Set<String> listedItemIds = <String>{
      for (final ShoppingEntry e in entries)
        if (e.itemId != null) e.itemId!,
    };
    final Set<String> listedNames = <String>{
      for (final ShoppingEntry e in entries) _key(e.name),
    };
    final int coverDays = horizonDays + coverBeyondHorizonDays > minCoverDays
        ? horizonDays + coverBeyondHorizonDays
        : minCoverDays;

    final List<BuyRecommendation> out = <BuyRecommendation>[];
    for (final ItemStock stock in stocks) {
      final Item item = stock.item;
      final ItemForecast? forecast = forecasts[item.id];
      final int? daysLeft = forecast?.daysLeft;
      if (forecast == null ||
          !forecast.isReady ||
          daysLeft == null ||
          daysLeft > horizonDays) {
        continue;
      }
      if (listedItemIds.contains(item.id) ||
          listedNames.contains(_key(item.name))) {
        continue;
      }

      final double pack = PurchaseHistory.usualPackSize(
        item,
        stock.batches,
        excludedBatchIds: excludedBatchIds,
      );
      final double need = forecast.perDay * coverDays - forecast.remaining;
      double quantity = pack;
      if (need > pack) {
        final int packs = (need / pack - kQtyEpsilon).ceil();
        quantity = roundQty(packs * pack);
      }
      out.add(
        BuyRecommendation(
          item: item,
          forecast: forecast,
          quantity: quantity,
          packSize: pack,
        ),
      );
    }

    out.sort((BuyRecommendation a, BuyRecommendation b) {
      final int byDays = a.forecast.daysLeft!.compareTo(b.forecast.daysLeft!);
      if (byDays != 0) {
        return byDays;
      }
      return a.item.name.toLowerCase().compareTo(b.item.name.toLowerCase());
    });
    return out;
  }

  static String _key(String name) => name.trim().toLowerCase();
}
