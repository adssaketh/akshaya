import '../../recipes/domain/recipe_models.dart';
import 'meal_plan_models.dart';
import 'meal_slot.dart';

/// Suggests prep reminders ("Soak Rajma", "Thaw Chicken") for a recipe, from
/// its steps, title and ingredients. Runs on the phone, no AI. The person can
/// edit, remove or add reminders afterwards. Pure Dart, English only.
abstract final class PrepRules {
  /// Most reminders suggested for one meal.
  static const int maxSuggestions = 4;

  /// Soaking for batter happens in the morning of the day before (soak,
  /// grind in the evening, ferment overnight).
  static const int _batterMinutes = 9 * 60;

  /// Evening of the day before.
  static const int _eveningMinutes = kDefaultPrepMinutes;

  static final RegExp _soak = RegExp(r'\bsoak', caseSensitive: false);
  static final RegExp _thaw = RegExp(r'\b(thaw|defrost)', caseSensitive: false);
  static final RegExp _ferment = RegExp(r'\bferment', caseSensitive: false);
  static final RegExp _marinate = RegExp(r'\bmarinat', caseSensitive: false);
  static final RegExp _overnight = RegExp(r'\bovernight\b', caseSensitive: false);
  static final RegExp _hours = RegExp(
    r'(\d+)(?:\s*-\s*(\d+))?\s*(?:hours?|hrs?)\b',
    caseSensitive: false,
  );

  /// Dishes made from a fermented batter.
  static final RegExp _batterDish = RegExp(
    r'\b(idli|idly|dosa|dosai|uttapam|uttappam|appam|vada|medu vada|paniyaram)\b',
    caseSensitive: false,
  );

  static final RegExp _urad = RegExp(r'\b(urad|black gram|minapappu)', caseSensitive: false);
  static final RegExp _rice = RegExp(r'\brice\b', caseSensitive: false);

  /// Dried beans and pulses that need soaking before cooking.
  static final RegExp _soakable = RegExp(
    r'\b(rajma|kidney bean|chole|chickpea|kabuli|chana|lobia|black.?eyed|'
    r'horse gram|kulthi|sabudana|sago)',
    caseSensitive: false,
  );

  static final RegExp _pesarattu = RegExp(r'pesarattu|adai', caseSensitive: false);
  static final RegExp _moong = RegExp(r'\b(moong|green gram|pesalu)', caseSensitive: false);

  /// Reminders for [recipe] eaten at [slot], most useful first. Empty when
  /// nothing needs doing ahead.
  static List<PrepReminder> suggest(Recipe recipe, MealSlot slot) {
    final List<PrepReminder> out = <PrepReminder>[];
    final Set<String> seen = <String>{};

    void add(String text, int daysBefore, int minutes) {
      final String cleaned = PrepReminder.clean(text);
      if (cleaned.isEmpty || out.length >= maxSuggestions) {
        return;
      }
      if (seen.add(cleaned.toLowerCase())) {
        out.add(
          PrepReminder(
            text: cleaned,
            daysBefore: daysBefore,
            minutesOfDay: minutes,
          ),
        );
      }
    }

    final String title = recipe.title;
    final List<String> names = <String>[
      for (final RecipeIngredient i in recipe.ingredients) i.name,
    ];
    final bool hasUrad = names.any(_urad.hasMatch);
    final bool hasRice = names.any(_rice.hasMatch);
    final bool mentionsFerment = recipe.steps.any(_ferment.hasMatch);

    // Batter dishes: soak the rice and urad dal the morning before.
    final bool batter = hasUrad && (_batterDish.hasMatch(title) || mentionsFerment);
    if (batter) {
      add(
        hasRice
            ? 'Soak rice and urad dal for the batter'
            : 'Soak urad dal for the batter',
        1,
        _batterMinutes,
      );
    } else if (mentionsFerment) {
      add('Start fermenting the batter', 1, _eveningMinutes);
    }

    // Steps that say what to do ahead of time.
    for (final String step in recipe.steps) {
      if (_soak.hasMatch(step) && !(batter && (_urad.hasMatch(step) || _rice.hasMatch(step)))) {
        final String? what = _ingredientIn(step, names);
        add(what == null ? 'Soak ingredients for $title' : 'Soak $what', 1, _eveningMinutes);
      } else if (_thaw.hasMatch(step)) {
        final String? what = _ingredientIn(step, names);
        add(what == null ? 'Thaw ingredients for $title' : 'Thaw $what', 1, _eveningMinutes);
      } else if (_marinate.hasMatch(step)) {
        final String? what = _ingredientIn(step, names);
        final String text = what == null ? 'Marinate for $title' : 'Marinate $what';
        if (_overnight.hasMatch(step)) {
          add(text, 1, _eveningMinutes);
        } else {
          final int? hours = _longestHours(step);
          if (hours != null && hours >= 2) {
            // Same day, early enough for the marinade to work.
            final int minutes = slot.defaultMinutes - (hours * 60) - 30;
            add(text, 0, minutes < 6 * 60 ? 6 * 60 : minutes);
          }
        }
      } else if (_overnight.hasMatch(step)) {
        add('Prepare ahead for $title', 1, _eveningMinutes);
      }
    }

    // Dried beans soak even when the steps do not say so.
    for (final String name in names) {
      if (_soakable.hasMatch(name)) {
        add('Soak $name', 1, _eveningMinutes);
      } else if (_moong.hasMatch(name) && _pesarattu.hasMatch(title)) {
        add('Soak $name', 1, _eveningMinutes);
      }
    }

    return out;
  }

  /// The ingredient whose name appears in [step] (the longest such name), or
  /// null.
  static String? _ingredientIn(String step, List<String> names) {
    final String text = step.toLowerCase();
    String? best;
    for (final String name in names) {
      final String plain = name
          .toLowerCase()
          .replaceAll(RegExp(r'\([^)]*\)'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (plain.length < 3 || !text.contains(plain)) {
        continue;
      }
      if (best == null || plain.length > best.length) {
        best = name;
      }
    }
    return best;
  }

  /// The largest number of hours mentioned in [step] ("2 hours", "4-6 hrs"),
  /// or null.
  static int? _longestHours(String step) {
    int? best;
    for (final RegExpMatch m in _hours.allMatches(step)) {
      // A range ("4-6 hours") counts as its upper end.
      final int? hours = int.tryParse(m.group(2) ?? m.group(1) ?? '');
      if (hours != null && (best == null || hours > best)) {
        best = hours;
      }
    }
    return best;
  }
}
