import 'package:akshaya/core/util/barcode.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeBarcode', () {
    test('keeps EAN-13 and EAN-8 as they are', () {
      expect(normalizeBarcode('4006381333931'), '4006381333931');
      expect(normalizeBarcode('96385074'), '96385074');
    });

    test('turns UPC-A into EAN-13', () {
      expect(normalizeBarcode('036000291452'), '0036000291452');
    });

    test('turns a GTIN-14 with a leading zero into EAN-13', () {
      expect(normalizeBarcode('04006381333931'), '4006381333931');
      expect(normalizeBarcode('14006381333938'), '14006381333938');
    });

    test('ignores spaces and dashes', () {
      expect(normalizeBarcode(' 4006381 333931 '), '4006381333931');
      expect(normalizeBarcode('4006-3813-33931'), '4006381333931');
    });

    test('rejects text and the wrong lengths', () {
      expect(normalizeBarcode(''), isNull);
      expect(normalizeBarcode('12345'), isNull);
      expect(normalizeBarcode('40063813339A1'), isNull);
      expect(normalizeBarcode('123456789012345'), isNull);
    });
  });

  group('canonicalBarcode', () {
    test('falls back to the trimmed text for non-retail codes', () {
      expect(canonicalBarcode('  SHOP-42 '), 'SHOP-42');
      expect(canonicalBarcode('123'), '123');
    });

    test('canonicalises retail codes', () {
      expect(canonicalBarcode('036000291452'), '0036000291452');
    });
  });

  group('hasValidCheckDigit', () {
    test('accepts real codes', () {
      expect(hasValidCheckDigit('4006381333931'), isTrue);
      expect(hasValidCheckDigit('036000291452'), isTrue);
      expect(hasValidCheckDigit('96385074'), isTrue);
    });

    test('rejects a mistyped digit', () {
      expect(hasValidCheckDigit('4006381333932'), isFalse);
      expect(hasValidCheckDigit('036000291453'), isFalse);
    });

    test('rejects non-digits and bad lengths', () {
      expect(hasValidCheckDigit('40063813339X1'), isFalse);
      expect(hasValidCheckDigit('1234567'), isFalse);
    });
  });

  group('barcodeVariants', () {
    test('a UPC-A scan also matches the EAN-13 spelling and back', () {
      expect(
        barcodeVariants('036000291452'),
        containsAll(<String>['0036000291452', '036000291452']),
      );
      expect(
        barcodeVariants('0036000291452'),
        containsAll(<String>['0036000291452', '036000291452']),
      );
    });

    test('a plain EAN-13 has no UPC-A twin', () {
      expect(barcodeVariants('4006381333931'), <String>['4006381333931']);
    });

    test('custom codes stay as typed', () {
      expect(barcodeVariants(' 123 '), <String>['123']);
    });
  });
}
