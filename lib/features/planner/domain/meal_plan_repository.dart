import 'meal_plan_models.dart';

/// Everything the meal planner needs from storage. Like the pantry, the local
/// database is the source of truth and cloud sync works behind this interface.
abstract interface class MealPlanRepository {
  /// The meals from [from] to [to] (both included, calendar days), by day and
  /// slot. Emits again on every change.
  Stream<List<MealPlanEntry>> watchBetween(DateTime from, DateTime to);

  /// Every meal on or after [from], by day and slot. Emits again on every
  /// change (used to schedule prep reminders).
  Stream<List<MealPlanEntry>> watchFrom(DateTime from);

  /// The same as [watchFrom], once.
  Future<List<MealPlanEntry>> readFrom(DateTime from);

  /// Puts the meal of [draft] on its day and slot. A slot holds one meal: when
  /// it already has one, that meal is replaced in place.
  Future<MealPlanEntry> put(MealPlanDraft draft);

  /// [put] for several meals, in one transaction.
  Future<List<MealPlanEntry>> putAll(List<MealPlanDraft> drafts);

  /// Saves changes to a meal (its content, prep reminders or cooked mark).
  Future<void> update(MealPlanEntry entry);

  /// Removes a meal (a soft delete, so it can be undone and synced).
  Future<void> delete(String id);

  Future<void> undoDelete(String id);

  Future<void> deleteMany(List<String> ids);

  Future<void> undoDeleteMany(List<String> ids);
}
