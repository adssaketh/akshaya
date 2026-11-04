/// Why stock left the pantry. The enum [name] is stored in the database.
enum ConsumptionType {
  used('Used'),
  wasted('Wasted'),
  expired('Expired'),
  givenAway('Given away'),
  cookedInRecipe('Cooked in recipe');

  const ConsumptionType(this.label);

  final String label;
}
