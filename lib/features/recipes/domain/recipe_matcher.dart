import '../../../core/util/quantity.dart';
import '../../commands/domain/grocery_lexicon.dart';
import '../../commands/domain/text_normalizer.dart';
import '../../pantry/domain/unit.dart';
import 'recipe_models.dart';
import 'recipe_pantry.dart';

/// How a recipe's ingredient stands against the pantry.
enum IngredientAvailability {
  /// Matched to a pantry item with enough cookable stock (or the recipe gives
  /// no amount we can compare).
  inPantry,

  /// Matched, but there is less than the recipe needs.
  short,

  /// Not in the pantry, or only out of stock or expired.
  missing,

  /// Water and salt: assumed to be in every kitchen, never shopped for or
  /// deducted.
  assumed,
}

/// One ingredient and what the pantry has for it.
final class IngredientMatch {
  const IngredientMatch({
    required this.ingredient,
    required this.availability,
    this.line,
    this.needed,
  });

  final RecipeIngredient ingredient;
  final IngredientAvailability availability;

  /// The pantry item it was matched to (also set for an out-of-stock item, so
  /// a shopping entry can point at it).
  final PantryLine? line;

  /// What the recipe needs, in the matched item's unit. Null when the recipe
  /// gives no amount or its unit cannot be converted.
  final double? needed;

  String? get itemId => line?.itemId;

  /// How much more is needed than the pantry has, in the item's unit.
  double? get shortfall {
    final PantryLine? matched = line;
    final double? need = needed;
    if (availability != IngredientAvailability.short ||
        matched == null ||
        need == null) {
      return null;
    }
    return roundQty(need - matched.usable);
  }
}

/// Matches AI-written English ingredient names to the person's pantry items.
///
/// Names match when they are the same words (ignoring case, plurals, brackets
/// and word order), when one name is the other plus extra describing words
/// ("Rice" and "Basmati Rice"), through an item's aliases, or through the
/// bundled dictionary's synonyms ("Rava" and "Semolina"). Words that change
/// the product ("powder", "flour", "paste"...) stop a loose match. This is a
/// heuristic: the cooking confirmation lets the person correct any line.
final class RecipeMatcher {
  RecipeMatcher(this.lines, {this.lexicon})
      : _lineVariants = <List<List<String>>>[
          for (final PantryLine line in lines) _itemVariants(line),
        ];

  final List<PantryLine> lines;
  final GroceryLexicon? lexicon;
  final List<List<List<String>>> _lineVariants;

  /// Ingredients every kitchen is assumed to have.
  static const Set<String> assumedOnHand = <String>{'water', 'salt'};

  /// Extra words that make a different product, so "Chilli" must not match
  /// "Chilli Powder".
  static const Set<String> _identityWords = <String>{
    'powder',
    'flour',
    'paste',
    'sauce',
    'juice',
    'cream',
    'butter',
    'masala',
    'coconut',
    'mix',
    'essence',
    'syrup',
    'extract',
  };

  static final RegExp _punctuation =
      RegExp(r'[^\p{L}\p{M}\p{N}\s]', unicode: true);
  static final RegExp _brackets = RegExp(r'\(([^)]*)\)');
  static final RegExp _spaces = RegExp(r'\s+');

  /// Every ingredient of [recipe] with its availability.
  List<IngredientMatch> matchAll(Recipe recipe) {
    return <IngredientMatch>[
      for (final RecipeIngredient i in recipe.ingredients) match(i),
    ];
  }

  IngredientMatch match(RecipeIngredient ingredient) {
    final List<String> texts = _variantTexts(ingredient.name);
    final List<List<String>> wanted = <List<String>>[
      for (final String t in texts) _tokens(t),
    ];
    for (final List<String> tokens in wanted) {
      if (tokens.length == 1 && assumedOnHand.contains(tokens.first)) {
        return IngredientMatch(
          ingredient: ingredient,
          availability: IngredientAvailability.assumed,
        );
      }
    }

    final PantryLine? line = _find(ingredient, wanted, texts);
    if (line == null || !line.hasStock) {
      return IngredientMatch(
        ingredient: ingredient,
        availability: IngredientAvailability.missing,
        line: line,
        needed: line == null ? null : _needed(ingredient, line),
      );
    }
    final double? need = _needed(ingredient, line);
    final bool isShort = need != null && line.usable + kQtyEpsilon < need;
    return IngredientMatch(
      ingredient: ingredient,
      availability: isShort
          ? IngredientAvailability.short
          : IngredientAvailability.inPantry,
      line: line,
      needed: need,
    );
  }

  PantryLine? _find(
    RecipeIngredient ingredient,
    List<List<String>> wanted,
    List<String> texts,
  ) {
    final String? hint = ingredient.itemId;
    if (hint != null) {
      for (final PantryLine line in lines) {
        if (line.itemId == hint) {
          return line;
        }
      }
    }

    PantryLine? best;
    int bestScore = 0;
    for (int i = 0; i < lines.length; i++) {
      final int score = _score(wanted, _lineVariants[i]);
      if (score == 0) {
        continue;
      }
      final PantryLine line = lines[i];
      final bool better = best == null ||
          score > bestScore ||
          (score == bestScore && line.hasStock && !best.hasStock);
      if (better) {
        best = line;
        bestScore = score;
      }
    }
    if (best != null) {
      return best;
    }
    return _viaDictionary(texts);
  }

  PantryLine? _viaDictionary(List<String> texts) {
    final GroceryLexicon? dictionary = lexicon;
    if (dictionary == null) {
      return null;
    }
    for (final String text in texts) {
      final List<String> tokens = phraseTokens(text);
      if (tokens.isEmpty) {
        continue;
      }
      final LexiconHit? hit = dictionary.lookup(tokens, 0, allowLoose: false);
      final String? id = hit?.item.itemId;
      if (hit == null || hit.tokenCount != tokens.length || id == null) {
        continue;
      }
      for (final PantryLine line in lines) {
        if (line.itemId == id) {
          return line;
        }
      }
    }
    return null;
  }

  static double? _needed(RecipeIngredient ingredient, PantryLine line) {
    final double? quantity = ingredient.quantity;
    final Unit? unit = ingredient.unit;
    if (quantity == null || unit == null || !unit.isCompatibleWith(line.unit)) {
      return null;
    }
    return roundQty(unit.convertTo(quantity, line.unit));
  }

  /// 2 for the same words, 1 for a looser match, 0 for none.
  static int _score(List<List<String>> wanted, List<List<String>> candidates) {
    int best = 0;
    for (final List<String> w in wanted) {
      for (final List<String> c in candidates) {
        if (_sameWords(w, c)) {
          return 2;
        }
        if (best < 1 && _looseMatch(w, c)) {
          best = 1;
        }
      }
    }
    return best;
  }

  static bool _sameWords(List<String> a, List<String> b) {
    if (a.length != b.length) {
      return false;
    }
    return a.every(b.contains) && b.every(a.contains);
  }

  /// One name is the other plus describing words, none of which changes the
  /// product.
  static bool _looseMatch(List<String> a, List<String> b) {
    final bool aShorter = a.length <= b.length;
    final List<String> shorter = aShorter ? a : b;
    final List<String> longer = aShorter ? b : a;
    if (shorter.isEmpty || shorter.length == longer.length) {
      return false;
    }
    if (!shorter.every(longer.contains)) {
      return false;
    }
    for (final String word in longer) {
      if (!shorter.contains(word) && _identityWords.contains(word)) {
        return false;
      }
    }
    return true;
  }

  static List<List<String>> _itemVariants(PantryLine line) {
    final List<List<String>> out = <List<String>>[];
    final List<String> names = <String>[line.item.name, ...line.item.aliases];
    for (final String name in names) {
      for (final String text in _variantTexts(name)) {
        final List<String> tokens = _tokens(text);
        if (tokens.isNotEmpty) {
          out.add(tokens);
        }
      }
    }
    return out;
  }

  /// "Semolina (Rava)" is read as "Semolina" and as "Rava".
  static List<String> _variantTexts(String name) {
    final List<String> out = <String>[];
    final String outside = name.replaceAll(_brackets, ' ').trim();
    if (outside.isNotEmpty) {
      out.add(outside);
    }
    for (final Match m in _brackets.allMatches(name)) {
      final String inside = (m.group(1) ?? '').trim();
      if (inside.isNotEmpty) {
        out.add(inside);
      }
    }
    return out;
  }

  static List<String> _tokens(String text) {
    final String cleaned = text.toLowerCase().replaceAll(_punctuation, ' ');
    return <String>[
      for (final String t in cleaned.split(_spaces))
        if (t.isNotEmpty) _stem(t),
    ];
  }

  /// A rough singular, so that "tomatoes" and "tomato", "chillies", "chilly"
  /// and "chilli", or "peas" and "pea" compare equal. A final "y" is folded to
  /// "i" on both sides, which only has to be consistent, not pretty.
  static String _stem(String word) {
    String w = word;
    if (w.length > 4 && w.endsWith('ies')) {
      w = '${w.substring(0, w.length - 3)}i';
    } else if (w.length > 4 &&
        (w.endsWith('oes') ||
            w.endsWith('ches') ||
            w.endsWith('shes') ||
            w.endsWith('xes'))) {
      w = w.substring(0, w.length - 2);
    } else if (w.length > 3 && w.endsWith('s') && !w.endsWith('ss')) {
      w = w.substring(0, w.length - 1);
    }
    if (w.length > 3 && w.endsWith('y')) {
      w = '${w.substring(0, w.length - 1)}i';
    }
    return w;
  }
}

/// A recipe with its ingredients matched to the pantry, for display and
/// ranking.
final class RankedRecipe {
  const RankedRecipe({
    required this.recipe,
    required this.matches,
    required this.expiringUsed,
    this.soonestDays,
  });

  final Recipe recipe;
  final List<IngredientMatch> matches;

  /// Names of expiring pantry items this recipe uses, soonest first.
  final List<String> expiringUsed;

  /// Days left of the soonest expiring item used, or null when none is used.
  final int? soonestDays;

  /// Ingredients that are missing or short.
  int get missingCount {
    int count = 0;
    for (final IngredientMatch m in matches) {
      if (m.availability == IngredientAvailability.missing ||
          m.availability == IngredientAvailability.short) {
        count++;
      }
    }
    return count;
  }

  bool get canCookNow => missingCount == 0;
}

/// Orders recipes by how much expiring food they use up.
abstract final class RecipeRanker {
  /// Recipes using more expiring items come first, then those using the
  /// soonest-expiring one, then those with fewer missing ingredients, then the
  /// quicker ones; equal recipes keep the order the AI gave.
  static List<RankedRecipe> rank(
    List<Recipe> recipes,
    RecipeMatcher matcher, {
    required Map<String, int> expiringDays,
  }) {
    final List<RankedRecipe> ranked = <RankedRecipe>[
      for (final Recipe r in recipes) _rankOne(r, matcher, expiringDays),
    ];
    final List<int> order = List<int>.generate(ranked.length, (int i) => i);
    order.sort((int a, int b) {
      final RankedRecipe ra = ranked[a];
      final RankedRecipe rb = ranked[b];
      int c = rb.expiringUsed.length.compareTo(ra.expiringUsed.length);
      if (c != 0) {
        return c;
      }
      c = _dayKey(ra.soonestDays).compareTo(_dayKey(rb.soonestDays));
      if (c != 0) {
        return c;
      }
      c = ra.missingCount.compareTo(rb.missingCount);
      if (c != 0) {
        return c;
      }
      c = ra.recipe.timeMinutes.compareTo(rb.recipe.timeMinutes);
      if (c != 0) {
        return c;
      }
      return a.compareTo(b);
    });
    return <RankedRecipe>[for (final int i in order) ranked[i]];
  }

  static int _dayKey(int? days) => days ?? (1 << 30);

  static RankedRecipe _rankOne(
    Recipe recipe,
    RecipeMatcher matcher,
    Map<String, int> expiringDays,
  ) {
    final List<IngredientMatch> matches = matcher.matchAll(recipe);
    final Map<String, (int, String)> used = <String, (int, String)>{};
    for (final IngredientMatch m in matches) {
      final PantryLine? line = m.line;
      if (line == null || !line.hasStock) {
        continue;
      }
      final int? days = expiringDays[line.itemId];
      if (days != null) {
        used[line.itemId] = (days, line.name);
      }
    }
    final List<(int, String)> sorted = used.values.toList();
    sorted.sort(((int, String) a, (int, String) b) {
      final int c = a.$1.compareTo(b.$1);
      return c != 0 ? c : a.$2.compareTo(b.$2);
    });
    return RankedRecipe(
      recipe: recipe,
      matches: matches,
      expiringUsed: <String>[for (final (int, String) e in sorted) e.$2],
      soonestDays: sorted.isEmpty ? null : sorted.first.$1,
    );
  }
}
