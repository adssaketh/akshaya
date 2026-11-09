import 'package:akshaya/core/design/design.dart' show StatusKind;

import 'default_categories.dart';
import 'entities.dart';
import 'item_kind.dart';
import 'stock_logic.dart';
import 'storage_location.dart';

/// How the pantry list is grouped.
enum PantryGroup {
  category('Category'),
  location('Location');

  const PantryGroup(this.label);

  final String label;
}

/// How items are ordered inside each group.
enum PantrySort {
  name('Name'),
  expiry('Expiry'),
  quantity('Quantity'),
  recentlyAdded('Recently added'),
  type('Type');

  const PantrySort(this.label);

  final String label;
}

/// Lower-cases, trims and collapses spaces. Telugu and Hindi script pass
/// through unchanged, so aliases in any script can be matched.
String normalizeForSearch(String text) {
  return text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

/// Search text, grouping, ordering and status filter for the pantry list.
final class PantryQuery {
  const PantryQuery({
    this.text = '',
    this.group = PantryGroup.category,
    this.sort = PantrySort.expiry,
    this.statusFilter,
    this.kindFilter,
  });

  final String text;
  final PantryGroup group;
  final PantrySort sort;
  final StatusKind? statusFilter;

  /// Show only cooked or only homemade food (null shows everything).
  final ItemKind? kindFilter;

  bool get hasActiveFilters =>
      text.trim().isNotEmpty || statusFilter != null || kindFilter != null;

  PantryQuery copyWith({
    String? text,
    PantryGroup? group,
    PantrySort? sort,
    StatusKind? statusFilter,
    bool clearStatusFilter = false,
    ItemKind? kindFilter,
    bool clearKindFilter = false,
  }) {
    return PantryQuery(
      text: text ?? this.text,
      group: group ?? this.group,
      sort: sort ?? this.sort,
      statusFilter:
          clearStatusFilter ? null : (statusFilter ?? this.statusFilter),
      kindFilter: clearKindFilter ? null : (kindFilter ?? this.kindFilter),
    );
  }

  /// True when [stock] passes the status filter and the search text. Every
  /// word typed must appear in the name, brand, any alias or the name of the
  /// item's category ([categoryName]), so searching "dairy" lists the Dairy
  /// category.
  bool matches(ItemStock stock, {String? categoryName}) {
    final StatusKind? wanted = statusFilter;
    if (wanted != null && stock.status != wanted) {
      return false;
    }
    final ItemKind? wantedKind = kindFilter;
    if (wantedKind != null && stock.item.kind != wantedKind) {
      return false;
    }
    final String needle = normalizeForSearch(text);
    if (needle.isEmpty) {
      return true;
    }
    final StringBuffer haystack = StringBuffer(normalizeForSearch(stock.item.name));
    final String? brand = stock.item.brand;
    if (brand != null) {
      haystack
        ..write(' ')
        ..write(normalizeForSearch(brand));
    }
    for (final String alias in stock.item.aliases) {
      haystack
        ..write(' ')
        ..write(normalizeForSearch(alias));
    }
    if (categoryName != null) {
      haystack
        ..write(' ')
        ..write(normalizeForSearch(categoryName));
    }
    final String all = haystack.toString();
    return needle.split(' ').every(all.contains);
  }
}

/// One titled group of items in the pantry list.
final class PantrySection {
  const PantrySection({
    required this.id,
    required this.title,
    required this.items,
  });

  final String id;
  final String title;
  final List<ItemStock> items;
}

/// Filters, orders and groups items for the pantry screen.
abstract final class PantryListBuilder {
  static List<PantrySection> build(
    List<ItemStock> stocks,
    PantryQuery query,
    List<Category> categories,
  ) {
    final Map<String, String> names = <String, String>{
      for (final Category c in categories) c.id: c.name,
    };
    final Map<String, int> order = <String, int>{
      for (final Category c in categories) c.id: c.sortOrder,
    };
    final List<ItemStock> visible = stocks
        .where(
          (ItemStock s) => query.matches(
            s,
            categoryName: names[s.item.categoryId] ?? 'Other',
          ),
        )
        .toList()
      ..sort(_comparator(query.sort, order));

    switch (query.group) {
      case PantryGroup.category:
        return _byCategory(visible, categories);
      case PantryGroup.location:
        return _byLocation(visible);
    }
  }

  static List<PantrySection> _byCategory(
    List<ItemStock> visible,
    List<Category> categories,
  ) {
    final Map<String, List<ItemStock>> buckets = <String, List<ItemStock>>{};
    for (final ItemStock s in visible) {
      buckets.putIfAbsent(s.item.categoryId, () => <ItemStock>[]).add(s);
    }

    final List<PantrySection> sections = <PantrySection>[];
    for (final Category c in categories) {
      final List<ItemStock>? items = buckets.remove(c.id);
      if (items != null) {
        sections.add(PantrySection(id: c.id, title: c.name, items: items));
      }
    }
    if (buckets.isNotEmpty) {
      final List<ItemStock> rest = <ItemStock>[
        for (final List<ItemStock> list in buckets.values) ...list,
      ];
      sections.add(
        PantrySection(id: kDefaultCategoryId, title: 'Other', items: rest),
      );
    }
    return sections;
  }

  static List<PantrySection> _byLocation(List<ItemStock> visible) {
    final List<PantrySection> sections = <PantrySection>[];
    for (final StorageLocation location in StorageLocation.values) {
      final List<ItemStock> items = visible
          .where((ItemStock s) => s.primaryLocation == location)
          .toList();
      if (items.isNotEmpty) {
        sections.add(
          PantrySection(
            id: location.name,
            title: location.label,
            items: items,
          ),
        );
      }
    }
    return sections;
  }

  static int Function(ItemStock, ItemStock) _comparator(
    PantrySort sort,
    Map<String, int> categoryOrder,
  ) {
    switch (sort) {
      case PantrySort.name:
        return _byName;
      case PantrySort.expiry:
        return (ItemStock a, ItemStock b) {
          final DateTime? ea = a.nearestExpiry;
          final DateTime? eb = b.nearestExpiry;
          if (ea != null && eb != null) {
            final int c = ea.compareTo(eb);
            if (c != 0) {
              return c;
            }
          } else if (ea != null) {
            return -1;
          } else if (eb != null) {
            return 1;
          }
          return _byName(a, b);
        };
      case PantrySort.quantity:
        return (ItemStock a, ItemStock b) {
          final int c = a.totalRemaining.compareTo(b.totalRemaining);
          return c != 0 ? c : _byName(a, b);
        };
      case PantrySort.recentlyAdded:
        return (ItemStock a, ItemStock b) {
          final int c = b.item.createdAt.compareTo(a.item.createdAt);
          return c != 0 ? c : _byName(a, b);
        };
      case PantrySort.type:
        // By category (in the Categories screen's order), then by name. Most
        // useful when the list is grouped by Location.
        return (ItemStock a, ItemStock b) {
          final int oa = categoryOrder[a.item.categoryId] ?? (1 << 30);
          final int ob = categoryOrder[b.item.categoryId] ?? (1 << 30);
          final int c = oa.compareTo(ob);
          return c != 0 ? c : _byName(a, b);
        };
    }
  }

  static int _byName(ItemStock a, ItemStock b) {
    return a.item.name.toLowerCase().compareTo(b.item.name.toLowerCase());
  }
}
