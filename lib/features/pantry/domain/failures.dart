/// Errors the pantry domain reports to the UI. Every failure carries a message
/// that is safe to show to the person using the app.
sealed class PantryFailure implements Exception {
  const PantryFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// A value the person entered is not acceptable.
final class InvalidInputFailure extends PantryFailure {
  const InvalidInputFailure(super.message);
}

/// The item, batch or category no longer exists.
final class NotFoundFailure extends PantryFailure {
  const NotFoundFailure(super.message);
}

/// An item with the same name already exists.
final class DuplicateItemFailure extends PantryFailure {
  DuplicateItemFailure({required this.existingItemId, required String name})
      : super('"$name" is already in your pantry.');

  final String existingItemId;
}

/// Another item already uses this barcode.
final class DuplicateBarcodeFailure extends PantryFailure {
  DuplicateBarcodeFailure({
    required this.existingItemId,
    required String itemName,
  }) : super('This barcode already belongs to "$itemName".');

  final String existingItemId;
}

/// More was requested than the batches hold.
final class InsufficientStockFailure extends PantryFailure {
  InsufficientStockFailure({
    required this.available,
    required String availableLabel,
  }) : super('Only $availableLabel left.');

  /// Amount available, in the unit that was requested.
  final double available;
}

/// A unit cannot be converted to another (for example kg to litres).
final class UnitMismatchFailure extends PantryFailure {
  UnitMismatchFailure(String from, String to)
      : super('Cannot convert $from to $to.');
}
