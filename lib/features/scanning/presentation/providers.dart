import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/time/clock.dart';
import '../../pantry/presentation/providers.dart';
import '../data/cached_product_lookup.dart';
import '../data/open_food_facts_client.dart';
import '../domain/product_lookup.dart';
import '../domain/scan_service.dart';

/// Looks products up on Open Food Facts, with a local cache. Tests override
/// this with a fake.
final Provider<ProductLookup> productLookupProvider =
    Provider<ProductLookup>((Ref ref) {
  final http.Client client = http.Client();
  ref.onDispose(client.close);
  return CachedProductLookup(
    db: ref.watch(appDatabaseProvider),
    remote: OpenFoodFactsClient(client: client),
    clock: ref.watch(clockProvider),
  );
});

/// Resolves a scanned barcode. Tests override this with a fake.
final Provider<ScanService> scanServiceProvider =
    Provider<ScanService>((Ref ref) {
  return ScanService(
    pantry: ref.watch(pantryRepositoryProvider),
    lookup: ref.watch(productLookupProvider),
  );
});
