import '../../ai/domain/ai_command_service.dart';
import '../../ai/domain/ai_failures.dart';
import '../../ai/domain/ai_gate.dart';
import '../../recipes/domain/recipe_models.dart';
import '../../recipes/domain/recipe_pantry.dart';
import '../../recipes/domain/recipe_validator.dart';
import 'plan_prompt.dart';
import 'plan_validator.dart';
import 'prep_rules.dart';

/// The bit that asks Gemini (through Firebase AI Logic) for a weekly plan.
/// Tests replace it with a fake.
abstract interface class PlanBackend {
  /// Sends [prompt] and returns the JSON text of the answer.
  Future<String> generatePlanJson(String prompt);
}

/// Asks Gemini to fill empty meal slots, in one call.
///
/// The call goes through the same gate as command reading and recipe ideas
/// ([guard]): the on/off switch, the privacy notice, the one daily cap (every
/// attempt counts), the quota cooldown and the retries. Whatever happens, the
/// caller gets either meals that fit the person's diet and avoid list, or an
/// [AiFailure] and nothing changes on the plan.
final class AiPlanService {
  AiPlanService({
    required this.guard,
    required this.backend,
    required this.promptTemplate,
    required this.now,
    this.timeout = const Duration(seconds: 90),
  });

  /// Most meals asked for at once. A full recipe is returned for each, so
  /// more would make the answer too long to be reliable.
  static const int maxSlots = 21;

  final AiCommandService guard;
  final PlanBackend backend;
  final String promptTemplate;
  final DateTime Function() now;

  /// A week of full recipes takes much longer to write than one recipe list.
  final Duration timeout;

  /// Why AI can or cannot be used right now.
  Future<AiAvailability> availability() => guard.availability();

  /// Meals for [slots] (at most [maxSlots]; extra ones are ignored).
  /// [pantry] is already limited to what may be sent (see
  /// `RecipePantry.forPrompt`); [alreadyPlanned] are dish titles to avoid
  /// repeating. Throws an [AiFailure].
  Future<List<PlannedMeal>> generate({
    required List<PantryLine> pantry,
    required RecipePreferences preferences,
    required List<PlanSlot> slots,
    List<String> alreadyPlanned = const <String>[],
  }) async {
    final List<PlanSlot> asked = slots.take(maxSlots).toList();
    if (asked.isEmpty) {
      throw const AiInvalidResponseFailure('nothing to plan');
    }
    final DateTime current = now();
    final String prompt = PlanPromptBuilder.build(
      promptTemplate,
      pantry: pantry,
      preferences: preferences,
      slots: asked,
      alreadyPlanned: alreadyPlanned,
      today: DateTime(current.year, current.month, current.day),
    );
    final String answer = await guard.guardedCall(
      () => backend.generatePlanJson(prompt),
      timeout: timeout,
    );
    // An answer that cannot be used is not retried: that would only burn the
    // daily cap.
    final List<PlannedMeal> parsed = PlanResponseValidator.parse(
      answer,
      allowed: <String>{
        for (final PlanSlot s in asked)
          PlanResponseValidator.slotKey(s.date, s.slot),
      },
    );
    final List<PlannedMeal> fitting = <PlannedMeal>[
      for (final PlannedMeal m in parsed)
        if (RecipeSafety.isAllowed(m.recipe, preferences))
          PlannedMeal(
            date: m.date,
            slot: m.slot,
            recipe: m.recipe,
            // The AI's own reminders, or the app's rules when it gave none.
            prep: m.prep.isNotEmpty
                ? m.prep
                : PrepRules.suggest(m.recipe, m.slot),
          ),
    ];
    if (fitting.isEmpty) {
      throw const AiInvalidResponseFailure('nothing fits the preferences');
    }
    return fitting;
  }
}
