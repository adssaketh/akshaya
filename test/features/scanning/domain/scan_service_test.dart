import 'package:akshaya/features/pantry/domain/entities.dart';
import 'package:akshaya/features/scanning/domain/product_info.dart';
import 'package:akshaya/features/scanning/domain/product_lookup.dart';
import 'package:akshaya/features/scanning/domain/scan_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../pantry/domain/test_data.dart';
import '../../pantry/presentation/fake_repository.dart';

class FakeLookup implements ProductLookup {
  FakeLookup(this.result);

  LookupResult result;
  final List<String> asked = <String>[];

  @override
  Future<LookupResult> lookup(String barcode) async {
    asked.add(barcode);
    return result;
  }
}

void main() {
  test('a barcode the pantry knows never goes online', () async {
    final FakePantryRepository pantry = FakePantryRepository(
      items: <ItemWithBatches>[
        ItemWithBatches(item: makeItem(name: 'Butter'), batches: const <StockBatch>[]),
      ],
    )..barcodes['4006381333931'] = 'i1';
    final FakeLookup lookup = FakeLookup(const LookupUnavailable());

    final ScanOutcome outcome =
        await ScanService(pantry: pantry, lookup: lookup).resolve('4006381333931');

    expect(outcome, isA<ScanKnownItem>());
    expect((outcome as ScanKnownItem).item.name, 'Butter');
    expect(lookup.asked, isEmpty);
  });

  test('a new barcode with details becomes a prefilled product', () async {
    final FakeLookup lookup = FakeLookup(
      const LookupFound(ProductInfo(name: 'Salted Butter', brand: 'Amul')),
    );

    final ScanOutcome outcome =
        await ScanService(pantry: FakePantryRepository(), lookup: lookup)
            .resolve('036000291452');

    final ScanNewProduct product = outcome as ScanNewProduct;
    expect(product.barcode, '0036000291452', reason: 'canonical form');
    expect(product.info!.name, 'Salted Butter');
    expect(product.notice, ScanNotice.none);
    expect(lookup.asked, <String>['0036000291452']);
  });

  test('an unknown barcode keeps the code and says it was not found', () async {
    final ScanOutcome outcome = await ScanService(
      pantry: FakePantryRepository(),
      lookup: FakeLookup(const LookupNotFound()),
    ).resolve('4006381333931');

    final ScanNewProduct product = outcome as ScanNewProduct;
    expect(product.barcode, '4006381333931');
    expect(product.info, isNull);
    expect(product.notice, ScanNotice.notFound);
  });

  test('offline keeps the code and says so', () async {
    final ScanOutcome outcome = await ScanService(
      pantry: FakePantryRepository(),
      lookup: FakeLookup(const LookupUnavailable()),
    ).resolve('4006381333931');

    expect((outcome as ScanNewProduct).notice, ScanNotice.offline);
  });
}
