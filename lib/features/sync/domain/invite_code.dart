import 'dart:math';

/// Household invite codes: eight characters from an alphabet without the
/// look-alikes (no 0/O or 1/I/L), shown as `ABCD-EFGH` and carried in a QR code
/// as `akshaya-join:ABCDEFGH`.
abstract final class InviteCode {
  static const String _alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

  static const int length = 8;

  static const String qrPrefix = 'akshaya-join:';

  /// A new random code.
  static String generate([Random? random]) {
    final Random source = random ?? Random.secure();
    final StringBuffer out = StringBuffer();
    for (int i = 0; i < length; i++) {
      out.write(_alphabet[source.nextInt(_alphabet.length)]);
    }
    return out.toString();
  }

  /// The canonical code for what a person typed or scanned (any case, with or
  /// without a dash or spaces, with or without the QR prefix), or null when it
  /// cannot be a code.
  static String? normalize(String input) {
    String text = input.trim();
    if (text.toLowerCase().startsWith(qrPrefix)) {
      text = text.substring(qrPrefix.length);
    }
    final String cleaned = text.toUpperCase().replaceAll(
          RegExp(r'[\s\-_]'),
          '',
        );
    if (cleaned.length != length) {
      return null;
    }
    for (final int unit in cleaned.codeUnits) {
      if (!_alphabet.contains(String.fromCharCode(unit))) {
        return null;
      }
    }
    return cleaned;
  }

  /// `ABCD-EFGH`.
  static String format(String code) {
    if (code.length != length) {
      return code;
    }
    return '${code.substring(0, 4)}-${code.substring(4)}';
  }

  /// The text a QR code carries.
  static String qrPayload(String code) => '$qrPrefix$code';
}
