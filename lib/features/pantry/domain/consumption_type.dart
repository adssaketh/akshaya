/// Why stock left the pantry. The enum [name] is stored in the database.
enum ConsumptionType {
  used('Used'),
  wasted('Wasted'),
  expired('Expired'),
  givenAway('Given away'),
  cookedInRecipe('Cooked in recipe'),

  /// A correction made by Count mode or a spoken "set to" command. The amount
  /// is signed: positive when stock was lowered, negative when it was raised.
  /// It never counts as use or as waste.
  adjustment('Adjustment');

  const ConsumptionType(this.label);

  final String label;
}
