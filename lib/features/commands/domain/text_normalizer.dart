/// Text helpers for the offline command parser. Pure Dart, no Flutter.
///
/// Spoken and typed commands arrive in English, Telugu and Hindi, in native
/// script or romanised, so every comparison goes through [normalizeText] first.
library;

/// Characters that carry no meaning for matching: zero-width joiners and the
/// Devanagari nukta (so "ज़" and "ज" match, as people type both).
const int _zeroWidthNonJoiner = 0x200C;
const int _zeroWidthJoiner = 0x200D;
const int _devanagariNukta = 0x093C;

/// Precomposed Devanagari letters with a nukta, mapped to their plain letter.
const Map<int, int> _nuktaLetters = <int, int>{
  0x0958: 0x0915,
  0x0959: 0x0916,
  0x095A: 0x0917,
  0x095B: 0x091C,
  0x095C: 0x0921,
  0x095D: 0x0922,
  0x095E: 0x092B,
  0x095F: 0x092F,
};

/// Lower-cases and folds spelling variants so equal words compare equal:
/// no zero-width characters or nukta, Devanagari and Telugu digits as ASCII
/// digits, and candrabindu as anusvara.
String normalizeText(String input) {
  final StringBuffer out = StringBuffer();
  for (final int rune in input.toLowerCase().runes) {
    if (rune == _zeroWidthNonJoiner ||
        rune == _zeroWidthJoiner ||
        rune == _devanagariNukta) {
      continue;
    }
    int mapped = _nuktaLetters[rune] ?? rune;
    if (mapped >= 0x0966 && mapped <= 0x096F) {
      mapped = 0x30 + (mapped - 0x0966);
    } else if (mapped >= 0x0C66 && mapped <= 0x0C6F) {
      mapped = 0x30 + (mapped - 0x0C66);
    } else if (mapped == 0x0901) {
      mapped = 0x0902;
    } else if (mapped == 0x0C01) {
      mapped = 0x0C02;
    }
    out.writeCharCode(mapped);
  }
  return out.toString();
}

/// Letters (with their vowel signs), numbers such as "1.5", "1,5" and "1/2",
/// the fraction glyphs, and the characters that separate commands.
final RegExp _tokenPattern = RegExp(
  r'[\p{L}\p{M}]+|\d+(?:[.,/]\d+)?|[½¼¾]|[,;.।|\n&+]',
  unicode: true,
);

/// Tokens that end one command and start the next.
const Set<String> kSeparatorTokens = <String>{
  ',',
  ';',
  '.',
  '।',
  '|',
  '\n',
  '&',
  '+',
};

/// Splits [input] into normalised tokens (words, numbers and separators).
List<String> tokenize(String input) {
  return <String>[
    for (final Match m in _tokenPattern.allMatches(normalizeText(input)))
      m.group(0)!,
  ];
}

/// The words of [input] without separator tokens.
List<String> phraseTokens(String input) {
  return <String>[
    for (final String t in tokenize(input))
      if (!kSeparatorTokens.contains(t)) t,
  ];
}

final RegExp _latinWord = RegExp(r'^[a-z]+$');

/// True for a word written only with the letters a to z.
bool isLatinWord(String token) => _latinWord.hasMatch(token);

final RegExp _repeatedLetters = RegExp(r'(.)\1+');
final RegExp _silentH = RegExp(r'(?<=[bdgkpts])h');

/// A spelling-insensitive key for romanised words, so "biyyam", "biyyamu" and
/// "biyam" meet: repeated letters collapse, w/v and z/j merge, an h after
/// b d g k p t s is dropped, and a trailing "u" on longer words is dropped.
String phoneticKey(String token) {
  String key = token.replaceAllMapped(
    _repeatedLetters,
    (Match m) => m.group(1)!,
  );
  key = key.replaceAll('w', 'v').replaceAll('z', 'j');
  key = key.replaceAll(_silentH, '');
  if (key.length > 4 && key.endsWith('u')) {
    key = key.substring(0, key.length - 1);
  }
  return key;
}

/// [phoneticKey] of every token, joined by spaces.
String phoneticPhraseKey(List<String> tokens) {
  return tokens.map(phoneticKey).join(' ');
}

/// Capitalises the first letter of every space-separated word. Letters in
/// other scripts are left as they are.
String titleCase(String text) {
  return text
      .split(' ')
      .map(
        (String word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1)}',
      )
      .join(' ');
}
