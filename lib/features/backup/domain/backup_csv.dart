import '../../../core/util/quantity.dart';
import '../../pantry/domain/entities.dart';
import 'csv.dart';

/// "2026-11-04".
String _date(DateTime d) {
  final String m = d.month.toString().padLeft(2, '0');
  final String day = d.day.toString().padLeft(2, '0');
  return '${d.year}-$m-$day';
}

/// The CSV files Settings can export. Pure Dart.
abstract final class BackupCsv {
  /// One row per purchase batch: what is in the pantry, with dates and
  /// prices.
  static String pantry(List<ItemWithBatches> records, List<Category> categories) {
    final Map<String, String> categoryNames = <String, String>{
      for (final Category c in categories) c.id: c.name,
    };
    final List<ItemWithBatches> sorted = List<ItemWithBatches>.of(records)
      ..sort(
        (ItemWithBatches a, ItemWithBatches b) =>
            a.item.name.toLowerCase().compareTo(b.item.name.toLowerCase()),
      );
    final List<List<Object?>> rows = <List<Object?>>[
      <Object?>[
        'Item',
        'Brand',
        'Category',
        'Quantity left',
        'Unit',
        'Quantity bought',
        'Purchased',
        'Expiry',
        'Opened',
        'Price',
        'Store',
        'Location',
        'Type',
        'Container',
        'Check by',
      ],
    ];
    for (final ItemWithBatches r in sorted) {
      for (final StockBatch b in r.batches) {
        rows.add(<Object?>[
          r.item.name,
          r.item.brand,
          categoryNames[r.item.categoryId] ?? 'Other',
          roundQty(b.quantityRemaining),
          b.unit.symbol,
          roundQty(b.quantityBought),
          _date(b.purchaseDate),
          b.expiryDate == null ? null : _date(b.expiryDate!),
          b.openedDate == null ? null : _date(b.openedDate!),
          b.price,
          b.store,
          b.storageLocation.label,
          r.item.kind.label,
          b.containerLabel,
          b.checkBy == null ? null : _date(b.checkBy!),
        ]);
      }
    }
    return Csv.encode(rows);
  }

  /// One row per use, waste or expiry entry, oldest first.
  static String history(
    List<ConsumptionEntry> logs,
    List<ItemWithBatches> records,
  ) {
    final Map<String, String> names = <String, String>{
      for (final ItemWithBatches r in records) r.item.id: r.item.name,
    };
    final List<ConsumptionEntry> sorted = List<ConsumptionEntry>.of(logs)
      ..sort(
        (ConsumptionEntry a, ConsumptionEntry b) => a.date.compareTo(b.date),
      );
    final List<List<Object?>> rows = <List<Object?>>[
      <Object?>['Date', 'Item', 'Quantity', 'Unit', 'Type', 'Reason'],
      for (final ConsumptionEntry e in sorted)
        <Object?>[
          _date(e.date),
          names[e.itemId] ?? 'Removed item',
          roundQty(e.quantityUsed),
          e.unit.symbol,
          e.type.label,
          e.wasteReason?.label,
        ],
    ];
    return Csv.encode(rows);
  }
}
