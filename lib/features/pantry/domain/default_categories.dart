/// Id of the catch-all category.
const String kDefaultCategoryId = 'cat_other';

/// A category that ships with the app.
final class DefaultCategory {
  const DefaultCategory(this.id, this.name, this.iconKey);

  /// Stable id (not a random UUID) so every device agrees on defaults.
  final String id;
  final String name;
  final String iconKey;
}

/// Default categories, in display order. People can edit them in Settings
/// (Phase 8); ids never change.
const List<DefaultCategory> kDefaultCategories = <DefaultCategory>[
  DefaultCategory('cat_vegetables', 'Vegetables', 'vegetables'),
  DefaultCategory('cat_fruits', 'Fruits', 'fruits'),
  DefaultCategory('cat_dairy', 'Dairy', 'dairy'),
  DefaultCategory('cat_grains', 'Grains & Rice', 'grains'),
  DefaultCategory('cat_dals', 'Dals & Pulses', 'dals'),
  DefaultCategory('cat_spices', 'Spices & Masalas', 'spices'),
  DefaultCategory('cat_oils', 'Oils & Ghee', 'oils'),
  DefaultCategory('cat_snacks', 'Snacks', 'snacks'),
  DefaultCategory('cat_beverages', 'Beverages', 'beverages'),
  DefaultCategory('cat_bakery', 'Bakery', 'bakery'),
  DefaultCategory('cat_frozen', 'Frozen', 'frozen'),
  DefaultCategory('cat_meat_eggs', 'Meat & Eggs', 'meat'),
  DefaultCategory('cat_cleaning', 'Cleaning', 'cleaning'),
  DefaultCategory('cat_personal_care', 'Personal Care', 'personal_care'),
  DefaultCategory(kDefaultCategoryId, 'Other', 'other'),
];
