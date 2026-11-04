/// Barcode helpers shared by scanning and the pantry database.
///
/// Retail barcodes come as EAN-8, UPC-A (12 digits), EAN-13 and GTIN-14. A
/// UPC-A code is the same product as its EAN-13 with a leading zero, so codes
/// are stored in one canonical form.
library;

const Set<int> _kAcceptedLengths = <int>{8, 12, 13, 14};

final RegExp _separators = RegExp(r'[\s-]');
final RegExp _digitsOnly = RegExp(r'^\d+$');

/// The canonical digits of [raw], or null when it is not a plausible retail
/// barcode. Spaces and dashes are ignored.
///
/// Canonical form: UPC-A becomes EAN-13 (leading zero added) and a GTIN-14
/// with a leading zero becomes EAN-13. EAN-8 and other GTIN-14 stay as they
/// are.
String? normalizeBarcode(String raw) {
  final String digits = raw.replaceAll(_separators, '');
  if (!_digitsOnly.hasMatch(digits) ||
      !_kAcceptedLengths.contains(digits.length)) {
    return null;
  }
  if (digits.length == 12) {
    return '0$digits';
  }
  if (digits.length == 14 && digits.startsWith('0')) {
    return digits.substring(1);
  }
  return digits;
}

/// The form to store: the canonical digits when [raw] is a retail barcode,
/// otherwise the trimmed text (a shop's own label code, for example).
String canonicalBarcode(String raw) => normalizeBarcode(raw) ?? raw.trim();

/// True when the last digit is the correct GS1 check digit for the others.
bool hasValidCheckDigit(String digits) {
  if (digits.length < 8 || digits.length > 14 || !_digitsOnly.hasMatch(digits)) {
    return false;
  }
  int sum = 0;
  int weight = 3;
  for (int i = digits.length - 2; i >= 0; i--) {
    sum += int.parse(digits[i]) * weight;
    weight = weight == 3 ? 1 : 3;
  }
  final int expected = (10 - sum % 10) % 10;
  return expected == int.parse(digits[digits.length - 1]);
}

/// Every spelling under which the same product may have been saved, so a scan
/// finds items whose barcode was typed in another form.
List<String> barcodeVariants(String raw) {
  final String code = canonicalBarcode(raw);
  final Set<String> variants = <String>{code, raw.trim()};
  if (code.length == 13 && code.startsWith('0')) {
    variants.add(code.substring(1)); // UPC-A
    variants.add('0$code'); // GTIN-14
  }
  variants.remove('');
  return variants.toList(growable: false);
}
