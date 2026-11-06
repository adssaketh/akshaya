/// Removes things that must never end up in a log that a person may share:
/// e-mail addresses, API keys and tokens. Also keeps messages and stack
/// traces to a sensible size.
abstract final class DiagRedactor {
  static final RegExp _email =
      RegExp(r'[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}');
  static final RegExp _apiKey = RegExp(r'AIza[0-9A-Za-z_\-]{20,}');
  static final RegExp _bearer =
      RegExp(r'Bearer\s+[A-Za-z0-9._\-]+', caseSensitive: false);
  static final RegExp _secretParam = RegExp(
    r'([?&](?:key|token|api_key|apikey|access_token|id_token)=)[^&\s]+',
    caseSensitive: false,
  );

  /// [text] with secrets replaced and cut to [maxLength] characters.
  static String clean(String text, {int maxLength = 600}) {
    final String safe = text
        .replaceAll(_email, '<email>')
        .replaceAll(_apiKey, '<key>')
        .replaceAll(_bearer, 'Bearer <token>')
        .replaceAllMapped(_secretParam, (Match m) => '${m[1]}<redacted>');
    if (safe.length <= maxLength) {
      return safe;
    }
    return '${safe.substring(0, maxLength)}...';
  }

  /// The first [maxLines] lines of a stack trace.
  static String trimStack(String stack, {int maxLines = 30}) {
    final List<String> lines = stack
        .split('\n')
        .where((String line) => line.trim().isNotEmpty)
        .toList();
    if (lines.length <= maxLines) {
      return lines.join('\n');
    }
    final int more = lines.length - maxLines;
    return '${lines.take(maxLines).join('\n')}\n... ($more more lines)';
  }
}
