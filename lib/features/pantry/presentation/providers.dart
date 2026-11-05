import 'package:akshaya/core/design/design.dart' show StatusKind;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/clock.dart';
import '../data/database/app_database.dart';
import '../data/database/open_database.dart';
import '../data/drift_pantry_repository.dart';
import '../domain/entities.dart';
import '../domain/item_kind.dart';
import '../domain/pantry_query.dart';
import '../domain/pantry_repository.dart';
import '../domain/stock_logic.dart';

/// The local SQLite database. Tests override this with an in-memory database.
final Provider<AppDatabase> appDatabaseProvider = Provider<AppDatabase>(
  (Ref ref) {
    final AppDatabase db = openAppDatabase();
    ref.onDispose(db.close);
    return db;
  },
);

final Provider<PantryRepository> pantryRepositoryProvider =
    Provider<PantryRepository>((Ref ref) {
  return DriftPantryRepository(
    ref.watch(appDatabaseProvider),
    clock: ref.watch(clockProvider),
  );
});

/// Days before expiry that count as "expiring soon". The app root
/// (`main.dart`) overrides this with the saved alert setting, so the pantry
/// list and the daily alert always agree.
final Provider<int> expiryWarningDaysProvider =
    Provider<int>((Ref ref) => kDefaultExpiryWarningDays);

/// Raw items and their batches, straight from the database.
final StreamProvider<List<ItemWithBatches>> itemsStreamProvider =
    StreamProvider<List<ItemWithBatches>>((Ref ref) {
  return ref.watch(pantryRepositoryProvider).watchItems();
});

final StreamProvider<List<Category>> categoriesProvider =
    StreamProvider<List<Category>>((Ref ref) {
  return ref.watch(pantryRepositoryProvider).watchCategories();
});

/// Categories by id, for icon and name lookups.
final Provider<Map<String, Category>> categoriesByIdProvider =
    Provider<Map<String, Category>>((Ref ref) {
  final List<Category> list =
      ref.watch(categoriesProvider).value ?? const <Category>[];
  return <String, Category>{for (final Category c in list) c.id: c};
});

/// Items with status and totals worked out for today.
final Provider<AsyncValue<List<ItemStock>>> pantryStocksProvider =
    Provider<AsyncValue<List<ItemStock>>>((Ref ref) {
  final AsyncValue<List<ItemWithBatches>> items =
      ref.watch(itemsStreamProvider);
  final DateTime today = ref.watch(todayProvider);
  final int warningDays = ref.watch(expiryWarningDaysProvider);
  return items.whenData(
    (List<ItemWithBatches> list) => <ItemStock>[
      for (final ItemWithBatches record in list)
        StockLogic.summarize(record, today: today, warningDays: warningDays),
    ],
  );
});

/// One item's stock, or null when it does not exist (any more).
final itemStockProvider =
    Provider.family<AsyncValue<ItemStock?>, String>((Ref ref, String itemId) {
  return ref.watch(pantryStocksProvider).whenData<ItemStock?>(
    (List<ItemStock> list) {
      for (final ItemStock stock in list) {
        if (stock.item.id == itemId) {
          return stock;
        }
      }
      return null;
    },
  );
});

/// Usage history of one item.
final historyProvider =
    StreamProvider.family<List<ConsumptionEntry>, String>(
  (Ref ref, String itemId) {
    return ref.watch(pantryRepositoryProvider).watchHistory(itemId);
  },
);

/// Search, grouping, sorting and status filter of the pantry list.
final NotifierProvider<PantryQueryNotifier, PantryQuery> pantryQueryProvider =
    NotifierProvider<PantryQueryNotifier, PantryQuery>(
  PantryQueryNotifier.new,
);

class PantryQueryNotifier extends Notifier<PantryQuery> {
  @override
  PantryQuery build() => const PantryQuery();

  void setText(String text) => state = state.copyWith(text: text);

  void setGroup(PantryGroup group) => state = state.copyWith(group: group);

  void setSort(PantrySort sort) => state = state.copyWith(sort: sort);

  /// Pass null to show every status.
  void setStatus(StatusKind? status) {
    state = status == null
        ? state.copyWith(clearStatusFilter: true)
        : state.copyWith(statusFilter: status);
  }

  /// Pass null to show every kind of food.
  void setKind(ItemKind? kind) {
    state = kind == null
        ? state.copyWith(clearKindFilter: true)
        : state.copyWith(kindFilter: kind);
  }

  void clearFilters() {
    state = state.copyWith(
      text: '',
      clearStatusFilter: true,
      clearKindFilter: true,
    );
  }
}

/// The pantry list: filtered, sorted and grouped.
final Provider<AsyncValue<List<PantrySection>>> pantrySectionsProvider =
    Provider<AsyncValue<List<PantrySection>>>((Ref ref) {
  final AsyncValue<List<ItemStock>> stocks = ref.watch(pantryStocksProvider);
  final List<Category> categories =
      ref.watch(categoriesProvider).value ?? const <Category>[];
  final PantryQuery query = ref.watch(pantryQueryProvider);
  return stocks.whenData(
    (List<ItemStock> list) =>
        PantryListBuilder.build(list, query, categories),
  );
});
