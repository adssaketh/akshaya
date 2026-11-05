import '../../rescue/domain/food_rescue.dart';
import '../../shopping/domain/shopping_entities.dart';

/// One row of the shopping widget.
final class WidgetShopRow {
  const WidgetShopRow({
    required this.id,
    required this.text,
    required this.checked,
  });

  /// The shopping entry the row toggles.
  final String id;

  /// "Milk, 1 L".
  final String text;
  final bool checked;
}

/// What the home screen widgets show. Plain text, so the Android side only
/// has to draw it.
final class WidgetSnapshot {
  const WidgetSnapshot({
    required this.useFirst,
    required this.useFirstMore,
    required this.shopping,
    required this.shoppingMore,
  });

  /// "Milk · Today".
  final List<String> useFirst;

  /// How many more food rescue entries did not fit.
  final int useFirstMore;
  final List<WidgetShopRow> shopping;
  final int shoppingMore;

  static const WidgetSnapshot empty = WidgetSnapshot(
    useFirst: <String>[],
    useFirstMore: 0,
    shopping: <WidgetShopRow>[],
    shoppingMore: 0,
  );

  /// The values handed to the widgets (Android shared preferences).
  Map<String, Object> toPrefs() {
    final Map<String, Object> out = <String, Object>{
      'use_first_count': useFirst.length,
      'use_first_more': useFirstMore,
      'shop_count': shopping.length,
      'shop_more': shoppingMore,
    };
    for (int i = 0; i < WidgetSnapshots.useFirstRows; i++) {
      out['use_first_$i'] = i < useFirst.length ? useFirst[i] : '';
    }
    for (int i = 0; i < WidgetSnapshots.shoppingRows; i++) {
      final bool has = i < shopping.length;
      out['shop_id_$i'] = has ? shopping[i].id : '';
      out['shop_text_$i'] = has ? shopping[i].text : '';
      out['shop_checked_$i'] = has && shopping[i].checked;
    }
    return out;
  }

  @override
  bool operator ==(Object other) {
    if (other is! WidgetSnapshot) {
      return false;
    }
    final Map<String, Object> a = toPrefs();
    final Map<String, Object> b = other.toPrefs();
    if (a.length != b.length) {
      return false;
    }
    for (final MapEntry<String, Object> e in a.entries) {
      if (b[e.key] != e.value) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(toPrefs().values);
}

/// Builds the widget contents. Pure Dart.
abstract final class WidgetSnapshots {
  /// Rows in the "Use these first" widget.
  static const int useFirstRows = 5;

  /// Rows in the shopping widget.
  static const int shoppingRows = 6;

  /// Food rescue entries (most urgent first) and the first shopping list.
  ///
  /// Shopping rows are the entries that are on the list today (repeating
  /// items that are not due or are held back by a trip are left out), the
  /// ones still to buy first and ticked ones after them.
  static WidgetSnapshot build({
    required List<RescueEntry> rescue,
    required List<ShoppingEntry> entries,
    required DateTime today,
    DateTime? pausedUntil,
    String listId = kDefaultListId,
  }) {
    final List<String> use = <String>[
      for (final RescueEntry e in rescue.take(useFirstRows))
        '${e.item.name} · ${e.statusLabel}',
    ];
    final int useMore = rescue.length > useFirstRows
        ? rescue.length - useFirstRows
        : 0;

    final List<ShoppingEntry> due = <ShoppingEntry>[
      for (final ShoppingEntry e in entries)
        if (e.listId == listId && e.isDueOn(today, pausedUntil: pausedUntil)) e,
    ];
    final List<ShoppingEntry> open = <ShoppingEntry>[
      for (final ShoppingEntry e in due)
        if (!e.isChecked) e,
    ];
    final List<ShoppingEntry> done = <ShoppingEntry>[
      for (final ShoppingEntry e in due)
        if (e.isChecked) e,
    ];
    final List<ShoppingEntry> ordered = <ShoppingEntry>[...open, ...done];
    final List<WidgetShopRow> rows = <WidgetShopRow>[
      for (final ShoppingEntry e in ordered.take(shoppingRows))
        WidgetShopRow(
          id: e.id,
          text: '${e.name}, ${e.unit.format(e.quantity)}',
          checked: e.isChecked,
        ),
    ];
    final int shopMore =
        ordered.length > shoppingRows ? ordered.length - shoppingRows : 0;

    return WidgetSnapshot(
      useFirst: use,
      useFirstMore: useMore,
      shopping: rows,
      shoppingMore: shopMore,
    );
  }
}
