import 'package:flutter/material.dart';

import '../domain/storage_location.dart';

/// One icon a category can use: the key stored in the database, a short name
/// for the picker, and the icon itself.
final class CategoryIconOption {
  const CategoryIconOption(this.key, this.label, this.icon);

  final String key;
  final String label;
  final IconData icon;
}

/// Every icon a category can use, in picker order. Keys are stored in the
/// database and synced, so a key is never renamed or reused; new icons are
/// only ever added. Unknown keys (from a newer app on another phone) fall back
/// to the generic icon.
const List<CategoryIconOption> kCategoryIconOptions = <CategoryIconOption>[
  // Fresh and staples.
  CategoryIconOption('vegetables', 'Vegetables', Icons.eco_rounded),
  CategoryIconOption('fruits', 'Fruits', Icons.apple_rounded),
  CategoryIconOption('dairy', 'Dairy', Icons.local_drink_rounded),
  CategoryIconOption('eggs', 'Eggs', Icons.egg_rounded),
  CategoryIconOption('meat', 'Meat', Icons.set_meal_rounded),
  CategoryIconOption('fish', 'Fish and seafood', Icons.waves_rounded),
  CategoryIconOption('grains', 'Grains and rice', Icons.grain_rounded),
  CategoryIconOption('flour', 'Flours and atta', Icons.rice_bowl_rounded),
  CategoryIconOption('dals', 'Dals and pulses', Icons.blur_on_rounded),
  CategoryIconOption('millets', 'Millets and health foods', Icons.grass_rounded),
  CategoryIconOption(
    'dry_fruits',
    'Dry fruits and nuts',
    Icons.bubble_chart_rounded,
  ),
  CategoryIconOption(
    'spices',
    'Spices and masalas',
    Icons.local_fire_department_rounded,
  ),
  CategoryIconOption('oils', 'Oils and ghee', Icons.opacity_rounded),
  CategoryIconOption(
    'sugar_salt',
    'Sugar and salt',
    Icons.blur_circular_rounded,
  ),
  CategoryIconOption('sauces', 'Sauces and pickles', Icons.liquor_rounded),
  // Ready food, snacks and drinks.
  CategoryIconOption('breakfast', 'Breakfast', Icons.breakfast_dining_rounded),
  CategoryIconOption('instant', 'Instant food', Icons.ramen_dining_rounded),
  CategoryIconOption('packaged', 'Packaged food', Icons.takeout_dining_rounded),
  CategoryIconOption('snacks', 'Snacks', Icons.fastfood_rounded),
  CategoryIconOption('biscuits', 'Biscuits', Icons.cookie_rounded),
  CategoryIconOption('sweets', 'Sweets and chocolates', Icons.cake_rounded),
  CategoryIconOption('ice_cream', 'Ice cream', Icons.icecream_rounded),
  CategoryIconOption('bakery', 'Bakery', Icons.bakery_dining_rounded),
  CategoryIconOption('frozen', 'Frozen', Icons.ac_unit_rounded),
  CategoryIconOption('beverages', 'Beverages', Icons.coffee_rounded),
  CategoryIconOption(
    'tea',
    'Tea and coffee',
    Icons.emoji_food_beverage_rounded,
  ),
  CategoryIconOption('water', 'Water', Icons.water_drop_rounded),
  CategoryIconOption('organic', 'Organic', Icons.energy_savings_leaf_rounded),
  // Personal care and health.
  CategoryIconOption(
    'personal_care',
    'Personal care',
    Icons.spa_rounded,
  ),
  CategoryIconOption(
    'beauty',
    'Beauty and skincare',
    Icons.face_retouching_natural_rounded,
  ),
  CategoryIconOption('hair_care', 'Hair care', Icons.content_cut_rounded),
  CategoryIconOption(
    'oral_care',
    'Oral care',
    Icons.sentiment_satisfied_alt_rounded,
  ),
  CategoryIconOption('bath_body', 'Bath and body', Icons.shower_rounded),
  CategoryIconOption('baby', 'Baby care', Icons.child_care_rounded),
  CategoryIconOption('medicine', 'Medicines', Icons.medication_rounded),
  CategoryIconOption(
    'wellness',
    'Health and first aid',
    Icons.health_and_safety_rounded,
  ),
  CategoryIconOption(
    'supplements',
    'Vitamins and supplements',
    Icons.fitness_center_rounded,
  ),
  CategoryIconOption('pets', 'Pet care', Icons.pets_rounded),
  // Home.
  CategoryIconOption(
    'cleaning',
    'Cleaning',
    Icons.cleaning_services_rounded,
  ),
  CategoryIconOption(
    'laundry',
    'Laundry',
    Icons.local_laundry_service_rounded,
  ),
  CategoryIconOption('dishwash', 'Dishwashing', Icons.wash_rounded),
  CategoryIconOption(
    'disposables',
    'Paper and disposables',
    Icons.shopping_bag_rounded,
  ),
  CategoryIconOption('pooja', 'Pooja items', Icons.self_improvement_rounded),
  CategoryIconOption('gifts', 'Gifts and festive', Icons.redeem_rounded),
  CategoryIconOption('garden', 'Garden', Icons.yard_rounded),
  CategoryIconOption(
    'batteries',
    'Batteries and bulbs',
    Icons.battery_charging_full_rounded,
  ),
  CategoryIconOption('stationery', 'Stationery', Icons.edit_rounded),
  CategoryIconOption('other', 'Other', Icons.category_rounded),
];

/// Icon keys in picker order.
final List<String> kCategoryIconKeys = <String>[
  for (final CategoryIconOption option in kCategoryIconOptions) option.key,
];

final Map<String, IconData> _iconByKey = <String, IconData>{
  for (final CategoryIconOption option in kCategoryIconOptions)
    option.key: option.icon,
};

/// Icon for a category's `iconKey`. Unknown keys fall back to a generic icon.
IconData categoryIcon(String? iconKey) {
  return _iconByKey[iconKey] ?? Icons.category_rounded;
}

/// Short name of an icon for the picker (the key itself when unknown).
String categoryIconLabel(String iconKey) {
  for (final CategoryIconOption option in kCategoryIconOptions) {
    if (option.key == iconKey) {
      return option.label;
    }
  }
  return iconKey;
}

/// Icon for a storage location.
IconData locationIcon(StorageLocation location) {
  switch (location) {
    case StorageLocation.fridge:
      return Icons.kitchen_rounded;
    case StorageLocation.freezer:
      return Icons.ac_unit_rounded;
    case StorageLocation.pantry:
      return Icons.inventory_2_rounded;
    case StorageLocation.other:
      return Icons.category_rounded;
  }
}
