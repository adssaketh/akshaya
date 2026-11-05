import '../../pantry/domain/stock_logic.dart';
import '../../shopping/domain/shopping_suggestions.dart';
import 'alert_action.dart';
import 'alert_digest.dart';

/// Where tapping an alert takes the person.
enum AlertTarget {
  /// Pantry, filtered to expired stock.
  pantryExpired('pantry:expired'),

  /// Pantry, filtered to stock that is expiring soon.
  pantryExpiring('pantry:expiring'),

  /// The Shopping tab, whose top shows the restock suggestions.
  shoppingSuggestions('shopping:suggestions'),

  /// The Shopping tab, after another household member changed a list.
  householdShopping('household:shopping'),

  /// The Pantry tab, after another household member added stock.
  householdPantry('household:pantry'),

  /// Count mode's start screen, from the monthly "time to count" reminder.
  countMode('count:start'),

  /// The meal planner, from a prep reminder ("Soak Rajma").
  mealPlan('plan:week'),

  /// The Recipes tab, from the "Show recipes" button of an expiry alert.
  recipes('recipes:open');

  const AlertTarget(this.payload);

  /// Text carried by the notification and handed back when it is tapped.
  final String payload;

  static AlertTarget? fromPayload(String? payload) {
    return AlertPayload.parse(payload)?.target;
  }
}

/// What a notification carries: where it leads, and (for an alert about one
/// item) which item, so its buttons act on exactly that item.
final class AlertPayload {
  const AlertPayload(this.target, {this.itemId});

  final AlertTarget target;

  /// The item a single-item alert is about, or null.
  final String? itemId;

  static const String _separator = '|';

  /// The text stored on the notification: the target's payload, then the
  /// item id after a `|` when there is one.
  String encode() {
    final String? id = itemId;
    return id == null ? target.payload : '${target.payload}$_separator$id';
  }

  /// Reads [text] back; null when it is empty or names no known target.
  static AlertPayload? parse(String? text) {
    if (text == null || text.isEmpty) {
      return null;
    }
    final int cut = text.indexOf(_separator);
    final String targetText = cut < 0 ? text : text.substring(0, cut);
    final String? id = cut < 0 ? null : text.substring(cut + 1);
    for (final AlertTarget target in AlertTarget.values) {
      if (target.payload == targetText) {
        return AlertPayload(
          target,
          itemId: id == null || id.isEmpty ? null : id,
        );
      }
    }
    return null;
  }
}

/// The Android notification channel an alert belongs to, so each kind can be
/// muted on its own in system settings.
enum AlertChannelKind { expiry, stock, household, prep }

/// One notification to show.
final class AlertNotification {
  const AlertNotification({
    required this.id,
    required this.target,
    required this.channel,
    required this.title,
    required this.body,
    this.actions = const <AlertAction>[],
    this.itemId,
  });

  final int id;
  final AlertTarget target;
  final AlertChannelKind channel;
  final String title;

  /// May hold several lines; the notification expands to show them all.
  final String body;

  /// The buttons under the notification (Android shows up to three).
  final List<AlertAction> actions;

  /// The item an alert about exactly one item is about; its buttons act on
  /// that item.
  final String? itemId;

  /// The text stored on the notification (see [AlertPayload]).
  String get payload => AlertPayload(target, itemId: itemId).encode();
}

/// Turns a digest into the notifications to show. Pure and English only.
abstract final class AlertPlanner {
  /// Day offsets 0 to 2 are the scheduled days; this one is the preview shown
  /// right away, so it never replaces a scheduled alert.
  static const int previewDayOffset = 9;

  /// Names listed in a notification before "+N more".
  static const int maxNames = 4;

  static const int _baseId = 4100;
  static const int _expiredSlot = 1;
  static const int _expiringSlot = 2;
  static const int _lowStockSlot = 3;
  static const int _countSlot = 4;

  /// The id of an alert on day [dayOffset] (0 is the first alert day).
  static int idFor(int dayOffset, int slot) => _baseId + dayOffset * 10 + slot;

  /// Up to three notifications, in this order: expired, expiring, low stock.
  /// Empty when there is nothing to say.
  static List<AlertNotification> plan(AlertDigest digest, {int dayOffset = 0}) {
    final List<AlertNotification> result = <AlertNotification>[];

    if (digest.expired.isNotEmpty) {
      final int n = digest.expired.length;
      result.add(
        AlertNotification(
          id: idFor(dayOffset, _expiredSlot),
          target: AlertTarget.pantryExpired,
          channel: AlertChannelKind.expiry,
          title: n == 1 ? '1 item has expired' : '$n items have expired',
          body: _list(<String>[
            for (final ItemStock s in digest.expired)
              '${s.item.name} (${_ago(-(s.daysToExpiry ?? 0))})',
          ]),
          actions: const <AlertAction>[
            AlertAction.addToList,
            AlertAction.snooze,
          ],
        ),
      );
    }

    final int today = digest.expiringToday.length;
    final int soon = digest.expiringSoon.length;
    if (today + soon > 0) {
      final List<String> lines = <String>[];
      if (today > 0) {
        final String names = _list(<String>[
          for (final ItemStock s in digest.expiringToday) s.item.name,
        ]);
        lines.add('Today: $names');
      }
      if (soon > 0) {
        // With a one-day window everything on this line is due tomorrow, so
        // the per-item "(tomorrow)" would only repeat the label.
        final bool oneDay = digest.warningDays == 1;
        final String label =
            oneDay ? 'Tomorrow' : 'Next ${digest.warningDays} days';
        final String names = _list(<String>[
          for (final ItemStock s in digest.expiringSoon)
            oneDay
                ? s.item.name
                : '${s.item.name} (${_inDays(s.daysToExpiry ?? 1)})',
        ]);
        lines.add('$label: $names');
      }

      final String title;
      if (today > 0 && soon > 0) {
        title = '$today expiring today, $soon more soon';
      } else if (today > 0) {
        title = today == 1 ? '1 item expires today' : '$today items expire today';
      } else {
        title = soon == 1 ? '1 item expiring soon' : '$soon items expiring soon';
      }

      result.add(
        AlertNotification(
          id: idFor(dayOffset, _expiringSlot),
          target: AlertTarget.pantryExpiring,
          channel: AlertChannelKind.expiry,
          title: title,
          body: lines.join('\n'),
          // One item: its own "Used it". Several: buttons for the whole
          // group, because "Used it" could not say which one.
          actions: today + soon == 1
              ? const <AlertAction>[
                  AlertAction.usedIt,
                  AlertAction.snooze,
                  AlertAction.showRecipes,
                ]
              : const <AlertAction>[
                  AlertAction.showRecipes,
                  AlertAction.addToList,
                  AlertAction.snooze,
                ],
          itemId: today + soon == 1
              ? (digest.expiringToday.isNotEmpty
                      ? digest.expiringToday.first
                      : digest.expiringSoon.first)
                  .item
                  .id
              : null,
        ),
      );
    }

    if (digest.lowStock.isNotEmpty) {
      final int n = digest.lowStock.length;
      result.add(
        AlertNotification(
          id: idFor(dayOffset, _lowStockSlot),
          target: AlertTarget.shoppingSuggestions,
          channel: AlertChannelKind.stock,
          title: n == 1 ? '1 item is running low' : '$n items are running low',
          body: _list(<String>[
            for (final ShoppingSuggestion s in digest.lowStock)
              '${s.item.name} (${_stockLeft(s)})',
          ]),
          actions: const <AlertAction>[
            AlertAction.addToList,
            AlertAction.snooze,
          ],
        ),
      );
    }

    return result;
  }

  /// The monthly reminder to check the shelf against the app.
  static AlertNotification countReminder({int dayOffset = 0}) {
    return AlertNotification(
      id: idFor(dayOffset, _countSlot),
      target: AlertTarget.countMode,
      channel: AlertChannelKind.stock,
      title: 'Time to count your pantry',
      body: 'Check the shelf against the app. A few minutes keeps it right.',
    );
  }

  /// "Milk, Curd, Rice, Atta, +3 more".
  static String _list(List<String> names) {
    if (names.length <= maxNames) {
      return names.join(', ');
    }
    final int more = names.length - maxNames;
    return '${names.take(maxNames).join(', ')}, +$more more';
  }

  static String _ago(int daysAgo) {
    return daysAgo <= 1 ? 'yesterday' : '${daysAgo}d ago';
  }

  static String _inDays(int days) {
    return days <= 1 ? 'tomorrow' : 'in ${days}d';
  }

  static String _stockLeft(ShoppingSuggestion suggestion) {
    return suggestion.reason == SuggestionReason.outOfStock
        ? 'none left'
        : suggestion.detail;
  }
}
