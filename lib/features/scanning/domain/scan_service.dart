import '../../../core/util/barcode.dart';
import '../../pantry/domain/entities.dart';
import '../../pantry/domain/pantry_repository.dart';
import 'product_info.dart';
import 'product_lookup.dart';

/// Why a scanned product has no details to fill in.
enum ScanNotice {
  /// Details were found; nothing to say.
  none,

  /// Open Food Facts does not know this barcode.
  notFound,

  /// The lookup could not run (no connection, timeout, service refusing).
  offline,
}

/// What a scanned barcode turned out to be.
sealed class ScanOutcome {
  const ScanOutcome();
}

/// The barcode already belongs to an item in the pantry.
final class ScanKnownItem extends ScanOutcome {
  const ScanKnownItem(this.item);

  final Item item;
}

/// A barcode the pantry has not seen. [info] holds the details when they
/// were found; otherwise [notice] says why not. Either way the barcode is
/// kept so it is saved with the item.
final class ScanNewProduct extends ScanOutcome {
  const ScanNewProduct({
    required this.barcode,
    this.info,
    this.notice = ScanNotice.none,
  });

  /// Canonical barcode.
  final String barcode;
  final ProductInfo? info;
  final ScanNotice notice;
}

/// Turns a scanned barcode into something the add-item screen can use: the
/// pantry item it already belongs to, or product details to prefill a new one.
class ScanService {
  const ScanService({
    required this._pantry,
    required this._lookup,
  });

  final PantryRepository _pantry;
  final ProductLookup _lookup;

  Future<ScanOutcome> resolve(String rawBarcode) async {
    final String barcode = canonicalBarcode(rawBarcode);

    final Item? known = await _pantry.findItemByBarcode(barcode);
    if (known != null) {
      return ScanKnownItem(known);
    }

    final LookupResult result = await _lookup.lookup(barcode);
    return switch (result) {
      LookupFound(:final ProductInfo info) =>
        ScanNewProduct(barcode: barcode, info: info),
      LookupNotFound() =>
        ScanNewProduct(barcode: barcode, notice: ScanNotice.notFound),
      LookupUnavailable() =>
        ScanNewProduct(barcode: barcode, notice: ScanNotice.offline),
    };
  }
}
