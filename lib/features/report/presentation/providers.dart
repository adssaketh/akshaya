import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/clock.dart';
import '../../ai/domain/ai_failures.dart';
import '../../ai/presentation/providers.dart';
import '../../insights/presentation/providers.dart';
import '../../pantry/domain/entities.dart';
import '../../pantry/domain/stock_logic.dart';
import '../../pantry/presentation/providers.dart';
import '../../recipes/domain/recipe_models.dart';
import '../../recipes/presentation/providers.dart';
import '../../settings/presentation/providers.dart';
import '../../takeaway/domain/food_estimate.dart';
import '../../takeaway/domain/takeaway_models.dart';
import '../../takeaway/presentation/providers.dart';
import '../data/firebase_report_backend.dart';
import '../domain/report_ai.dart';
import '../domain/report_bundle.dart';
import '../domain/report_models.dart';

/// Which window the Home report card and the Food report page show.
final NotifierProvider<ReportPeriodNotifier, ReportPeriod>
reportPeriodProvider = NotifierProvider<ReportPeriodNotifier, ReportPeriod>(
  ReportPeriodNotifier.new,
);

class ReportPeriodNotifier extends Notifier<ReportPeriod> {
  @override
  ReportPeriod build() => ReportPeriod.today;

  void select(ReportPeriod period) => state = period;
}

/// Settings keys of the report.
const String kReportKcalTargetKey = 'report.kcal_target';
const String kReportEggsKey = 'report.include_eggs';
const String kReportAiKeyKey = 'report.ai_key';
const String kReportAiTextKey = 'report.ai_text';

const int kMinKcalTarget = 1200;
const int kMaxKcalTarget = 3500;
const int kDefaultKcalTarget = 2000;

/// The daily energy target per person that the charts draw (a general figure
/// that the person can change; it is not advice).
final Provider<int> kcalTargetProvider = Provider<int>((Ref ref) {
  final Map<String, String> stored =
      ref.watch(settingsMapProvider).value ?? const <String, String>{};
  final int value =
      int.tryParse(stored[kReportKcalTargetKey] ?? '') ?? kDefaultKcalTarget;
  return value.clamp(kMinKcalTarget, kMaxKcalTarget);
});

/// Whether meal ideas, tips and the AI review may include eggs. The person
/// can choose on the report page; until then it follows the diet chosen in
/// Recipes (anything but Vegetarian includes eggs).
final Provider<bool> reportIncludeEggsProvider = Provider<bool>((Ref ref) {
  final Map<String, String> stored =
      ref.watch(settingsMapProvider).value ?? const <String, String>{};
  switch (stored[kReportEggsKey]) {
    case 'true':
      return true;
    case 'false':
      return false;
  }
  return ref.watch(recipePreferencesProvider).diet != RecipeDiet.veg;
});

/// Saves the choice between "Vegetarian" and "With eggs".
Future<void> saveIncludeEggs(WidgetRef ref, bool include) {
  return ref.read(settingsRepositoryProvider).writeAll(<String, String>{
    kReportEggsKey: include.toString(),
  });
}

/// Everything the Food report page shows, for the chosen period.
final Provider<AsyncValue<ReportBundle>> reportBundleProvider =
    Provider<AsyncValue<ReportBundle>>((Ref ref) {
      final ReportPeriod period = ref.watch(reportPeriodProvider);
      final RecipePreferences prefs = ref.watch(recipePreferencesProvider);
      final DateTime today = ref.watch(todayProvider);
      final bool includeEggs = ref.watch(reportIncludeEggsProvider);
      final List<ItemStock> stocks =
          ref.watch(pantryStocksProvider).value ?? const <ItemStock>[];
      final List<TakeawayMeal> takeaways =
          ref.watch(takeawaysProvider).value ?? const <TakeawayMeal>[];
      final Map<String, FoodEstimate> estimates = ref.watch(
        foodEstimatesProvider,
      );
      return ref
          .watch(allHistoryProvider)
          .whenData(
            (List<ConsumptionEntry> entries) => buildReportBundle(
              period: period,
              today: today,
              history: entries,
              itemsById: <String, Item>{
                for (final ItemStock s in stocks) s.item.id: s.item,
              },
              people: prefs.people,
              vegetarian: !includeEggs,
              stocks: stocks,
              takeaways: takeaways,
              estimates: estimates,
            ),
          );
    });

final Provider<ReportBackend> reportBackendProvider = Provider<ReportBackend>((
  Ref ref,
) {
  return FirebaseReportBackend(ref.watch(firebaseRuntimeProvider));
});

/// The AI review service, or null while the AI gate loads.
final Provider<ReportAiService?> reportAiServiceProvider =
    Provider<ReportAiService?>((Ref ref) {
      final guard = ref.watch(aiCommandServiceProvider);
      if (guard == null) {
        return null;
      }
      return ReportAiService(
        guard: guard,
        backend: ref.watch(reportBackendProvider),
      );
    });

enum ReportAiStatus { idle, loading, done, failed }

/// The state of the on-demand AI review.
final class ReportAiState {
  const ReportAiState({
    this.status = ReportAiStatus.idle,
    this.text,
    this.textKey,
    this.message,
  });

  final ReportAiStatus status;

  /// The review, and the report signature it was written for.
  final String? text;
  final String? textKey;

  /// Why it failed, in plain words.
  final String? message;
}

final NotifierProvider<ReportAiNotifier, ReportAiState> reportAiProvider =
    NotifierProvider<ReportAiNotifier, ReportAiState>(ReportAiNotifier.new);

class ReportAiNotifier extends Notifier<ReportAiState> {
  @override
  ReportAiState build() => const ReportAiState();

  /// The saved review for [key], if one was written for this very report.
  String? saved(String key) {
    final Map<String, String> stored =
        ref.read(settingsMapProvider).value ?? const <String, String>{};
    return stored[kReportAiKeyKey] == key ? stored[kReportAiTextKey] : null;
  }

  /// Asks for a review. Makes one attempt and counts against the daily AI
  /// cap; never runs on its own.
  Future<void> generate(ReportBundle bundle, {required bool vegetarian}) async {
    if (state.status == ReportAiStatus.loading) {
      return;
    }
    final ReportAiService? service = ref.read(reportAiServiceProvider);
    if (service == null) {
      state = const ReportAiState(
        status: ReportAiStatus.failed,
        message: 'AI is still getting ready. Try again in a moment.',
      );
      return;
    }
    final String key = ReportAiService.signature(
      bundle.report,
      ref.read(todayProvider),
      variant: vegetarian ? 'veg' : 'eggs',
    );
    state = const ReportAiState(status: ReportAiStatus.loading);
    try {
      final String text = await service.review(
        report: bundle.report,
        pantryHints: bundle.pantryHints,
        vegetarian: vegetarian,
      );
      await ref.read(settingsRepositoryProvider).writeAll(<String, String>{
        kReportAiKeyKey: key,
        kReportAiTextKey: text,
      });
      state = ReportAiState(
        status: ReportAiStatus.done,
        text: text,
        textKey: key,
      );
    } on AiFailure catch (failure) {
      state = ReportAiState(
        status: ReportAiStatus.failed,
        message: failure.message,
      );
    } on Object {
      state = const ReportAiState(
        status: ReportAiStatus.failed,
        message: 'Something went wrong. Please try again later.',
      );
    }
  }
}

/// Saves a new daily energy target.
Future<void> saveKcalTarget(WidgetRef ref, int target) {
  return ref.read(settingsRepositoryProvider).writeAll(<String, String>{
    kReportKcalTargetKey: target
        .clamp(kMinKcalTarget, kMaxKcalTarget)
        .toString(),
  });
}
