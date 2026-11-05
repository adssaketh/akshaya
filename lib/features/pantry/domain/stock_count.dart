import 'entities.dart';
import 'storage_location.dart';
import 'unit.dart';

/// What [PantryRepository.setStock] changed, so it can be undone.
///
/// All amounts are in the item's default unit ([unit]).
final class CountResult {
  const CountResult({
    required this.itemId,
    required this.before,
    required this.after,
    required this.unit,
    this.deduction,
    this.addedBatchId,
    this.addedLogId,
  });

  final String itemId;

  /// What the app held before the change (in the counted scope).
  final double before;

  /// What it holds now.
  final double after;
  final Unit unit;

  /// Set when the stock was lowered: the batches that gave up stock.
  final UseResult? deduction;

  /// Set when the stock was raised: the batch and log that were created.
  final String? addedBatchId;
  final String? addedLogId;

  /// Counted minus expected: negative when stock was lowered.
  double get difference => after - before;

  /// False when the count matched and nothing was written.
  bool get changed => deduction != null || addedBatchId != null;
}

/// Which items a count walks through.
enum CountScopeKind { all, location, category }

/// What a count covers: the whole pantry, one storage location, or one
/// category. Persisted as text so a count can be resumed.
final class CountScope {
  const CountScope.all()
      : kind = CountScopeKind.all,
        location = null,
        categoryId = null;

  const CountScope.inLocation(StorageLocation this.location)
      : kind = CountScopeKind.location,
        categoryId = null;

  const CountScope.inCategory(String this.categoryId)
      : kind = CountScopeKind.category,
        location = null;

  final CountScopeKind kind;
  final StorageLocation? location;
  final String? categoryId;

  /// Compact text for storage: "all", "location:fridge", "category:cat_x".
  String get key {
    switch (kind) {
      case CountScopeKind.all:
        return 'all';
      case CountScopeKind.location:
        return 'location:${location!.name}';
      case CountScopeKind.category:
        return 'category:$categoryId';
    }
  }

  /// Reads [key] back; null when the text is not a scope.
  static CountScope? fromKey(String? key) {
    if (key == null) {
      return null;
    }
    if (key == 'all') {
      return const CountScope.all();
    }
    if (key.startsWith('location:')) {
      final String name = key.substring('location:'.length);
      for (final StorageLocation l in StorageLocation.values) {
        if (l.name == name) {
          return CountScope.inLocation(l);
        }
      }
      return null;
    }
    if (key.startsWith('category:')) {
      final String id = key.substring('category:'.length);
      return id.isEmpty ? null : CountScope.inCategory(id);
    }
    return null;
  }

  @override
  bool operator ==(Object other) => other is CountScope && other.key == key;

  @override
  int get hashCode => key.hashCode;
}
