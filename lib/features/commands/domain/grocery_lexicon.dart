import '../../pantry/domain/entities.dart';
import '../../pantry/domain/unit.dart';
import 'grocery_dictionary.dart';
import 'text_normalizer.dart';

/// What a word or phrase stands for: a pantry item or a dictionary product.
final class LexiconItem {
  const LexiconItem({
    required this.name,
    this.categoryId,
    this.unit,
    this.itemId,
  });

  /// English name (the pantry item's own name when [itemId] is set).
  final String name;
  final String? categoryId;

  /// The unit it is usually counted in.
  final Unit? unit;

  /// Set when the product is already in the pantry.
  final String? itemId;
}

/// A match at the start of some tokens.
final class LexiconHit {
  const LexiconHit(this.item, this.tokenCount);

  final LexiconItem item;

  /// How many tokens the match used.
  final int tokenCount;
}

/// Every word the parser knows for a product: the bundled dictionary plus the
/// names and aliases of the person's own pantry items. Pantry words win, and
/// a dictionary product that the pantry already has (for example "rice" when
/// the pantry has "Basmati Rice" with the alias "biyyam") points at that
/// pantry item, so a command never creates a second copy.
final class GroceryLexicon {
  GroceryLexicon._(this._exact, this._phonetic);

  /// Builds the lexicon for the dictionary and the pantry's [items].
  factory GroceryLexicon.build(
    GroceryDictionary dictionary, {
    List<Item> items = const <Item>[],
  }) {
    final Map<String, LexiconItem> exact = <String, LexiconItem>{};

    // Which pantry item, if any, stands for each dictionary product.
    final Map<int, (int, Item)> links = <int, (int, Item)>{};
    for (int e = 0; e < dictionary.entries.length; e++) {
      final DictionaryEntry entry = dictionary.entries[e];
      final Set<String> keys = _entryKeys(entry);
      final String nameKey = _phraseKey(entry.name);
      final List<String> entryTokens = phraseTokens(entry.name);
      for (final Item item in items) {
        final String itemKey = _phraseKey(item.name);
        final Set<String> aliasKeys = <String>{
          for (final String alias in item.aliases) _phraseKey(alias),
        };
        int score = 0;
        if (itemKey == nameKey) {
          score = 3;
        } else if (keys.contains(itemKey) ||
            aliasKeys.intersection(keys).isNotEmpty) {
          score = 2;
        } else {
          // "Basmati Rice" is a kind of "Rice": same last word.
          final List<String> itemTokens = phraseTokens(item.name);
          if (entryTokens.length == 1 &&
              itemTokens.length > 1 &&
              itemTokens.last == entryTokens.first) {
            score = 1;
          }
        }
        final (int, Item)? best = links[e];
        if (score > 0 && (best == null || score > best.$1)) {
          links[e] = (score, item);
        }
      }
    }

    void put(String key, LexiconItem value, {bool override = false}) {
      if (key.isEmpty) {
        return;
      }
      if (override || !exact.containsKey(key)) {
        exact[key] = value;
      }
    }

    for (int e = 0; e < dictionary.entries.length; e++) {
      final DictionaryEntry entry = dictionary.entries[e];
      final (int, Item)? link = links[e];
      final LexiconItem value = link == null
          ? LexiconItem(
              name: entry.name,
              categoryId: entry.categoryId,
              unit: entry.unit,
            )
          : _fromItem(link.$2);
      for (final String key in _entryKeys(entry)) {
        put(key, value);
      }
    }
    for (final Item item in items) {
      final LexiconItem value = _fromItem(item);
      put(_phraseKey(item.name), value, override: true);
      for (final String alias in item.aliases) {
        put(_phraseKey(alias), value, override: true);
      }
    }

    final Map<String, LexiconItem> phonetic = <String, LexiconItem>{};
    for (final MapEntry<String, LexiconItem> entry in exact.entries) {
      final List<String> tokens = entry.key.split(' ');
      if (tokens.every(isLatinWord)) {
        phonetic.putIfAbsent(phoneticPhraseKey(tokens), () => entry.value);
      }
    }
    return GroceryLexicon._(exact, phonetic);
  }

  final Map<String, LexiconItem> _exact;
  final Map<String, LexiconItem> _phonetic;

  /// The longest meaning that starts at [tokens] index [start], or null.
  ///
  /// With [allowLoose] false only exact spellings match. The parser uses that
  /// for function words ("cheyyi", "khatam"), which must never be mistaken for
  /// an item because they sound a little like one.
  LexiconHit? lookup(
    List<String> tokens,
    int start, {
    bool allowLoose = true,
  }) {
    final int remaining = tokens.length - start;
    final int limit = remaining < _maxItemTokens ? remaining : _maxItemTokens;
    for (int n = limit; n >= 1; n--) {
      final List<String> candidate = tokens.sublist(start, start + n);
      if (candidate.any(_isNumberOrSeparator)) {
        continue;
      }
      final LexiconItem? exact = _exact[candidate.join(' ')];
      if (exact != null) {
        return LexiconHit(exact, n);
      }
      if (allowLoose && candidate.every(isLatinWord)) {
        final int letters =
            candidate.fold<int>(0, (int sum, String t) => sum + t.length);
        if (letters >= 4) {
          final LexiconItem? sounds =
              _phonetic[phoneticPhraseKey(candidate)];
          if (sounds != null) {
            return LexiconHit(sounds, n);
          }
        }
      }
      if (n == 1 && allowLoose) {
        final LexiconItem? stemmed = _lookupStems(candidate.first);
        if (stemmed != null) {
          return LexiconHit(stemmed, 1);
        }
      }
    }
    return null;
  }

  /// The item that [phrase] names as a whole (every word used), or null.
  LexiconItem? lookupPhrase(String phrase) {
    final List<String> tokens = phraseTokens(phrase);
    if (tokens.isEmpty) {
      return null;
    }
    final LexiconHit? hit = lookup(tokens, 0);
    if (hit == null || hit.tokenCount != tokens.length) {
      return null;
    }
    return hit.item;
  }

  static const int _maxItemTokens = 4;

  static bool _isNumberOrSeparator(String token) {
    return kSeparatorTokens.contains(token) ||
        (token.isNotEmpty && '0123456789'.contains(token[0]));
  }

  LexiconItem? _lookupStems(String token) {
    for (final String stem in _stems(token)) {
      final LexiconItem? exact = _exact[stem];
      if (exact != null) {
        return exact;
      }
      if (isLatinWord(stem) && stem.length >= 4) {
        final LexiconItem? sounds = _phonetic[phoneticKey(stem)];
        if (sounds != null) {
          return sounds;
        }
      }
    }
    return null;
  }

  /// Plural and case endings removed: "tomatoes", "ullipayalu", "టమాటాలు".
  static List<String> _stems(String token) {
    final List<String> stems = <String>[];
    if (isLatinWord(token)) {
      if (token.endsWith('alu') && token.length > 5) {
        stems.add(token.substring(0, token.length - 3));
      }
      if (token.endsWith('lu') && token.length > 4) {
        stems.add(token.substring(0, token.length - 2));
      }
      if (token.endsWith('es') && token.length > 4) {
        stems.add(token.substring(0, token.length - 2));
      }
      if (token.endsWith('s') && token.length > 3) {
        stems.add(token.substring(0, token.length - 1));
      }
    } else {
      // Telugu plural "లు" and "లో" (in).
      if (token.endsWith('లు') && token.length > 3) {
        stems.add(token.substring(0, token.length - 2));
      }
      if (token.endsWith('లో') && token.length > 3) {
        stems.add(token.substring(0, token.length - 2));
      }
    }
    return stems;
  }

  static LexiconItem _fromItem(Item item) {
    return LexiconItem(
      name: item.name,
      categoryId: item.categoryId,
      unit: item.defaultUnit,
      itemId: item.id,
    );
  }

  static String _phraseKey(String text) => phraseTokens(text).join(' ');

  /// The English name and every form of [entry], as matching keys.
  static Set<String> _entryKeys(DictionaryEntry entry) {
    return <String>{
      _phraseKey(entry.name),
      for (final String form in entry.forms) _phraseKey(form),
    };
  }
}
