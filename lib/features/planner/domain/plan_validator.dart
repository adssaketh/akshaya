import 'dart:convert';

import '../../../core/util/date_only.dart';
import '../../ai/domain/ai_failures.dart';
import '../../recipes/domain/recipe_models.dart';
import '../../recipes/domain/recipe_validator.dart';
import 'meal_plan_models.dart';
import 'meal_slot.dart';

/// One meal the AI planned, checked and ready to put on the plan.
final class PlannedMeal {
  const PlannedMeal({
    required this.date,
    required this.slot,
    required this.recipe,
    this.prep = const <PrepReminder>[],
  });

  final DateTime date;
  final MealSlot slot;
  final Recipe recipe;

  /// Prep reminders the AI gave; empty when it gave none (the app then falls
  /// back to its own rules).
  final List<PrepReminder> prep;
}

/// Checks the JSON the AI returns for a weekly plan:
///
/// `{"recipes":[{"id", ...recipe fields..., "prep":[{"text","days_before",
/// "time"}]}], "meals":[{"date","slot","recipe_id"}]}`
///
/// A recipe or meal that does not fit the format is left out; when no meal
/// survives, the whole answer is rejected. Meals outside the asked dates and
/// slots are dropped, and a slot is filled at most once.
abstract final class PlanResponseValidator {
  static const int maxRecipes = 28;
  static const int maxMeals = 28;
  static const int maxIdLength = 24;
  static const int maxPrepPerRecipe = 4;

  static final RegExp _time = RegExp(r'^([01]?\d|2[0-3]):([0-5]\d)$');

  /// The planned meals in [text]. [allowed] are the day and slot pairs that
  /// were asked for, as `yyyy-MM-dd/slot` keys (see [slotKey]).
  static List<PlannedMeal> parse(String text, {required Set<String> allowed}) {
    final Object? decoded;
    try {
      decoded = jsonDecode(_stripFences(text));
    } on FormatException {
      throw const AiInvalidResponseFailure('not JSON');
    }
    if (decoded is! Map<String, Object?>) {
      throw const AiInvalidResponseFailure('not an object');
    }
    final Object? rawRecipes = decoded['recipes'];
    final Object? rawMeals = decoded['meals'];
    if (rawRecipes is! List<Object?> ||
        rawRecipes.isEmpty ||
        rawMeals is! List<Object?> ||
        rawMeals.isEmpty) {
      throw const AiInvalidResponseFailure('no recipes or meals');
    }

    final Map<String, ({Recipe recipe, List<PrepReminder> prep})> byId =
        <String, ({Recipe recipe, List<PrepReminder> prep})>{};
    for (final Object? item in rawRecipes.take(maxRecipes)) {
      if (item is! Map<String, Object?>) {
        continue;
      }
      final Object? id = item['id'];
      if (id is! String || id.trim().isEmpty || id.length > maxIdLength) {
        continue;
      }
      final Recipe? recipe = RecipeResponseValidator.parseRecipe(item);
      if (recipe == null) {
        continue;
      }
      byId[id.trim()] = (recipe: recipe, prep: _prep(item['prep']));
    }

    final List<PlannedMeal> out = <PlannedMeal>[];
    final Set<String> filled = <String>{};
    for (final Object? item in rawMeals.take(maxMeals)) {
      if (item is! Map<String, Object?>) {
        continue;
      }
      final Object? dateRaw = item['date'];
      final DateTime? date = dateRaw is String ? parseIsoDate(dateRaw.trim()) : null;
      final MealSlot? slot =
          item['slot'] is String ? MealSlot.fromKey(item['slot'] as String) : null;
      final Object? recipeId = item['recipe_id'];
      if (date == null || slot == null || recipeId is! String) {
        continue;
      }
      final String key = slotKey(date, slot);
      final ({Recipe recipe, List<PrepReminder> prep})? found =
          byId[recipeId.trim()];
      if (found == null || !allowed.contains(key) || !filled.add(key)) {
        continue;
      }
      out.add(
        PlannedMeal(
          date: date,
          slot: slot,
          recipe: found.recipe,
          prep: found.prep,
        ),
      );
    }
    if (out.isEmpty) {
      throw const AiInvalidResponseFailure('no valid meal');
    }
    return out;
  }

  /// "2026-11-06/dinner": identifies one slot of one day.
  static String slotKey(DateTime date, MealSlot slot) =>
      '${formatIsoDate(date)}/${slot.key}';

  static List<PrepReminder> _prep(Object? raw) {
    if (raw is! List<Object?>) {
      return const <PrepReminder>[];
    }
    final List<PrepReminder> out = <PrepReminder>[];
    for (final Object? item in raw) {
      if (item is! Map<String, Object?> || out.length >= maxPrepPerRecipe) {
        continue;
      }
      final Object? text = item['text'];
      if (text is! String) {
        continue;
      }
      final String cleaned = PrepReminder.clean(text);
      if (cleaned.isEmpty) {
        continue;
      }
      final Object? days = item['days_before'];
      final int daysBefore = days is num && days.isFinite
          ? days.round().clamp(0, PrepReminder.maxDaysBefore).toInt()
          : 1;
      int minutes = kDefaultPrepMinutes;
      final Object? time = item['time'];
      if (time is String) {
        final RegExpMatch? m = _time.firstMatch(time.trim());
        if (m != null) {
          minutes = int.parse(m.group(1)!) * 60 + int.parse(m.group(2)!);
        }
      }
      out.add(
        PrepReminder(text: cleaned, daysBefore: daysBefore, minutesOfDay: minutes),
      );
    }
    return out;
  }

  static String _stripFences(String text) {
    String t = text.trim();
    if (t.startsWith('```')) {
      final int firstNewline = t.indexOf('\n');
      if (firstNewline != -1) {
        t = t.substring(firstNewline + 1);
      }
      if (t.endsWith('```')) {
        t = t.substring(0, t.length - 3);
      }
    }
    return t.trim();
  }
}
