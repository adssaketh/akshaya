import 'dart:convert';

import '../../recipes/domain/recipe_models.dart';
import 'meal_slot.dart';

/// What a planned meal is.
enum MealKind {
  /// A recipe (saved, suggested or planned by the AI); the recipe is kept with
  /// the meal.
  recipe,

  /// Cooked food already in the pantry (a leftover) that will be eaten.
  leftover,

  /// Free text such as "Pesarattu" or "Outside".
  text,
}

/// Default time of a prep reminder: 8:00 pm, as minutes after midnight.
const int kDefaultPrepMinutes = 20 * 60;

/// A reminder to start something before a meal ("Soak Rajma").
final class PrepReminder {
  const PrepReminder({
    required this.text,
    this.daysBefore = 1,
    this.minutesOfDay = kDefaultPrepMinutes,
  });

  static const int maxTextLength = 80;

  /// The furthest ahead a reminder can be set.
  static const int maxDaysBefore = 3;

  /// What to do, in English ("Soak Rajma").
  final String text;

  /// 0 is the day of the meal, 1 the day before.
  final int daysBefore;

  /// Time of day, as minutes after midnight.
  final int minutesOfDay;

  PrepReminder copyWith({String? text, int? daysBefore, int? minutesOfDay}) {
    return PrepReminder(
      text: text ?? this.text,
      daysBefore: daysBefore ?? this.daysBefore,
      minutesOfDay: minutesOfDay ?? this.minutesOfDay,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'text': text,
      'daysBefore': daysBefore,
      'minutes': minutesOfDay,
    };
  }

  /// The reminder in [json], or null when it is not usable.
  static PrepReminder? fromJson(Object? json) {
    if (json is! Map<String, Object?>) {
      return null;
    }
    final Object? text = json['text'];
    if (text is! String) {
      return null;
    }
    final String cleaned = clean(text);
    if (cleaned.isEmpty) {
      return null;
    }
    final Object? days = json['daysBefore'];
    final Object? minutes = json['minutes'];
    return PrepReminder(
      text: cleaned,
      daysBefore: days is num ? days.round().clamp(0, maxDaysBefore).toInt() : 1,
      minutesOfDay: minutes is num
          ? minutes.round().clamp(0, 24 * 60 - 1).toInt()
          : kDefaultPrepMinutes,
    );
  }

  /// One line of plain text no longer than [maxTextLength].
  static String clean(String text) {
    final String oneLine = text
        .replaceAll(RegExp(r'[\u0000-\u001F\u007F]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return oneLine.length > maxTextLength
        ? oneLine.substring(0, maxTextLength).trim()
        : oneLine;
  }

  static String? encodeList(List<PrepReminder> reminders) {
    if (reminders.isEmpty) {
      return null;
    }
    return jsonEncode(<Object?>[for (final PrepReminder r in reminders) r.toJson()]);
  }

  /// The reminders in [text]; damaged entries are left out.
  static List<PrepReminder> decodeList(String? text) {
    if (text == null || text.trim().isEmpty) {
      return const <PrepReminder>[];
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      return const <PrepReminder>[];
    }
    if (decoded is! List<Object?>) {
      return const <PrepReminder>[];
    }
    return <PrepReminder>[
      for (final Object? raw in decoded)
        if (fromJson(raw) case final PrepReminder r) r,
    ];
  }

  @override
  bool operator ==(Object other) {
    return other is PrepReminder &&
        other.text == text &&
        other.daysBefore == daysBefore &&
        other.minutesOfDay == minutesOfDay;
  }

  @override
  int get hashCode => Object.hash(text, daysBefore, minutesOfDay);
}

/// One meal on the plan: a slot on a day.
final class MealPlanEntry {
  const MealPlanEntry({
    required this.id,
    required this.date,
    required this.slot,
    required this.title,
    this.recipe,
    this.leftoverItemId,
    this.isCooked = false,
    this.prep = const <PrepReminder>[],
  });

  final String id;

  /// The calendar day (no time of day).
  final DateTime date;
  final MealSlot slot;

  /// What to show: the recipe's title, the leftover's name or the free text.
  final String title;

  /// The recipe, when this is a recipe meal.
  final Recipe? recipe;

  /// The cooked pantry item, when this is a leftover meal.
  final String? leftoverItemId;

  /// True once the meal was cooked (or eaten).
  final bool isCooked;

  /// Reminders to start something before the meal.
  final List<PrepReminder> prep;

  MealKind get kind {
    if (recipe != null) {
      return MealKind.recipe;
    }
    if (leftoverItemId != null) {
      return MealKind.leftover;
    }
    return MealKind.text;
  }

  MealPlanEntry copyWith({
    DateTime? date,
    MealSlot? slot,
    String? title,
    Recipe? recipe,
    String? leftoverItemId,
    bool clearContent = false,
    bool? isCooked,
    List<PrepReminder>? prep,
  }) {
    return MealPlanEntry(
      id: id,
      date: date ?? this.date,
      slot: slot ?? this.slot,
      title: title ?? this.title,
      recipe: clearContent ? recipe : (recipe ?? this.recipe),
      leftoverItemId:
          clearContent ? leftoverItemId : (leftoverItemId ?? this.leftoverItemId),
      isCooked: isCooked ?? this.isCooked,
      prep: prep ?? this.prep,
    );
  }

  /// A copy holding what [draft] holds (same id, so the plan row is replaced
  /// in place). The cooked mark is cleared: it is a different meal now.
  MealPlanEntry replacedBy(MealPlanDraft draft) {
    return MealPlanEntry(
      id: id,
      date: draft.date,
      slot: draft.slot,
      title: draft.title,
      recipe: draft.recipe,
      leftoverItemId: draft.leftoverItemId,
      prep: draft.prep,
    );
  }

  static String encodeRecipe(Recipe recipe) => jsonEncode(recipe.toJson());

  /// The recipe in [text], or null when there is none or it is damaged.
  static Recipe? decodeRecipe(String? text) {
    if (text == null || text.trim().isEmpty) {
      return null;
    }
    try {
      return Recipe.fromJson(jsonDecode(text));
    } on FormatException {
      return null;
    }
  }
}

/// A meal about to be put on the plan.
final class MealPlanDraft {
  const MealPlanDraft._({
    required this.date,
    required this.slot,
    required this.title,
    this.recipe,
    this.leftoverItemId,
    this.prep = const <PrepReminder>[],
  });

  /// A recipe meal, titled after the recipe.
  factory MealPlanDraft.fromRecipe({
    required DateTime date,
    required MealSlot slot,
    required Recipe recipe,
    List<PrepReminder> prep = const <PrepReminder>[],
  }) {
    return MealPlanDraft._(
      date: DateTime(date.year, date.month, date.day),
      slot: slot,
      title: recipe.title,
      recipe: recipe,
      prep: prep,
    );
  }

  /// Eating the cooked pantry item [itemId] (named [name]).
  factory MealPlanDraft.leftover({
    required DateTime date,
    required MealSlot slot,
    required String itemId,
    required String name,
  }) {
    return MealPlanDraft._(
      date: DateTime(date.year, date.month, date.day),
      slot: slot,
      title: name,
      leftoverItemId: itemId,
    );
  }

  /// A free-text meal ("Pesarattu", "Outside").
  factory MealPlanDraft.text({
    required DateTime date,
    required MealSlot slot,
    required String text,
  }) {
    return MealPlanDraft._(
      date: DateTime(date.year, date.month, date.day),
      slot: slot,
      title: text,
    );
  }

  static const int maxTitleLength = 120;

  final DateTime date;
  final MealSlot slot;
  final String title;
  final Recipe? recipe;
  final String? leftoverItemId;
  final List<PrepReminder> prep;

  /// Free text made safe to store: one line, limited length. Null when empty.
  static String? cleanText(String text) {
    final String oneLine = text
        .replaceAll(RegExp(r'[\u0000-\u001F\u007F]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (oneLine.isEmpty) {
      return null;
    }
    return oneLine.length > maxTitleLength
        ? oneLine.substring(0, maxTitleLength).trim()
        : oneLine;
  }
}
