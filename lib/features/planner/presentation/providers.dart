import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/clock.dart';
import '../../../core/util/date_only.dart';
import '../../ai/domain/ai_command_service.dart';
import '../../ai/domain/ai_failures.dart';
import '../../ai/domain/ai_gate.dart';
import '../../ai/presentation/providers.dart';
import '../../pantry/presentation/providers.dart';
import '../../recipes/domain/recipe_models.dart';
import '../../recipes/domain/recipe_pantry.dart';
import '../../recipes/presentation/providers.dart';
import '../data/drift_meal_plan_repository.dart';
import '../data/firebase_plan_backend.dart';
import '../domain/ai_plan_service.dart';
import '../domain/meal_plan_models.dart';
import '../domain/meal_plan_repository.dart';
import '../domain/plan_prompt.dart';
import '../domain/plan_validator.dart';

final Provider<MealPlanRepository> mealPlanRepositoryProvider =
    Provider<MealPlanRepository>((Ref ref) {
  return DriftMealPlanRepository(
    ref.watch(appDatabaseProvider),
    clock: ref.watch(clockProvider),
  );
});

/// Every meal from today on. The prep reminders are scheduled from this.
final StreamProvider<List<MealPlanEntry>> upcomingMealsProvider =
    StreamProvider<List<MealPlanEntry>>((Ref ref) {
  final DateTime today = ref.watch(todayProvider);
  return ref.watch(mealPlanRepositoryProvider).watchFrom(today);
});

/// The Monday of the week [d] falls in.
DateTime mondayOf(DateTime d) => addDays(dateOnly(d), -(d.weekday - 1));

/// The first day (a Monday) of the week the planner shows.
final NotifierProvider<WeekStartNotifier, DateTime> weekStartProvider =
    NotifierProvider<WeekStartNotifier, DateTime>(WeekStartNotifier.new);

class WeekStartNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => mondayOf(ref.read(todayProvider));

  /// Moves by [weeks] weeks (negative goes back).
  void shift(int weeks) => state = addDays(state, weeks * 7);

  void thisWeek() => state = mondayOf(ref.read(todayProvider));
}

/// The meals of the week the planner shows.
final StreamProvider<List<MealPlanEntry>> weekMealsProvider =
    StreamProvider<List<MealPlanEntry>>((Ref ref) {
  final DateTime start = ref.watch(weekStartProvider);
  return ref
      .watch(mealPlanRepositoryProvider)
      .watchBetween(start, addDays(start, 6));
});

/// The weekly plan prompt template bundled with the app.
final FutureProvider<String> planPromptProvider = FutureProvider<String>(
  (Ref ref) => rootBundle.loadString('assets/prompts/plan_week.txt'),
);

final Provider<PlanBackend> planBackendProvider =
    Provider<PlanBackend>((Ref ref) {
  return FirebasePlanBackend(ref.watch(firebaseRuntimeProvider));
});

/// The plan generator, or null while the prompt or the AI gate load.
final Provider<AiPlanService?> aiPlanServiceProvider =
    Provider<AiPlanService?>((Ref ref) {
  final String? prompt = ref.watch(planPromptProvider).value;
  final AiCommandService? guard = ref.watch(aiCommandServiceProvider);
  if (prompt == null || guard == null) {
    return null;
  }
  return AiPlanService(
    guard: guard,
    backend: ref.watch(planBackendProvider),
    promptTemplate: prompt,
    now: ref.watch(clockProvider),
  );
});

/// What the planner shows about a running or finished AI request.
final class PlannerUiState {
  const PlannerUiState({this.busy = false, this.message});

  final bool busy;

  /// A line for the person (why nothing was planned, or what went wrong).
  final String? message;
}

/// What "Plan my week" did, so it can be undone.
final class PlanWeekResult {
  const PlanWeekResult({required this.ids, required this.asked});

  /// The meals that were put on the plan.
  final List<String> ids;

  /// How many empty slots were asked for.
  final int asked;
}

final NotifierProvider<PlannerController, PlannerUiState>
    plannerControllerProvider =
    NotifierProvider<PlannerController, PlannerUiState>(PlannerController.new);

/// Asks the AI to fill empty slots. Never throws: every failure becomes a
/// message and the plan stays as it was.
class PlannerController extends Notifier<PlannerUiState> {
  @override
  PlannerUiState build() => const PlannerUiState();

  void clearMessage() => state = const PlannerUiState();

  /// Fills [slots] (empty slots only, at most `AiPlanService.maxSlots`).
  /// [noticeAccepted] is the answer of the privacy notice the screen showed.
  /// [alreadyPlanned] are dish titles the AI should not repeat.
  Future<PlanWeekResult?> planWeek({
    required bool noticeAccepted,
    required List<PlanSlot> slots,
    required List<String> alreadyPlanned,
  }) async {
    if (state.busy) {
      return null;
    }
    if (!noticeAccepted) {
      state = const PlannerUiState(
        message: 'AI is turned off, so the week cannot be planned for you.',
      );
      return null;
    }
    final AiPlanService? service = ref.read(aiPlanServiceProvider);
    if (service == null) {
      state = const PlannerUiState(message: 'Planning is still loading.');
      return null;
    }
    if (slots.isEmpty) {
      state = const PlannerUiState(message: 'Pick at least one day and meal.');
      return null;
    }
    final List<PantryLine> forPrompt =
        RecipePantry.forPrompt(ref.read(pantryLinesProvider));
    final RecipePreferences prefs = ref.read(recipePreferencesProvider);
    final MealPlanRepository repository = ref.read(mealPlanRepositoryProvider);
    try {
      final AiAvailability availability = await service.availability();
      if (!availability.isReady) {
        state = PlannerUiState(message: availability.message);
        return null;
      }
      state = const PlannerUiState(busy: true);
      final List<PlannedMeal> meals = await service.generate(
        pantry: forPrompt,
        preferences: prefs,
        slots: slots,
        alreadyPlanned: alreadyPlanned,
      );
      // The person may have filled a slot while the AI was working: only
      // slots that are still empty are filled.
      final DateTime first = slots
          .map((PlanSlot s) => s.date)
          .reduce((DateTime a, DateTime b) => a.isBefore(b) ? a : b);
      final Set<String> taken = <String>{
        for (final MealPlanEntry e in await repository.readFrom(first))
          PlanResponseValidator.slotKey(e.date, e.slot),
      };
      final List<MealPlanDraft> drafts = <MealPlanDraft>[
        for (final PlannedMeal m in meals)
          if (!taken.contains(PlanResponseValidator.slotKey(m.date, m.slot)))
            MealPlanDraft.fromRecipe(
              date: m.date,
              slot: m.slot,
              recipe: m.recipe,
              prep: m.prep,
            ),
      ];
      final List<MealPlanEntry> saved = await repository.putAll(drafts);
      state = const PlannerUiState();
      return PlanWeekResult(
        ids: <String>[for (final MealPlanEntry e in saved) e.id],
        asked: slots.length,
      );
    } on AiFailure catch (failure) {
      state = PlannerUiState(message: failure.message);
      return null;
    } on Object {
      state = const PlannerUiState(
        message: 'Could not plan the week. Nothing was changed.',
      );
      return null;
    }
  }
}
