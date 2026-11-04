import '../../pantry/domain/default_categories.dart';
import '../../pantry/domain/entities.dart';
import 'shopping_entities.dart';
import 'shopping_enums.dart';

/// Entries of one category, in display order.
final class ShoppingSection {
  const ShoppingSection({required this.title, required this.entries});

  final String title;
  final List<ShoppingEntry> entries;
}

/// One list, ready to show.
final class ShoppingListView {
  const ShoppingListView({
    required this.sections,
    required this.basket,
    required this.upcoming,
  });

  /// Entries still to buy, grouped by category.
  final List<ShoppingSection> sections;

  /// Checked-off entries ("in the basket").
  final List<ShoppingEntry> basket;

  /// Repeating entries that come back on a later day.
  final List<ShoppingEntry> upcoming;

  int get toBuyCount {
    int total = 0;
    for (final ShoppingSection s in sections) {
      total += s.entries.length;
    }
    return total;
  }

  bool get isEmpty => sections.isEmpty && basket.isEmpty && upcoming.isEmpty;
}

/// Groups and orders a list's entries. Pure: no Flutter, no database.
abstract final class ShoppingListBuilder {
  /// Entries that are on the list today and not yet checked.
  static int toBuyCount(Iterable<ShoppingEntry> entries, DateTime today) {
    int total = 0;
    for (final ShoppingEntry e in entries) {
      if (!e.isChecked && e.isDueOn(today)) {
        total++;
      }
    }
    return total;
  }

  /// Builds the view of one list. [entries] must all belong to that list.
  ///
  /// Unchecked entries that are due go into category sections (category order
  /// as in Settings; free-text entries and entries of deleted items go under
  /// Other). Within a section, urgent entries come first, then by name.
  static ShoppingListView build({
    required List<ShoppingEntry> entries,
    required Map<String, Item> itemsById,
    required List<Category> categories,
    required DateTime today,
  }) {
    final Map<String, Category> categoryById = <String, Category>{
      for (final Category c in categories) c.id: c,
    };

    final Map<String, List<ShoppingEntry>> byCategory =
        <String, List<ShoppingEntry>>{};
    final List<ShoppingEntry> basket = <ShoppingEntry>[];
    final List<ShoppingEntry> upcoming = <ShoppingEntry>[];

    for (final ShoppingEntry e in entries) {
      if (e.isChecked) {
        basket.add(e);
      } else if (!e.isDueOn(today)) {
        upcoming.add(e);
      } else {
        final String? categoryId = itemsById[e.itemId]?.categoryId;
        final String key =
            categoryById.containsKey(categoryId) ? categoryId! : kDefaultCategoryId;
        byCategory.putIfAbsent(key, () => <ShoppingEntry>[]).add(e);
      }
    }

    final List<String> orderedKeys = byCategory.keys.toList()
      ..sort((String a, String b) {
        final int sa = categoryById[a]?.sortOrder ?? 1 << 20;
        final int sb = categoryById[b]?.sortOrder ?? 1 << 20;
        return sa.compareTo(sb);
      });

    final List<ShoppingSection> sections = <ShoppingSection>[
      for (final String key in orderedKeys)
        ShoppingSection(
          title: categoryById[key]?.name ?? 'Other',
          entries: (byCategory[key]!..sort(_byUrgencyThenName)),
        ),
    ];

    basket.sort(_byName);
    upcoming.sort((ShoppingEntry a, ShoppingEntry b) {
      final DateTime? da = a.dueOn;
      final DateTime? db = b.dueOn;
      if (da != null && db != null) {
        final int byDate = da.compareTo(db);
        if (byDate != 0) {
          return byDate;
        }
      }
      return _byName(a, b);
    });

    return ShoppingListView(
      sections: sections,
      basket: basket,
      upcoming: upcoming,
    );
  }

  static int _byName(ShoppingEntry a, ShoppingEntry b) {
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  }

  static int _byUrgencyThenName(ShoppingEntry a, ShoppingEntry b) {
    final bool aUrgent = a.priority == ShoppingPriority.high;
    final bool bUrgent = b.priority == ShoppingPriority.high;
    if (aUrgent != bUrgent) {
      return aUrgent ? -1 : 1;
    }
    return _byName(a, b);
  }
}
