import '../../../core/util/date_only.dart';
import '../../../core/util/quantity.dart';
import '../../pantry/domain/consumption_type.dart';
import '../../pantry/domain/entities.dart';
import '../../pantry/domain/failures.dart';
import '../../pantry/domain/pantry_repository.dart';
import '../../pantry/domain/stock_logic.dart';
import '../../pantry/domain/unit.dart';
import '../../settings/domain/settings_repository.dart';
import '../../shopping/domain/shopping_entities.dart';
import '../../shopping/domain/shopping_enums.dart';
import '../../shopping/domain/shopping_repository.dart';
import '../../shopping/domain/shopping_suggestions.dart';
import 'alert_action.dart';
import 'alert_digest.dart';
import 'alert_plan.dart';
import 'alert_settings.dart';
import 'alert_snoozes.dart';

/// What a notification button did.
final class ActionOutcome {
  const ActionOutcome(this.message, {this.changed = false});

  /// One line saying what happened (or why nothing did).
  final String message;

  /// Whether pantry, list or settings data changed. The caller then re-plans
  /// the scheduled alerts.
  final bool changed;
}

/// Does the work of the notification buttons that do not open the app:
/// "Used it", "Add to list" and "Snooze 1 day".
///
/// It works from the repositories it is given, so the running app uses its own
/// database (and its screens update at once) while the background task the
/// phone starts when the app is closed opens its own. Every run starts from
/// the data as it is now, so a button tapped long after the notification
/// appeared never acts on stale facts: what the notification listed is worked
/// out again, and anything that has been dealt with since is left alone.
class NotificationActionRunner {
  const NotificationActionRunner({
    required this.pantry,
    required this.shopping,
    required this.settings,
    required this.clock,
  });

  final PantryRepository pantry;
  final ShoppingRepository shopping;
  final SettingsRepository settings;
  final DateTime Function() clock;

  static const ActionOutcome _nothing = ActionOutcome('Nothing to do.');

  /// Runs [action] for the notification that carried [payload].
  Future<ActionOutcome> run(AlertAction action, AlertPayload payload) async {
    if (action.opensApp) {
      return _nothing;
    }

    final Map<String, String> stored = await settings.readAll();
    final AlertSettings alertSettings = AlertSettings.fromMap(stored);
    final AlertSnoozes snoozes = AlertSnoozes.fromMap(stored);
    final DateTime today = dateOnly(clock());
    final List<ItemWithBatches> items = await pantry.watchItems().first;
    final List<ShoppingEntry> entries = await shopping.watchEntries().first;

    // The group the notification listed, as it stands now. The type switches
    // are forced on: the notification exists, so its group does too.
    final AlertDigest digest = AlertDigestBuilder.build(
      items: items,
      entries: entries,
      today: today,
      settings: alertSettings.copyWith(
        expired: true,
        expiring: true,
        lowStock: true,
      ),
      snoozes: snoozes,
    );

    final List<ItemStock> stocks;
    final List<ShoppingSuggestion> suggestions;
    switch (payload.target) {
      case AlertTarget.pantryExpired:
        stocks = digest.expired;
        suggestions = const <ShoppingSuggestion>[];
      case AlertTarget.pantryExpiring:
        stocks = <ItemStock>[...digest.expiringToday, ...digest.expiringSoon];
        suggestions = const <ShoppingSuggestion>[];
      case AlertTarget.shoppingSuggestions:
        stocks = const <ItemStock>[];
        suggestions = digest.lowStock;
      case AlertTarget.householdShopping:
      case AlertTarget.householdPantry:
      case AlertTarget.countMode:
      case AlertTarget.mealPlan:
      case AlertTarget.recipes:
        return _nothing;
    }

    // An alert about one item acts on that item only.
    final String? only = payload.itemId;
    final List<ItemStock> groupStocks = <ItemStock>[
      for (final ItemStock s in stocks)
        if (only == null || s.item.id == only) s,
    ];
    final List<ShoppingSuggestion> groupSuggestions = <ShoppingSuggestion>[
      for (final ShoppingSuggestion s in suggestions)
        if (only == null || s.item.id == only) s,
    ];

    switch (action) {
      case AlertAction.snooze:
        return _snooze(
          groupStocks,
          groupSuggestions,
          only,
          snoozes,
          today,
        );
      case AlertAction.addToList:
        return _addToList(
          groupStocks,
          groupSuggestions,
          entries,
          addedReason: payload.target == AlertTarget.pantryExpired
              ? AddedReason.expired
              : AddedReason.manual,
        );
      case AlertAction.usedIt:
        return _usedIt(groupStocks, only, today, alertSettings.warningDays);
      case AlertAction.showRecipes:
        return _nothing;
    }
  }

  Future<ActionOutcome> _snooze(
    List<ItemStock> stocks,
    List<ShoppingSuggestion> suggestions,
    String? only,
    AlertSnoozes snoozes,
    DateTime today,
  ) async {
    final Set<String> ids = <String>{
      for (final ItemStock s in stocks) s.item.id,
      for (final ShoppingSuggestion s in suggestions) s.item.id,
    };
    if (only != null) {
      ids.add(only);
    }
    if (ids.isEmpty) {
      return _nothing;
    }
    await settings.writeAll(snoozes.snooze(ids, today: today).toMap());
    return ActionOutcome(
      ids.length == 1 ? 'Snoozed for a day.' : 'Snoozed ${ids.length} items.',
      changed: true,
    );
  }

  Future<ActionOutcome> _addToList(
    List<ItemStock> stocks,
    List<ShoppingSuggestion> suggestions,
    List<ShoppingEntry> entries, {
    required AddedReason addedReason,
  }) async {
    final Set<String> listed = <String>{
      for (final ShoppingEntry e in entries)
        if (!e.isChecked && e.itemId != null) e.itemId!,
    };
    final List<ShoppingEntryDraft> drafts = <ShoppingEntryDraft>[
      for (final ShoppingSuggestion s in suggestions)
        if (!listed.contains(s.item.id)) s.toDraft(kDefaultListId),
      for (final ItemStock s in stocks)
        if (!listed.contains(s.item.id))
          _restockDraft(s, addedReason: addedReason),
    ];
    if (drafts.isEmpty) {
      return const ActionOutcome('Already on your list.');
    }
    await shopping.addEntries(drafts);
    return ActionOutcome(
      drafts.length == 1
          ? 'Added 1 item to your list.'
          : 'Added ${drafts.length} items to your list.',
      changed: true,
    );
  }

  ShoppingEntryDraft _restockDraft(
    ItemStock stock, {
    required AddedReason addedReason,
  }) {
    final ({double quantity, Unit unit}) buy =
        ShoppingSuggestions.usualPurchase(stock);
    return ShoppingEntryDraft(
      listId: kDefaultListId,
      itemId: stock.item.id,
      name: stock.item.name,
      quantity: buy.quantity,
      unit: buy.unit,
      addedReason: addedReason,
    );
  }

  /// Uses up the stock that was expiring: every batch whose date falls within
  /// the warning window. Because the alert's item had nothing already
  /// expired (else it would be in the expired alert), taking this amount
  /// first-expiring first takes exactly those batches.
  Future<ActionOutcome> _usedIt(
    List<ItemStock> stocks,
    String? only,
    DateTime today,
    int warningDays,
  ) async {
    if (only == null || stocks.isEmpty) {
      return _nothing;
    }
    final ItemStock stock = stocks.first;
    final Unit unit = stock.item.defaultUnit;
    double amount = 0;
    for (final StockBatch b in stock.inStock) {
      final DateTime? expiry = b.effectiveExpiry;
      if (expiry == null || !b.unit.isCompatibleWith(unit)) {
        continue;
      }
      final int days = daysBetween(today, expiry);
      if (days < 0 || days > warningDays) {
        continue;
      }
      amount += b.unit.convertTo(b.quantityRemaining, unit);
    }
    amount = roundQty(amount);
    if (isZeroQty(amount)) {
      return _nothing;
    }
    try {
      await pantry.useStock(
        itemId: only,
        quantity: amount,
        unit: unit,
        type: ConsumptionType.used,
      );
    } on InsufficientStockFailure catch (failure) {
      // Rounding between units can ask for a hair too much: take what is
      // really there.
      if (isZeroQty(failure.available)) {
        return _nothing;
      }
      await pantry.useStock(
        itemId: only,
        quantity: failure.available,
        unit: unit,
        type: ConsumptionType.used,
      );
    }
    return ActionOutcome('Marked ${stock.item.name} as used.', changed: true);
  }
}
