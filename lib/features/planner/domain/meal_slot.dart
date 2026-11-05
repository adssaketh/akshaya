/// The four slots of a day in the meal plan. [key] is stored and used in the
/// JSON the AI returns, so never rename it.
enum MealSlot {
  breakfast('breakfast', 'Breakfast', 8 * 60),
  lunch('lunch', 'Lunch', 13 * 60),
  dinner('dinner', 'Dinner', 20 * 60),
  snack('snack', 'Snack', 17 * 60);

  const MealSlot(this.key, this.label, this.defaultMinutes);

  final String key;
  final String label;

  /// Roughly when this meal is eaten, as minutes after midnight. Prep
  /// reminders for the same day are placed relative to it.
  final int defaultMinutes;

  /// The slot stored under [text], or null.
  static MealSlot? fromKey(String? text) {
    final String wanted = (text ?? '').trim().toLowerCase();
    for (final MealSlot slot in MealSlot.values) {
      if (slot.key == wanted) {
        return slot;
      }
    }
    return null;
  }
}
