import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/clock.dart';
import '../../ai/domain/ai_command_service.dart';
import '../../ai/domain/ai_failures.dart';
import '../../ai/domain/ai_gate.dart';
import '../../ai/presentation/providers.dart';
import '../../commands/presentation/providers.dart';
import '../../pantry/domain/stock_logic.dart';
import '../../pantry/presentation/providers.dart';
import '../../settings/presentation/providers.dart';
import '../data/drift_recipe_repository.dart';
import '../data/firebase_recipe_backend.dart';
import '../domain/ai_recipe_service.dart';
import '../domain/recipe_fingerprint.dart';
import '../domain/recipe_matcher.dart';
import '../domain/recipe_models.dart';
import '../domain/recipe_pantry.dart';
import '../domain/recipe_repository.dart';

final Provider<RecipeRepository> recipeRepositoryProvider =
    Provider<RecipeRepository>((Ref ref) {
  return DriftRecipeRepository(
    ref.watch(appDatabaseProvider),
    clock: ref.watch(clockProvider),
  );
});

/// Recipes the household kept, newest first.
final StreamProvider<List<SavedRecipe>> savedRecipesProvider =
    StreamProvider<List<SavedRecipe>>((Ref ref) {
  return ref.watch(recipeRepositoryProvider).watchSaved();
});

/// The last ideas the AI gave (kept for offline reading).
final StreamProvider<RecipeCacheEntry?> recipeCacheProvider =
    StreamProvider<RecipeCacheEntry?>((Ref ref) {
  return ref.watch(recipeRepositoryProvider).watchCache();
});

/// The saved recipe preferences (defaults until they have loaded).
final Provider<RecipePreferences> recipePreferencesProvider =
    Provider<RecipePreferences>((Ref ref) {
  final Map<String, String> stored =
      ref.watch(settingsMapProvider).value ?? const <String, String>{};
  return RecipePreferences.fromMap(stored);
});

/// The recipe prompt template bundled with the app.
final FutureProvider<String> recipePromptProvider = FutureProvider<String>(
  (Ref ref) => rootBundle.loadString('assets/prompts/generate_recipes.txt'),
);

final Provider<RecipeBackend> recipeBackendProvider =
    Provider<RecipeBackend>((Ref ref) {
  return FirebaseRecipeBackend(ref.watch(firebaseRuntimeProvider));
});

/// The recipe generator, or null while the prompt or the AI gate load.
final Provider<AiRecipeService?> aiRecipeServiceProvider =
    Provider<AiRecipeService?>((Ref ref) {
  final String? prompt = ref.watch(recipePromptProvider).value;
  final AiCommandService? guard = ref.watch(aiCommandServiceProvider);
  if (prompt == null || guard == null) {
    return null;
  }
  return AiRecipeService(
    guard: guard,
    backend: ref.watch(recipeBackendProvider),
    promptTemplate: prompt,
    now: ref.watch(clockProvider),
  );
});

/// What the pantry holds that can be cooked with, soonest expiry first.
final Provider<List<PantryLine>> pantryLinesProvider =
    Provider<List<PantryLine>>((Ref ref) {
  final List<ItemStock> stocks =
      ref.watch(pantryStocksProvider).value ?? const <ItemStock>[];
  return RecipePantry.build(stocks, today: ref.watch(todayProvider));
});

/// Cookable items that expire within the warning window, as item id to days.
final Provider<Map<String, int>> expiringDaysProvider =
    Provider<Map<String, int>>((Ref ref) {
  return RecipePantry.expiringDays(
    ref.watch(pantryLinesProvider),
    warningDays: ref.watch(expiryWarningDaysProvider),
  );
});

/// Matches recipe ingredients to the live pantry.
final Provider<RecipeMatcher> recipeMatcherProvider =
    Provider<RecipeMatcher>((Ref ref) {
  return RecipeMatcher(
    ref.watch(pantryLinesProvider),
    lexicon: ref.watch(groceryLexiconProvider),
  );
});

/// The cached ideas, matched to today's pantry and ranked by how much
/// expiring food they use. Recomputed on every pantry change, so the
/// "in pantry / missing" labels are never stale.
final Provider<List<RankedRecipe>> rankedIdeasProvider =
    Provider<List<RankedRecipe>>((Ref ref) {
  final RecipeCacheEntry? cache = ref.watch(recipeCacheProvider).value;
  if (cache == null) {
    return const <RankedRecipe>[];
  }
  return RecipeRanker.rank(
    cache.recipes,
    ref.watch(recipeMatcherProvider),
    expiringDays: ref.watch(expiringDaysProvider),
  );
});

/// One recipe matched to the live pantry (saved recipes and the detail
/// screen).
RankedRecipe rankOne(WidgetRef ref, Recipe recipe) {
  return RecipeRanker.rank(
    <Recipe>[recipe],
    ref.watch(recipeMatcherProvider),
    expiringDays: ref.watch(expiringDaysProvider),
  ).first;
}

/// True when the pantry and preferences are the same as when the cached ideas
/// were made.
final Provider<bool> ideasUpToDateProvider = Provider<bool>((Ref ref) {
  final RecipeCacheEntry? cache = ref.watch(recipeCacheProvider).value;
  if (cache == null) {
    return false;
  }
  final String now = RecipeFingerprint.compute(
    ref.watch(pantryLinesProvider),
    ref.watch(recipePreferencesProvider),
  );
  return now == cache.fingerprint;
});

/// What the Recipes screen shows about a running or finished request.
final class RecipesUiState {
  const RecipesUiState({this.busy = false, this.message});

  final bool busy;

  /// A line for the person (why nothing was generated, or what went wrong).
  final String? message;
}

final NotifierProvider<RecipesController, RecipesUiState>
    recipesControllerProvider =
    NotifierProvider<RecipesController, RecipesUiState>(
  RecipesController.new,
);

/// Asks for recipe ideas and keeps the result. Never throws: every failure
/// becomes a message and the cached ideas stay as they were.
class RecipesController extends Notifier<RecipesUiState> {
  @override
  RecipesUiState build() => const RecipesUiState();

  void clearMessage() => state = const RecipesUiState();

  /// Saves new preferences. They change the fingerprint, so the next request
  /// is allowed even when the pantry has not changed.
  Future<void> savePreferences(RecipePreferences prefs) {
    return ref.read(settingsRepositoryProvider).writeAll(prefs.toMap());
  }

  /// [noticeAccepted] is the answer of the privacy notice the screen showed.
  /// With [force] the ideas are made again even if nothing changed.
  Future<void> generate({
    required bool noticeAccepted,
    bool force = false,
  }) async {
    if (state.busy) {
      return;
    }
    if (!noticeAccepted) {
      state = const RecipesUiState(
        message: 'AI is turned off, using offline mode.',
      );
      return;
    }
    final AiRecipeService? service = ref.read(aiRecipeServiceProvider);
    if (service == null) {
      state = const RecipesUiState(message: 'Recipes are still loading.');
      return;
    }
    final List<PantryLine> lines = ref.read(pantryLinesProvider);
    final List<PantryLine> forPrompt = RecipePantry.forPrompt(lines);
    if (forPrompt.isEmpty) {
      state = const RecipesUiState(
        message: 'Add some food to your pantry first.',
      );
      return;
    }
    final RecipePreferences prefs = ref.read(recipePreferencesProvider);
    final RecipeRepository repository = ref.read(recipeRepositoryProvider);
    final String fingerprint = RecipeFingerprint.compute(lines, prefs);
    try {
      final RecipeCacheEntry? cached = await repository.readCache();
      if (!force && cached != null && cached.fingerprint == fingerprint) {
        state = const RecipesUiState(
          message: 'Your pantry has not changed, so these ideas still stand.',
        );
        return;
      }
      final AiAvailability availability = await service.availability();
      if (!availability.isReady) {
        state = RecipesUiState(message: availability.message);
        return;
      }
      state = const RecipesUiState(busy: true);
      final List<Recipe> recipes =
          await service.generate(pantry: forPrompt, preferences: prefs);
      await repository.writeCache(
        RecipeCacheEntry(
          fingerprint: fingerprint,
          recipes: recipes,
          generatedAt: ref.read(clockProvider)(),
        ),
      );
      state = const RecipesUiState();
    } on AiFailure catch (failure) {
      state = RecipesUiState(message: failure.message);
    } on Object {
      state = const RecipesUiState(
        message: 'Could not get recipe ideas. Showing the last ones.',
      );
    }
  }
}
