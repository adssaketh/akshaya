import '../../recipes/domain/recipe_models.dart';
import '../../recipes/domain/recipe_pantry.dart';
import '../../recipes/domain/recipe_prompt.dart';
import 'meal_slot.dart';

/// One empty meal the AI is asked to plan.
final class PlanSlot {
  const PlanSlot(this.date, this.slot);

  /// The calendar day (no time of day).
  final DateTime date;
  final MealSlot slot;
}

/// Fills in the weekly plan prompt template (`assets/prompts/plan_week.txt`).
///
/// Like the recipe prompt, only grocery facts leave the phone: item names,
/// amounts, units and expiry dates, the cooking preferences, the dates and
/// slots to plan and the titles of dishes already planned. No name, email,
/// household or location is part of it.
abstract final class PlanPromptBuilder {
  /// Titles of already planned dishes listed in the prompt.
  static const int maxPlannedTitles = 30;

  static const List<String> _weekdays = <String>[
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  /// [pantry] must already be limited to what should be sent (see
  /// `RecipePantry.forPrompt`).
  static String build(
    String template, {
    required List<PantryLine> pantry,
    required RecipePreferences preferences,
    required List<PlanSlot> slots,
    required List<String> alreadyPlanned,
    required DateTime today,
  }) {
    final String avoid = preferences.avoid.isEmpty
        ? 'nothing'
        : preferences.avoid.map(RecipePromptBuilder.clean).join(', ');
    final String meals = slots
        .map(
          (PlanSlot s) => '- ${RecipePromptBuilder.isoDate(s.date)} '
              '(${_weekdays[s.date.weekday - 1]}): ${s.slot.key}',
        )
        .join('\n');
    final List<String> titles = <String>[
      for (final String t in alreadyPlanned.take(maxPlannedTitles))
        '- ${RecipePromptBuilder.clean(t)}',
    ];
    // The pieces of text that come from the person go in last, so nothing in
    // them can be mistaken for a placeholder.
    return template
        .replaceAll('{{today}}', RecipePromptBuilder.isoDate(today))
        .replaceAll('{{people}}', preferences.people.toString())
        .replaceAll('{{diet}}', RecipePromptBuilder.dietText(preferences.diet))
        .replaceAll(
          '{{cuisine}}',
          preferences.cuisine == RecipeCuisine.any
              ? 'any cuisine'
              : preferences.cuisine.label,
        )
        .replaceAll('{{max_minutes}}', preferences.maxMinutes.toString())
        .replaceAll('{{avoid}}', avoid)
        .replaceAll('{{meals}}', meals)
        .replaceAll('{{planned}}', titles.isEmpty ? '- nothing yet' : titles.join('\n'))
        .replaceAll('{{pantry}}', RecipePromptBuilder.pantryText(pantry));
  }
}
