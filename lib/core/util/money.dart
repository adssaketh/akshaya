/// The default currency symbol.
const String kCurrencySymbol = '₹';

/// The symbol in use (a setting; the app root keeps it up to date).
String currentCurrencySymbol = kCurrencySymbol;

/// "₹120" for whole amounts, "₹120.50" otherwise.
String formatMoney(double amount) {
  final double rounded = (amount * 100).roundToDouble() / 100;
  final String body = rounded == rounded.truncateToDouble()
      ? rounded.toInt().toString()
      : rounded.toStringAsFixed(2);
  return '$currentCurrencySymbol$body';
}

/// Reads a price typed by a person: "1250", "1,250", "1,25,000" (Indian
/// grouping), "120.50", "₹120". Commas are thousands separators, never decimal
/// points, so "1,250" is 1250. Returns null when the text is empty or not a
/// number; the caller decides whether a negative amount is acceptable.
double? parseMoney(String input) {
  String text = input.trim();
  for (final String symbol in <String>{currentCurrencySymbol, kCurrencySymbol}) {
    if (text.startsWith(symbol)) {
      text = text.substring(symbol.length);
      break;
    }
  }
  text = text.replaceAll(',', '').replaceAll(RegExp(r'\s'), '');
  if (text.isEmpty) {
    return null;
  }
  final double? value = double.tryParse(text);
  if (value == null || !value.isFinite) {
    return null;
  }
  return value;
}
