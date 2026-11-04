import 'package:akshaya/core/util/date_only.dart';
import 'package:akshaya/core/util/quantity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('dates', () {
    test('dateOnly drops time of day', () {
      expect(dateOnly(DateTime(2026, 11, 4, 23, 59)), DateTime(2026, 11, 4));
    });

    test('daysBetween counts calendar days across midnight', () {
      expect(daysBetween(DateTime(2026, 11, 4, 23, 59), DateTime(2026, 11, 5)), 1);
      expect(daysBetween(DateTime(2026, 11, 4), DateTime(2026, 11, 4, 23)), 0);
      expect(daysBetween(DateTime(2026, 11, 4), DateTime(2026, 11, 1)), -3);
    });

    test('addMonths clamps to month end', () {
      expect(addMonths(DateTime(2026, 1, 31), 1), DateTime(2026, 2, 28));
      expect(addMonths(DateTime(2028, 1, 31), 1), DateTime(2028, 2, 29));
      expect(addMonths(DateTime(2026, 11, 15), 3), DateTime(2027, 2, 15));
    });

    test('formatDate', () {
      expect(formatDate(DateTime(2026, 11, 4)), '4 Nov 2026');
    });
  });

  group('quantity', () {
    test('parseQuantity accepts common inputs', () {
      expect(parseQuantity('2'), 2);
      expect(parseQuantity('1,5'), 1.5);
      expect(parseQuantity('1/2'), 0.5);
      expect(parseQuantity('½'), 0.5);
      expect(parseQuantity('1½'), 1.5);
      expect(parseQuantity(' 3 '), 3);
    });

    test('parseQuantity rejects junk', () {
      expect(parseQuantity(''), isNull);
      expect(parseQuantity('abc'), isNull);
      expect(parseQuantity('1/0'), isNull);
    });

    test('roundQty and isZeroQty', () {
      expect(roundQty(0.1 + 0.2), 0.3);
      expect(isZeroQty(0.0001), isTrue);
      expect(isZeroQty(0.001), isFalse);
    });

    test('formatNumber trims trailing zeros', () {
      expect(formatNumber(2), '2');
      expect(formatNumber(1.5), '1.5');
    });
  });
}
