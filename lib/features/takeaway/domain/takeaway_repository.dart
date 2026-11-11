import 'food_estimate.dart';
import 'takeaway_models.dart';

/// Everything the Takeaway feature needs from storage. Like the pantry, the
/// local database is the source of truth and cloud sync works behind this
/// interface.
abstract interface class TakeawayRepository {
  /// Every takeaway, newest day first. Emits again on every change.
  Stream<List<TakeawayMeal>> watchAll();

  /// The same as [watchAll], once.
  Future<List<TakeawayMeal>> readAll();

  Future<TakeawayMeal> add(TakeawayDraft draft);

  /// Saves changes to a takeaway (what, when, how much, the price).
  Future<void> update(TakeawayMeal meal);

  /// Saves Gemini's [estimate] on the takeaway [id].
  Future<void> setEstimate(String id, FoodEstimate estimate);

  /// Removes a takeaway (a soft delete, so it can be undone and synced).
  Future<void> delete(String id);

  Future<void> undoDelete(String id);
}
