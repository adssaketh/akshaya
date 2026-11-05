import '../../ai/domain/ai_command_service.dart';
import '../../ai/domain/ai_failures.dart';
import '../../ai/domain/ai_gate.dart';
import 'recipe_models.dart';
import 'recipe_pantry.dart';
import 'recipe_prompt.dart';
import 'recipe_validator.dart';

/// The bit that asks Gemini (through Firebase AI Logic) for recipe ideas.
/// Tests replace it with a fake.
abstract interface class RecipeBackend {
  /// Sends [prompt] and returns the JSON text of the answer.
  Future<String> generateRecipesJson(String prompt);
}

/// Asks Gemini for recipe ideas from the pantry.
///
/// The call goes through the same gate as command reading ([guard]): the
/// on/off switch, the privacy notice, the one daily cap (every attempt counts),
/// the quota cooldown and the retries. Whatever happens, the caller gets either
/// recipes that fit the person's diet and avoid list, or an [AiFailure] and
/// carries on offline.
final class AiRecipeService {
  AiRecipeService({
    required this.guard,
    required this.backend,
    required this.promptTemplate,
    required this.now,
    this.timeout = const Duration(seconds: 45),
  });

  final AiCommandService guard;
  final RecipeBackend backend;
  final String promptTemplate;
  final DateTime Function() now;

  /// Recipes take longer to write than a command takes to read.
  final Duration timeout;

  /// Why AI can or cannot be used right now.
  Future<AiAvailability> availability() => guard.availability();

  /// Recipe ideas for [pantry] (already limited to what may be sent, see
  /// `RecipePantry.forPrompt`). Throws an [AiFailure].
  Future<List<Recipe>> generate({
    required List<PantryLine> pantry,
    required RecipePreferences preferences,
  }) async {
    if (pantry.isEmpty) {
      throw const AiInvalidResponseFailure('empty pantry');
    }
    final DateTime current = now();
    final String prompt = RecipePromptBuilder.build(
      promptTemplate,
      pantry: pantry,
      preferences: preferences,
      today: DateTime(current.year, current.month, current.day),
    );
    final String answer = await guard.guardedCall(
      () => backend.generateRecipesJson(prompt),
      timeout: timeout,
    );
    // An answer that cannot be used is not retried: that would only burn the
    // daily cap.
    final List<Recipe> parsed = RecipeResponseValidator.parse(answer);
    final List<Recipe> fitting = RecipeSafety.filter(parsed, preferences);
    if (fitting.isEmpty) {
      throw const AiInvalidResponseFailure('nothing fits the preferences');
    }
    return fitting;
  }
}
