/// What sort of food an item is. The enum [name] is what the database stores
/// (a missing value in the database means [stocked], which is how every item
/// looked before this existed), so never rename a value without a migration.
enum ItemKind {
  /// Bought food and household goods: the default.
  stocked('Stocked'),

  /// Food that was cooked at home and is eaten within days: curries, rice,
  /// batter, chutney, sambar. Also called leftovers.
  cooked('Cooked'),

  /// Food made at home that keeps for weeks or months: pickles, ghee, podi,
  /// masala powders, papad.
  homemade('Homemade');

  const ItemKind(this.label);

  final String label;

  bool get isStocked => this == ItemKind.stocked;

  /// Cooked and homemade items are made, not bought.
  bool get isMadeAtHome => this != ItemKind.stocked;

  /// The kind stored as [text] (an enum name), [stocked] for null or anything
  /// unknown.
  static ItemKind fromName(String? text) {
    for (final ItemKind kind in ItemKind.values) {
      if (kind.name == text) {
        return kind;
      }
    }
    return ItemKind.stocked;
  }
}
