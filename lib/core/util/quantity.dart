/// Quantity helpers shared by domain, data and presentation code.
library;

/// Quantities smaller than this are treated as zero.
const double kQtyEpsilon = 0.0005;

/// Rounds to three decimals so repeated deductions never leave float dust
/// such as 0.30000000000000004.
double roundQty(double value) => (value * 1000).roundToDouble() / 1000;

/// True when [value] is effectively zero (or negative).
bool isZeroQty(double value) => value < kQtyEpsilon;

/// Plain number text without trailing zeros: 2 -> "2", 1.50 -> "1.5".
String formatNumber(double value) {
  final double r = roundQty(value);
  if (r == r.truncateToDouble()) {
    return r.toInt().toString();
  }
  String text = r.toStringAsFixed(3);
  text = text.replaceFirst(RegExp(r'0+$'), '');
  if (text.endsWith('.')) {
    text = text.substring(0, text.length - 1);
  }
  return text;
}

const Map<String, double> _fractionGlyphs = <String, double>{
  '¼': 0.25,
  '½': 0.5,
  '¾': 0.75,
};

/// Parses what a person types into a quantity field.
///
/// Accepts "2", "1.5", "1,5", "1/2", "½", "¼", "1½" and surrounding spaces.
/// Returns null when the text is not a number.
double? parseQuantity(String input) {
  String text = input.trim();
  if (text.isEmpty) {
    return null;
  }
  text = text.replaceAll(',', '.');

  for (final MapEntry<String, double> glyph in _fractionGlyphs.entries) {
    if (text.endsWith(glyph.key)) {
      final String head =
          text.substring(0, text.length - glyph.key.length).trim();
      if (head.isEmpty) {
        return glyph.value;
      }
      final double? whole = double.tryParse(head);
      return whole == null ? null : whole + glyph.value;
    }
  }

  if (text.contains('/')) {
    final List<String> parts = text.split('/');
    if (parts.length != 2) {
      return null;
    }
    final double? numerator = double.tryParse(parts[0].trim());
    final double? denominator = double.tryParse(parts[1].trim());
    if (numerator == null || denominator == null || denominator == 0) {
      return null;
    }
    return numerator / denominator;
  }

  final double? value = double.tryParse(text);
  if (value == null || value.isNaN || value.isInfinite) {
    return null;
  }
  return value;
}
