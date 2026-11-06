import '../../commands/domain/grocery_lexicon.dart';
import '../../commands/domain/text_normalizer.dart';
import '../../pantry/domain/storage_location.dart';
import 'order_models.dart';

/// What a product line turned out to be.
final class OrderClassification {
  const OrderClassification({
    required this.name,
    required this.categoryId,
    required this.location,
    this.brand,
    this.skip,
    this.matched = false,
    this.matchedItemId,
    this.estimateDays,
  });

  /// English pantry name.
  final String name;
  final String? brand;
  final String categoryId;
  final StorageLocation location;

  /// Set for non-food and non-vegetarian lines.
  final SkipReason? skip;

  /// True when the product was recognised from the dictionary or the pantry
  /// (false means it was named from the printed text alone).
  final bool matched;

  /// The existing pantry item the line belongs to, if any.
  final String? matchedItemId;

  /// Days fresh food usually keeps, as a guess.
  final int? estimateDays;
}

/// Names a product line, files it under a category and decides whether it is
/// food. Works offline from the bundled dictionary and the pantry. Pure Dart.
final class OrderClassifier {
  const OrderClassifier(this.lexicon);

  final GroceryLexicon lexicon;

  static const List<String> _brands = <String>[
    'tata sampann',
    'tata salt',
    'tata',
    'catch',
    'orika',
    'amruth raj',
    'whole farm',
    'everest',
    "sid's farm",
    'akshayakalpa',
    'henfruit',
    'popular essentials',
    'conscious food',
    "mother's recipe",
    'the select aisle',
    'zepbake',
    'basic',
    'organic india',
    "baker's loaf",
    'wishcare',
    'aashirvaad',
    'india gate',
    'fortune',
    'saffola',
    'amul',
    'mother dairy',
    'nandini',
    'britannia',
    'parle',
    'haldiram',
    'mdh',
    'maggi',
    'nestle',
    'patanjali',
    '24 mantra',
    'pillsbury',
    'sunfeast',
    "kellogg's",
    'bb royal',
    'dabur',
    'dettol',
    'harpic',
  ];

  /// Words that turn a known product into a different product ("Chilli
  /// Powder" is not "Chilli").
  static const List<String> _veto = <String>[
    'masala',
    'powder',
    'seeds',
    'flour',
    'oil',
    'paste',
    'sauce',
    'pickle',
    'chips',
    'ketchup',
    'puree',
    'jam',
    'juice',
    'soup',
    'chutney',
    'mayonnaise',
  ];

  static const List<String> _cleaning = <String>[
    'harpic',
    'lizol',
    'vim',
    'detergent',
    'cleaner',
    'dishwash',
    'toilet',
    'floor',
    'garbage',
    'surf excel',
    'ariel',
  ];
  static const List<String> _personalCare = <String>[
    'dettol',
    'soap',
    'shampoo',
    'conditioner',
    'toothpaste',
    'toothbrush',
    'wishcare',
    'serum',
    'dandruff',
    'lotion',
    'sanitizer',
    'tissue',
    'handwash',
    'hand wash',
    'hand wa',
    'facewash',
    'face wash',
  ];
  static const List<String> _otherNonFood = <String>[
    'paper',
    'foil',
    'thermometer',
    'battery',
    'batteries',
    'candle',
    'matchbox',
    'bulb',
    'napkin',
    'diaper',
    'brush',
  ];
  static const List<String> _nonVeg = <String>[
    'chicken',
    'mutton',
    'fish',
    'prawn',
    'prawns',
    'shrimp',
    'lamb',
    'beef',
    'pork',
    'crab',
    'bacon',
    'sausage',
    'salami',
    'keema',
    'meat',
    'seafood',
    'tuna',
    'salmon',
    'ham',
  ];
  static const List<String> _spiceWords = <String>[
    'masala',
    'powder',
    'spice',
    'seasoning',
    'flavour',
    'flavor',
    'marinade',
  ];

  /// First keyword list that matches decides the category.
  static const List<(String, List<String>)> _keywords =
      <(String, List<String>)>[
    (
      'cat_other',
      <String>['ketchup', 'sauce', 'mayonnaise', 'jam', 'soup', 'puree', 'chutney']
    ),
    (
      'cat_spices',
      <String>[
        'masala',
        'seeds',
        'chilli powder',
        'baking powder',
        'baking soda',
        'salt',
        'jaggery',
        'sugar',
        'turmeric',
        'pepper',
        'cardamom',
        'clove',
        'cinnamon',
        'tamarind',
        'red chilli',
        'ajwain',
      ]
    ),
    (
      'cat_dals',
      <String>[
        'dal',
        'chana',
        'rajma',
        'moong',
        'urad',
        'toor',
        'masoor',
        'lentil',
        'chickpea',
      ]
    ),
    (
      'cat_grains',
      <String>[
        'rice',
        'atta',
        'flour',
        'maida',
        'rava',
        'sooji',
        'poha',
        'oats',
        'ragi',
        'jowar',
        'bajra',
        'besan',
        'vermicelli',
        'noodles',
        'pasta',
        'millet',
      ]
    ),
    ('cat_oils', <String>['oil', 'ghee']),
    (
      'cat_dairy',
      <String>[
        'milk',
        'curd',
        'dahi',
        'paneer',
        'cheese',
        'butter',
        'buttermilk',
        'yogurt',
        'yoghurt',
      ]
    ),
    ('cat_frozen', <String>['ice cream', 'frozen']),
    ('cat_bakery', <String>['bread', 'bun', 'pav', 'rusk', 'cake']),
    (
      'cat_snacks',
      <String>[
        'chips',
        'biscuit',
        'namkeen',
        'chocolate',
        'choco',
        'cookies',
        'cashew',
        'almond',
        'raisin',
        'peanut',
        'popcorn',
        'wafer',
        'bhujia',
        'nuts',
      ]
    ),
    (
      'cat_beverages',
      <String>[
        'tea',
        'coffee',
        'juice',
        'drink',
        'cola',
        'soda',
        'horlicks',
        'bournvita',
      ]
    ),
    (
      'cat_fruits',
      <String>[
        'banana',
        'apple',
        'mango',
        'orange',
        'grapes',
        'pomegranate',
        'papaya',
        'watermelon',
        'guava',
        'pineapple',
        'sapota',
        'kiwi',
        'strawberry',
        'melon',
        'berries',
        'pear',
      ]
    ),
    (
      'cat_vegetables',
      <String>[
        'onion',
        'tomato',
        'potato',
        'garlic',
        'ginger',
        'chilli',
        'capsicum',
        'brinjal',
        'okra',
        'cabbage',
        'cauliflower',
        'carrot',
        'beans',
        'cucumber',
        'spinach',
        'mint',
        'lemon',
        'gourd',
        'pumpkin',
        'beetroot',
        'radish',
        'peas',
        'mushroom',
        'coriander',
      ]
    ),
  ];

  /// Vegetables that keep best outside the fridge.
  static const List<String> _roots = <String>[
    'onion',
    'potato',
    'garlic',
    'sweet potato',
    'ginger',
  ];

  static final RegExp _openBracket = RegExp(r'\(\s*[^)]*$');
  static final RegExp _trailingComma = RegExp(r'[,;]+$');

  OrderClassification classify(
    String rawName, {
    List<String> hints = const <String>[],
    bool truncated = false,
  }) {
    final String clean = rawName.replaceAll(_openBracket, '').trim();
    final List<String> tokens = phraseTokens(clean);

    // Brand: the longest known brand at the start of the name.
    String? brand;
    List<String>? brandTokens;
    for (final String candidate in _brands) {
      final List<String> bt = phraseTokens(candidate);
      if (bt.isNotEmpty &&
          tokens.length >= bt.length &&
          _startsWith(tokens, bt) &&
          (brandTokens == null || bt.length > brandTokens.length)) {
        brand = candidate;
        brandTokens = bt;
      }
    }

    LexiconItem? entity = _singleProduct(tokens);
    if (entity == null && truncated && hints.isNotEmpty) {
      entity = _singleProduct(phraseTokens(hints.join(' ')));
    }
    if (entity != null) {
      final List<String> own = phraseTokens(entity.name);
      for (final String word in _veto) {
        if (tokens.contains(word) && !own.contains(word)) {
          entity = null;
          break;
        }
      }
    }

    SkipReason? skip;
    String category;
    if (_has(clean, _cleaning)) {
      skip = SkipReason.notFood;
      category = 'cat_cleaning';
    } else if (_has(clean, _personalCare)) {
      skip = SkipReason.notFood;
      category = 'cat_personal_care';
    } else if (_has(clean, _otherNonFood)) {
      skip = SkipReason.notFood;
      category = 'cat_other';
    } else if (_has(clean, _nonVeg) &&
        !_has(clean, _spiceWords) &&
        !(entity != null && entity.categoryId != 'cat_meat_eggs')) {
      skip = SkipReason.notVegetarian;
      category = 'cat_other';
    } else if (entity != null) {
      category = entity.categoryId ?? 'cat_other';
    } else {
      category = 'cat_other';
      for (final (String, List<String>) group in _keywords) {
        if (_has(clean, group.$2)) {
          category = group.$1;
          break;
        }
      }
    }

    final String name = entity != null && skip == null
        ? entity.name
        : _displayName(clean, brandTokens);
    final StorageLocation location = _locationFor(category, tokens);
    return OrderClassification(
      name: name,
      brand: brand == null ? null : titleCase(brand),
      categoryId: category,
      location: location,
      skip: skip,
      matched: entity != null && skip == null,
      matchedItemId: skip == null ? entity?.itemId : null,
      estimateDays: skip == null ? _estimateDays(category, tokens) : null,
    );
  }

  /// The one product named in [tokens], or null when none or several are.
  LexiconItem? _singleProduct(List<String> tokens) {
    final Map<String, LexiconItem> found = <String, LexiconItem>{};
    int i = 0;
    while (i < tokens.length) {
      final LexiconHit? hit = lexicon.lookup(tokens, i, allowLoose: false);
      if (hit != null) {
        found.putIfAbsent(hit.item.name, () => hit.item);
        i += hit.tokenCount;
      } else {
        i += 1;
      }
    }
    return found.length == 1 ? found.values.first : null;
  }

  static bool _startsWith(List<String> tokens, List<String> prefix) {
    for (int i = 0; i < prefix.length; i++) {
      if (tokens[i] != prefix[i]) {
        return false;
      }
    }
    return true;
  }

  static bool _has(String text, List<String> words) {
    final String padded = ' ${phraseTokens(text).join(' ')} ';
    for (final String word in words) {
      final String key = phraseTokens(word).join(' ');
      if (key.isNotEmpty && padded.contains(' $key ')) {
        return true;
      }
    }
    return false;
  }

  /// The printed name without the brand (unless the brand is all there is).
  static String _displayName(String clean, List<String>? brandTokens) {
    String body = clean.replaceAll(_trailingComma, '').trim();
    if (brandTokens != null) {
      final String pattern =
          '^${brandTokens.map(RegExp.escape).join(r'\W+')}\\W*';
      final RegExpMatch? m =
          RegExp(pattern, caseSensitive: false).firstMatch(clean);
      if (m != null) {
        final String rest = clean.substring(m.end).trim();
        if (RegExp('[A-Za-z]').allMatches(rest).length >= 3) {
          body = rest.replaceAll(_trailingComma, '').trim();
        }
      }
    }
    return titleCase(body);
  }

  static StorageLocation _locationFor(String category, List<String> tokens) {
    switch (category) {
      case 'cat_dairy':
      case 'cat_meat_eggs':
        return StorageLocation.fridge;
      case 'cat_frozen':
        return StorageLocation.freezer;
      case 'cat_vegetables':
        return tokens.any(_roots.contains)
            ? StorageLocation.pantry
            : StorageLocation.fridge;
      case 'cat_fruits':
        return StorageLocation.fridge;
      default:
        return StorageLocation.pantry;
    }
  }

  /// A rough "keeps for" guess for fresh food; packaged goods carry a printed
  /// date, so they get none.
  static int? _estimateDays(String category, List<String> tokens) {
    switch (category) {
      case 'cat_vegetables':
        return tokens.any(_roots.contains) ? 14 : 5;
      case 'cat_fruits':
        return 5;
      case 'cat_dairy':
        return tokens.contains('milk') || tokens.contains('curd') ? 3 : null;
      case 'cat_bakery':
        return 3;
      case 'cat_meat_eggs':
        return tokens.contains('eggs') || tokens.contains('egg') ? 14 : null;
      default:
        return null;
    }
  }
}
