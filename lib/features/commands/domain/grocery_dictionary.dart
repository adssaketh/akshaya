import 'dart:convert';

import '../../pantry/domain/unit.dart';

/// One product in the offline dictionary: its English name and every word
/// people use for it.
final class DictionaryEntry {
  const DictionaryEntry({
    required this.name,
    required this.categoryId,
    required this.unit,
    required this.forms,
  });

  /// Canonical English name, for example "Toor Dal".
  final String name;

  /// Id of the default category (see `kDefaultCategories`).
  final String categoryId;

  /// The unit the product is usually counted in.
  final Unit unit;

  /// Words for the product in English, Telugu and Hindi (native script and
  /// romanised). The English [name] is matched too.
  final List<String> forms;
}

/// The bundled dictionary of common Indian grocery words
/// (`assets/dictionary/grocery_dictionary.json`).
final class GroceryDictionary {
  const GroceryDictionary(this.entries);

  static const GroceryDictionary empty = GroceryDictionary(<DictionaryEntry>[]);

  /// Reads the JSON text of the asset. Entries that are incomplete are
  /// skipped, so one typo never takes the whole dictionary down.
  factory GroceryDictionary.fromJson(String source) {
    final Object? decoded = jsonDecode(source);
    if (decoded is! Map<String, Object?>) {
      return GroceryDictionary.empty;
    }
    final Object? items = decoded['items'];
    if (items is! List<Object?>) {
      return GroceryDictionary.empty;
    }
    final List<DictionaryEntry> entries = <DictionaryEntry>[];
    for (final Object? raw in items) {
      if (raw is! Map<String, Object?>) {
        continue;
      }
      final Object? name = raw['en'];
      final Object? category = raw['category'];
      final Object? unit = raw['unit'];
      final Object? forms = raw['forms'];
      if (name is! String ||
          category is! String ||
          unit is! String ||
          forms is! List<Object?>) {
        continue;
      }
      entries.add(
        DictionaryEntry(
          name: name,
          categoryId: category,
          unit: _unitFromSymbol(unit),
          forms: <String>[
            for (final Object? form in forms)
              if (form is String && form.trim().isNotEmpty) form,
          ],
        ),
      );
    }
    return GroceryDictionary(entries);
  }

  final List<DictionaryEntry> entries;

  static Unit _unitFromSymbol(String symbol) {
    for (final Unit unit in Unit.values) {
      if (unit.symbol == symbol) {
        return unit;
      }
    }
    return Unit.pcs;
  }
}
