import '../../../core/util/quantity.dart';
import '../../pantry/domain/default_categories.dart';
import '../../pantry/domain/unit.dart';

/// How much one pack holds, for example 500 g.
final class PackSize {
  const PackSize(this.amount, this.unit);

  final double amount;
  final Unit unit;
}

/// What Open Food Facts knows about a product, reduced to what Akshaya Patra
/// uses.
final class ProductInfo {
  const ProductInfo({
    required this.name,
    this.brand,
    this.quantityText,
    this.categoryTags = const <String>[],
  });

  /// Product name (English when Open Food Facts has one).
  final String name;
  final String? brand;

  /// Pack size as printed, for example "500 g" or "6 x 100 g".
  final String? quantityText;

  /// Open Food Facts category tags, for example `en:milks`.
  final List<String> categoryTags;

  /// [quantityText] as an amount and unit, or null when it cannot be read.
  PackSize? get packSize => parsePackSize(quantityText);

  /// The default category that best fits [categoryTags].
  String get suggestedCategoryId => categoryIdForTags(categoryTags);

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'name': name,
      'brand': brand,
      'quantity': quantityText,
      'categories': categoryTags,
    };
  }

  /// Reads what [toJson] wrote. Returns null for anything unusable.
  static ProductInfo? fromJson(Object? json) {
    if (json is! Map<String, Object?>) {
      return null;
    }
    final Object? name = json['name'];
    if (name is! String || name.trim().isEmpty) {
      return null;
    }
    final Object? brand = json['brand'];
    final Object? quantity = json['quantity'];
    final Object? categories = json['categories'];
    return ProductInfo(
      name: name.trim(),
      brand: brand is String && brand.trim().isNotEmpty ? brand.trim() : null,
      quantityText:
          quantity is String && quantity.trim().isNotEmpty ? quantity.trim() : null,
      categoryTags: categories is List<Object?>
          ? <String>[
              for (final Object? tag in categories)
                if (tag is String) tag,
            ]
          : const <String>[],
    );
  }
}

final RegExp _packPattern = RegExp(
  r'^\s*(?:(\d+)\s*[x×*]\s*)?(\d+(?:[.,]\d+)?)\s*'
  r'(kg|gm|gr|grams?|g|litres?|liters?|ltr|lt|l|ml|cl|dl|pcs|pc|pieces?|units?)'
  r'(?![a-z])',
  caseSensitive: false,
);

/// Reads a printed pack size such as "500 g", "1,5 L", "250ml" or
/// "6 x 100 g". Amounts of 1000 g or 1000 ml are shown as kg or L. Returns
/// null when nothing sensible is found.
PackSize? parsePackSize(String? text) {
  if (text == null) {
    return null;
  }
  final RegExpMatch? match = _packPattern.firstMatch(text);
  if (match == null) {
    return null;
  }
  final double? number = double.tryParse(match.group(2)!.replaceAll(',', '.'));
  if (number == null) {
    return null;
  }
  final double multiplier =
      match.group(1) == null ? 1 : double.parse(match.group(1)!);

  Unit unit;
  double amount = number * multiplier;
  switch (match.group(3)!.toLowerCase()) {
    case 'kg':
      unit = Unit.kg;
    case 'gm' || 'gr' || 'g' || 'gram' || 'grams':
      unit = Unit.g;
    case 'l' || 'lt' || 'ltr' || 'litre' || 'litres' || 'liter' || 'liters':
      unit = Unit.l;
    case 'ml':
      unit = Unit.ml;
    case 'cl':
      unit = Unit.ml;
      amount *= 10;
    case 'dl':
      unit = Unit.ml;
      amount *= 100;
    default:
      unit = Unit.pcs;
  }

  amount = roundQty(amount);
  if (amount <= 0) {
    return null;
  }
  if (unit == Unit.g && amount >= 1000) {
    return PackSize(roundQty(amount / 1000), Unit.kg);
  }
  if (unit == Unit.ml && amount >= 1000) {
    return PackSize(roundQty(amount / 1000), Unit.l);
  }
  return PackSize(amount, unit);
}

final class _CategoryRule {
  const _CategoryRule(this.categoryId, this.words);

  final String categoryId;
  final Set<String> words;
}

/// First match wins, so the order matters (for example milk is Dairy even
/// though Open Food Facts also lists it under beverages).
const List<_CategoryRule> _categoryRules = <_CategoryRule>[
  _CategoryRule('cat_frozen', <String>{'frozen'}),
  _CategoryRule('cat_meat_eggs', <String>{
    'meat',
    'meats',
    'poultry',
    'fish',
    'seafood',
    'chicken',
    'egg',
    'eggs',
  }),
  _CategoryRule('cat_oils', <String>{'oil', 'oils', 'ghee', 'clarified'}),
  _CategoryRule('cat_dairy', <String>{
    'milk',
    'milks',
    'dairy',
    'dairies',
    'yogurt',
    'yogurts',
    'yoghurt',
    'curd',
    'cheese',
    'cheeses',
    'butter',
    'butters',
    'paneer',
    'cream',
    'creams',
  }),
  _CategoryRule('cat_dals', <String>{
    'legumes',
    'pulses',
    'lentils',
    'lentil',
    'dal',
    'dals',
    'chickpeas',
    'beans',
  }),
  _CategoryRule('cat_spices', <String>{
    'spices',
    'spice',
    'masala',
    'masalas',
    'salt',
    'herbs',
    'seasonings',
  }),
  _CategoryRule('cat_snacks', <String>{
    'snacks',
    'snack',
    'chips',
    'crisps',
    'chocolates',
    'chocolate',
    'sweets',
    'confectioneries',
    'candies',
    'namkeen',
    'biscuits',
    'cookies',
  }),
  _CategoryRule('cat_bakery', <String>{
    'breads',
    'bread',
    'buns',
    'bakery',
    'cakes',
  }),
  _CategoryRule('cat_grains', <String>{
    'cereals',
    'rice',
    'rices',
    'flours',
    'flour',
    'wheat',
    'grains',
    'pasta',
    'noodles',
    'oats',
    'atta',
    'semolina',
  }),
  _CategoryRule('cat_beverages', <String>{
    'beverages',
    'beverage',
    'drinks',
    'juices',
    'juice',
    'teas',
    'tea',
    'coffees',
    'coffee',
    'waters',
    'water',
    'sodas',
  }),
  _CategoryRule('cat_fruits', <String>{'fruits', 'fruit', 'berries'}),
  _CategoryRule('cat_vegetables', <String>{'vegetables', 'vegetable'}),
];

final RegExp _languagePrefix = RegExp(r'^[a-z]{2,3}:');

/// Best-fit default category for Open Food Facts [tags]; "Other" when no rule
/// matches. The person can always change it before saving.
String categoryIdForTags(List<String> tags) {
  final Set<String> words = <String>{};
  for (final String tag in tags) {
    final String bare = tag.toLowerCase().replaceFirst(_languagePrefix, '');
    words.addAll(bare.split('-'));
  }
  for (final _CategoryRule rule in _categoryRules) {
    if (rule.words.any(words.contains)) {
      return rule.categoryId;
    }
  }
  return kDefaultCategoryId;
}
