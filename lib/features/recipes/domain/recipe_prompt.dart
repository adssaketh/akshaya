import '../../../core/util/quantity.dart';
import 'recipe_models.dart';
import 'recipe_pantry.dart';

/// Fills in the recipe prompt template (`assets/prompts/generate_recipes.txt`).
///
/// Only grocery facts leave the phone: item names, amounts, units and expiry
/// dates, plus the cooking preferences (diet, cuisine, time, number of people
/// and the avoid list). No name, email, household or location is ever part of
/// it.
abstract final class RecipePromptBuilder {
  static const int maxNameLength = 80;

  static final RegExp _controlChars = RegExp(r'[\u0000-\u001F\u007F]');

  /// [pantry] must already be limited to what should be sent (see
  /// `RecipePantry.forPrompt`).
  static String build(
    String template, {
    required List<PantryLine> pantry,
    required RecipePreferences preferences,
    required DateTime today,
  }) {
    final String avoid = preferences.avoid.isEmpty
        ? 'nothing'
        : preferences.avoid.map(_clean).join(', ');
    final String pantryText =
        pantry.map((PantryLine line) => _line(line)).join('\n');
    // The two pieces of text that come from the person go in last, so nothing
    // in them can be mistaken for a placeholder.
    return template
        .replaceAll('{{today}}', _isoDate(today))
        .replaceAll('{{people}}', preferences.people.toString())
        .replaceAll('{{diet}}', _dietText(preferences.diet))
        .replaceAll(
          '{{cuisine}}',
          preferences.cuisine == RecipeCuisine.any
              ? 'any cuisine'
              : preferences.cuisine.label,
        )
        .replaceAll('{{max_minutes}}', preferences.maxMinutes.toString())
        .replaceAll('{{avoid}}', avoid)
        .replaceAll('{{pantry}}', pantryText);
  }

  static String _line(PantryLine line) {
    final String amount = '${formatNumber(line.usable)} ${line.unit.symbol}';
    final DateTime? expiry = line.expiry;
    final int? days = line.daysLeft;
    final String when;
    if (expiry == null || days == null) {
      when = 'no expiry date';
    } else if (days <= 0) {
      when = 'expires ${_isoDate(expiry)} (today)';
    } else if (days == 1) {
      when = 'expires ${_isoDate(expiry)} (tomorrow)';
    } else {
      when = 'expires ${_isoDate(expiry)} (in $days days)';
    }
    final String leftover = line.item.isLeftover ? ' [cooked leftover]' : '';
    return '- ${_clean(line.name)}: $amount, $when$leftover';
  }

  static String _dietText(RecipeDiet diet) {
    switch (diet) {
      case RecipeDiet.veg:
        return 'vegetarian (no meat, fish or eggs)';
      case RecipeDiet.egg:
        return 'eggetarian (vegetarian food and eggs, but no meat or fish)';
      case RecipeDiet.nonVeg:
        return 'non-vegetarian food is allowed, but vegetarian recipes are fine';
    }
  }

  /// One line of plain text: no control characters or template or fence
  /// markers, limited length.
  static String _clean(String text) {
    final String oneLine = text
        .replaceAll(_controlChars, ' ')
        .replaceAll('{{', ' ')
        .replaceAll('}}', ' ')
        .replaceAll('<<<', ' ')
        .replaceAll('>>>', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return oneLine.length > maxNameLength
        ? oneLine.substring(0, maxNameLength)
        : oneLine;
  }

  static String _isoDate(DateTime d) {
    final String m = d.month.toString().padLeft(2, '0');
    final String day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }
}
