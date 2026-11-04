import 'product_info.dart';

/// Outcome of looking a barcode up online (or in the local cache).
sealed class LookupResult {
  const LookupResult();
}

/// The product is known.
final class LookupFound extends LookupResult {
  const LookupFound(this.info);

  final ProductInfo info;
}

/// The service answered but does not know this barcode.
final class LookupNotFound extends LookupResult {
  const LookupNotFound();
}

/// The service could not be reached (offline, timed out, or refusing
/// requests), and nothing usable was cached.
final class LookupUnavailable extends LookupResult {
  const LookupUnavailable();
}

/// Thrown by a remote source when it cannot give an answer at all. A product
/// that simply is not there is not an error: sources return null for it.
final class LookupUnavailableException implements Exception {
  const LookupUnavailableException();

  @override
  String toString() => 'Product lookup is unavailable.';
}

/// Finds product details for a barcode. Never throws: every problem becomes
/// [LookupUnavailable], so scanning keeps working offline.
abstract interface class ProductLookup {
  Future<LookupResult> lookup(String barcode);
}
