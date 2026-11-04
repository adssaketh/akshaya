/// Currency symbol. Becomes a setting in Phase 8.
const String kCurrencySymbol = '₹';

/// "₹120" for whole amounts, "₹120.50" otherwise.
String formatMoney(double amount) {
  final double rounded = (amount * 100).roundToDouble() / 100;
  final String body = rounded == rounded.truncateToDouble()
      ? rounded.toInt().toString()
      : rounded.toStringAsFixed(2);
  return '$kCurrencySymbol$body';
}
