import '../../../core/util/date_only.dart';
import '../../../core/util/quantity.dart';
import '../../pantry/domain/entities.dart';
import '../../pantry/domain/stock_logic.dart';
import '../../pantry/domain/unit.dart';

/// What the pantry holds of one item that can still be cooked with: stock in
/// batches that are not past their date, counted in the item's own unit.
final class PantryLine {
  const PantryLine({
    required this.item,
    required this.usable,
    this.expiry,
    this.daysLeft,
  });

  final Item item;

  /// Cookable quantity in [unit]. Zero for an item that is out of stock or
  /// only has expired batches.
  final double usable;

  /// The earliest effective expiry among the cookable batches.
  final DateTime? expiry;

  /// Calendar days from today to [expiry].
  final int? daysLeft;

  String get itemId => item.id;

  String get name => item.name;

  Unit get unit => item.defaultUnit;

  bool get hasStock => !isZeroQty(usable);

  /// "1.5 kg".
  String get quantityLabel => unit.format(usable);
}

/// Works out the cookable pantry for recipe suggestions. Pure Dart.
abstract final class RecipePantry {
  /// At most this many items are described to the AI (the ones expiring
  /// soonest come first), which keeps the request small.
  static const int maxPromptLines = 60;

  /// One line per pantry item, cookable stock first, soonest expiry first,
  /// then the rest by name. Expired batches do not count as stock.
  static List<PantryLine> build(
    List<ItemStock> stocks, {
    required DateTime today,
  }) {
    final List<PantryLine> lines = <PantryLine>[];
    for (final ItemStock stock in stocks) {
      double total = 0;
      DateTime? nearest;
      for (final StockBatch batch in stock.inStock) {
        final DateTime? expiry = batch.effectiveExpiry;
        if (expiry != null && expiry.isBefore(today)) {
          continue;
        }
        if (!batch.unit.isCompatibleWith(stock.item.defaultUnit)) {
          continue;
        }
        total += batch.unit.convertTo(
          batch.quantityRemaining,
          stock.item.defaultUnit,
        );
        if (expiry != null && (nearest == null || expiry.isBefore(nearest))) {
          nearest = expiry;
        }
      }
      lines.add(
        PantryLine(
          item: stock.item,
          usable: roundQty(total),
          expiry: nearest,
          daysLeft: nearest == null ? null : daysBetween(today, nearest),
        ),
      );
    }
    lines.sort(_byUrgency);
    return lines;
  }

  /// Lines that have cookable stock.
  static List<PantryLine> stocked(List<PantryLine> lines) {
    return <PantryLine>[
      for (final PantryLine line in lines)
        if (line.hasStock) line,
    ];
  }

  /// The lines described to the AI: cookable stock, soonest expiry first,
  /// limited to [maxPromptLines].
  static List<PantryLine> forPrompt(List<PantryLine> lines) {
    return stocked(lines).take(maxPromptLines).toList();
  }

  /// Item id to days left, for cookable items that expire within
  /// [warningDays] (the same window the Pantry uses for "Expiring soon").
  static Map<String, int> expiringDays(
    List<PantryLine> lines, {
    required int warningDays,
  }) {
    final Map<String, int> out = <String, int>{};
    for (final PantryLine line in lines) {
      final int? days = line.daysLeft;
      if (line.hasStock && days != null && days <= warningDays) {
        out[line.itemId] = days;
      }
    }
    return out;
  }

  static int _byUrgency(PantryLine a, PantryLine b) {
    if (a.hasStock != b.hasStock) {
      return a.hasStock ? -1 : 1;
    }
    final int? daysA = a.daysLeft;
    final int? daysB = b.daysLeft;
    if (daysA != daysB) {
      if (daysA == null) {
        return 1;
      }
      if (daysB == null) {
        return -1;
      }
      return daysA.compareTo(daysB);
    }
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  }
}
