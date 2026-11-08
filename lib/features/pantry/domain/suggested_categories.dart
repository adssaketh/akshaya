import 'entities.dart';

/// A category the app offers to add with one tap (Settings > Categories >
/// Suggestions). They are not added by themselves, so nobody's category list
/// changes unless they choose it.
final class SuggestedCategory {
  const SuggestedCategory(this.name, this.iconKey, this.group);

  final String name;
  final String iconKey;
  final String group;
}

const String kSuggestFood = 'Food';
const String kSuggestPersonalCare = 'Personal care and health';
const String kSuggestHome = 'Home';

/// Suggested categories, grouped, in display order. The names follow the
/// aisles of the large Indian grocery apps (fresh produce, staples, fish and
/// meat, beauty and hygiene, home and household, pet care, medicines).
const List<SuggestedCategory> kSuggestedCategories = <SuggestedCategory>[
  SuggestedCategory('Eggs', 'eggs', kSuggestFood),
  SuggestedCategory('Dry Fruits & Nuts', 'dry_fruits', kSuggestFood),
  SuggestedCategory('Fish & Seafood', 'fish', kSuggestFood),
  SuggestedCategory('Flours & Atta', 'flour', kSuggestFood),
  SuggestedCategory('Millets & Health Foods', 'millets', kSuggestFood),
  SuggestedCategory('Sugar, Salt & Sweeteners', 'sugar_salt', kSuggestFood),
  SuggestedCategory('Sauces, Pickles & Spreads', 'sauces', kSuggestFood),
  SuggestedCategory('Breakfast & Cereals', 'breakfast', kSuggestFood),
  SuggestedCategory('Instant & Ready to Eat', 'instant', kSuggestFood),
  SuggestedCategory('Canned & Packaged', 'packaged', kSuggestFood),
  SuggestedCategory('Biscuits & Cookies', 'biscuits', kSuggestFood),
  SuggestedCategory('Sweets & Chocolates', 'sweets', kSuggestFood),
  SuggestedCategory('Ice Cream & Desserts', 'ice_cream', kSuggestFood),
  SuggestedCategory('Tea & Coffee', 'tea', kSuggestFood),
  SuggestedCategory('Water & Soft Drinks', 'water', kSuggestFood),
  SuggestedCategory('Organic', 'organic', kSuggestFood),
  SuggestedCategory('Beauty & Skincare', 'beauty', kSuggestPersonalCare),
  SuggestedCategory('Hair Care', 'hair_care', kSuggestPersonalCare),
  SuggestedCategory('Oral Care', 'oral_care', kSuggestPersonalCare),
  SuggestedCategory('Bath & Body', 'bath_body', kSuggestPersonalCare),
  SuggestedCategory('Baby Care', 'baby', kSuggestPersonalCare),
  SuggestedCategory('Medicines', 'medicine', kSuggestPersonalCare),
  SuggestedCategory('Health & First Aid', 'wellness', kSuggestPersonalCare),
  SuggestedCategory(
    'Vitamins & Supplements',
    'supplements',
    kSuggestPersonalCare,
  ),
  SuggestedCategory('Pet Care', 'pets', kSuggestPersonalCare),
  SuggestedCategory('Laundry', 'laundry', kSuggestHome),
  SuggestedCategory('Dishwashing', 'dishwash', kSuggestHome),
  SuggestedCategory('Paper & Disposables', 'disposables', kSuggestHome),
  SuggestedCategory('Pooja Items', 'pooja', kSuggestHome),
  SuggestedCategory('Gifts & Festive', 'gifts', kSuggestHome),
  SuggestedCategory('Batteries & Bulbs', 'batteries', kSuggestHome),
  SuggestedCategory('Garden', 'garden', kSuggestHome),
  SuggestedCategory('Stationery', 'stationery', kSuggestHome),
];

/// Lower-case letters and digits only, so "Dals & Pulses" and "dals and
/// pulses" read as the same name.
String _plainName(String name) {
  return name
      .toLowerCase()
      .replaceAll('&', 'and')
      .replaceAll(RegExp(r'[^a-z0-9]'), '');
}

/// The suggestions whose names are not already categories.
List<SuggestedCategory> missingSuggestions(List<Category> existing) {
  final Set<String> taken = <String>{
    for (final Category c in existing) _plainName(c.name),
  };
  return <SuggestedCategory>[
    for (final SuggestedCategory s in kSuggestedCategories)
      if (!taken.contains(_plainName(s.name))) s,
  ];
}
