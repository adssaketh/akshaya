/// A button on a notification.
///
/// [usedIt], [addToList] and [snooze] run without opening the app: the phone
/// starts a short background task that changes the data and re-plans the
/// alerts. [showRecipes] has to open the app, so it does.
enum AlertAction {
  /// The one item the notification is about was used up in time.
  usedIt('akshaya_used', 'Used it', opensApp: false),

  /// Put what the notification lists on the default shopping list.
  addToList('akshaya_add_to_list', 'Add to list', opensApp: false),

  /// Leave what the notification lists out of the alerts for a day.
  snooze('akshaya_snooze', 'Snooze 1 day', opensApp: false),

  /// Open the Recipes tab.
  showRecipes('akshaya_show_recipes', 'Show recipes', opensApp: true);

  const AlertAction(this.id, this.label, {required this.opensApp});

  /// The id the notification button carries and hands back when tapped.
  final String id;

  /// The button text.
  final String label;

  /// Whether tapping the button opens the app (the others run in the
  /// background).
  final bool opensApp;

  /// The action with button id [id], or null for any other id (a plain tap on
  /// the notification has none).
  static AlertAction? fromId(String? id) {
    for (final AlertAction action in AlertAction.values) {
      if (action.id == id) {
        return action;
      }
    }
    return null;
  }
}
