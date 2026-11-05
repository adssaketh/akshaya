/// Minimal CSV writer (RFC 4180 quoting) for the exports.
abstract final class Csv {
  /// Rows of cells joined into one CSV text, CRLF line ends. Cells are
  /// strings, numbers or null. Text that a spreadsheet would run as a formula
  /// (starting with `=`, `+`, `-` or `@`) gets a leading apostrophe.
  static String encode(List<List<Object?>> rows) {
    final StringBuffer out = StringBuffer();
    for (final List<Object?> row in rows) {
      out.write(row.map(_cell).join(','));
      out.write('\r\n');
    }
    return out.toString();
  }

  static String _cell(Object? value) {
    if (value == null) {
      return '';
    }
    if (value is num) {
      return value == value.truncateToDouble()
          ? value.toInt().toString()
          : value.toString();
    }
    String text = value.toString();
    if (text.isNotEmpty && '=+-@'.contains(text[0])) {
      text = "'$text";
    }
    final bool needsQuotes = text.contains(',') ||
        text.contains('"') ||
        text.contains('\n') ||
        text.contains('\r');
    if (!needsQuotes) {
      return text;
    }
    return '"${text.replaceAll('"', '""')}"';
  }
}
