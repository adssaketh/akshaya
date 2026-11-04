/// Where a batch is kept. The enum [name] is stored in the database.
enum StorageLocation {
  fridge('Fridge'),
  freezer('Freezer'),
  pantry('Pantry'),
  other('Other');

  const StorageLocation(this.label);

  final String label;
}
