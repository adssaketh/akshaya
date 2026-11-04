import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/clock.dart';
import '../../pantry/domain/entities.dart';
import '../../pantry/domain/stock_logic.dart';
import '../../pantry/presentation/providers.dart';
import '../data/drift_shopping_repository.dart';
import '../domain/shopping_entities.dart';
import '../domain/shopping_repository.dart';
import '../domain/shopping_suggestions.dart';
import '../domain/shopping_view.dart';

final Provider<ShoppingRepository> shoppingRepositoryProvider =
    Provider<ShoppingRepository>((Ref ref) {
  return DriftShoppingRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(pantryRepositoryProvider),
    clock: ref.watch(clockProvider),
  );
});

final StreamProvider<List<ShoppingList>> shoppingListsProvider =
    StreamProvider<List<ShoppingList>>((Ref ref) {
  return ref.watch(shoppingRepositoryProvider).watchLists();
});

/// Every active entry of every list.
final StreamProvider<List<ShoppingEntry>> shoppingEntriesProvider =
    StreamProvider<List<ShoppingEntry>>((Ref ref) {
  return ref.watch(shoppingRepositoryProvider).watchEntries();
});

/// The list the Shopping tab is showing. Null until the person picks one; the
/// first list is shown then (and when the picked list has been deleted).
final NotifierProvider<SelectedListNotifier, String?> selectedListIdProvider =
    NotifierProvider<SelectedListNotifier, String?>(SelectedListNotifier.new);

class SelectedListNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String listId) => state = listId;
}

/// The list being shown, or null while lists load.
final Provider<ShoppingList?> selectedListProvider =
    Provider<ShoppingList?>((Ref ref) {
  final List<ShoppingList> lists =
      ref.watch(shoppingListsProvider).value ?? const <ShoppingList>[];
  if (lists.isEmpty) {
    return null;
  }
  final String? picked = ref.watch(selectedListIdProvider);
  for (final ShoppingList list in lists) {
    if (list.id == picked) {
      return list;
    }
  }
  return lists.first;
});

/// The selected list, grouped and ordered for today.
final Provider<AsyncValue<ShoppingListView>> shoppingViewProvider =
    Provider<AsyncValue<ShoppingListView>>((Ref ref) {
  final AsyncValue<List<ShoppingEntry>> entries =
      ref.watch(shoppingEntriesProvider);
  final ShoppingList? list = ref.watch(selectedListProvider);
  final DateTime today = ref.watch(todayProvider);
  final List<ItemWithBatches> items =
      ref.watch(itemsStreamProvider).value ?? const <ItemWithBatches>[];
  final List<Category> categories =
      ref.watch(categoriesProvider).value ?? const <Category>[];

  return entries.whenData(
    (List<ShoppingEntry> all) => ShoppingListBuilder.build(
      entries: <ShoppingEntry>[
        for (final ShoppingEntry e in all)
          if (list != null && e.listId == list.id) e,
      ],
      itemsById: <String, Item>{
        for (final ItemWithBatches r in items) r.item.id: r.item,
      },
      categories: categories,
      today: today,
    ),
  );
});

/// How many entries are still to buy on each list (by list id), for the list
/// chips.
final Provider<Map<String, int>> toBuyCountsProvider =
    Provider<Map<String, int>>((Ref ref) {
  final List<ShoppingEntry> entries =
      ref.watch(shoppingEntriesProvider).value ?? const <ShoppingEntry>[];
  final DateTime today = ref.watch(todayProvider);

  final Map<String, List<ShoppingEntry>> byList =
      <String, List<ShoppingEntry>>{};
  for (final ShoppingEntry e in entries) {
    byList.putIfAbsent(e.listId, () => <ShoppingEntry>[]).add(e);
  }
  return <String, int>{
    for (final MapEntry<String, List<ShoppingEntry>> e in byList.entries)
      e.key: ShoppingListBuilder.toBuyCount(e.value, today),
  };
});

/// Suggestions the person dismissed. Kept in memory only: they come back the
/// next time the app starts, if the item still needs restocking.
final NotifierProvider<DismissedSuggestionsNotifier, Set<String>>
    dismissedSuggestionsProvider =
    NotifierProvider<DismissedSuggestionsNotifier, Set<String>>(
  DismissedSuggestionsNotifier.new,
);

class DismissedSuggestionsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => const <String>{};

  void dismiss(String itemId) => state = <String>{...state, itemId};
}

/// Pantry items worth restocking that are not on any list yet.
final Provider<List<ShoppingSuggestion>> suggestionsProvider =
    Provider<List<ShoppingSuggestion>>((Ref ref) {
  final List<ItemStock> stocks =
      ref.watch(pantryStocksProvider).value ?? const <ItemStock>[];
  final List<ShoppingEntry> entries =
      ref.watch(shoppingEntriesProvider).value ?? const <ShoppingEntry>[];
  final DateTime today = ref.watch(todayProvider);
  final Set<String> dismissed = ref.watch(dismissedSuggestionsProvider);

  return <ShoppingSuggestion>[
    for (final ShoppingSuggestion s in ShoppingSuggestions.compute(
      stocks: stocks,
      entries: entries,
      today: today,
    ))
      if (!dismissed.contains(s.item.id)) s,
  ];
});
