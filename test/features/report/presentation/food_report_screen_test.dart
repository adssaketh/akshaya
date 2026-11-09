import 'package:akshaya/core/design/design.dart';
import 'package:akshaya/core/share/share_service.dart';
import 'package:akshaya/core/time/clock.dart';
import 'package:akshaya/features/ai/domain/ai_command_service.dart';
import 'package:akshaya/features/ai/domain/ai_gate.dart';
import 'package:akshaya/features/ai/domain/ai_settings.dart';
import 'package:akshaya/features/ai/presentation/providers.dart';
import 'package:akshaya/features/pantry/domain/entities.dart';
import 'package:akshaya/features/pantry/domain/unit.dart';
import 'package:akshaya/features/recipes/domain/recipe_models.dart';
import 'package:akshaya/features/recipes/presentation/providers.dart';
import 'package:akshaya/features/report/domain/meal_ideas.dart';
import 'package:akshaya/features/report/domain/report_ai.dart';
import 'package:akshaya/features/report/domain/report_bundle.dart';
import 'package:akshaya/features/report/domain/report_models.dart';
import 'package:akshaya/features/report/presentation/food_report_screen.dart';
import 'package:akshaya/features/report/presentation/providers.dart';
import 'package:akshaya/features/report/presentation/report_charts.dart';
import 'package:akshaya/features/settings/presentation/providers.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../ai/domain/ai_test_support.dart';
import '../../settings/fake_settings_repository.dart';
import '../domain/report_ai_test.dart' show FakeReportBackend, kGoodReview;
import 'report_test_data.dart';

class _FixedToday extends TodayNotifier {
  @override
  DateTime build() => reportToday;
}

class _FakeShare implements ShareService {
  final List<String> shared = <String>[];

  @override
  Future<void> shareText(String text, {String? subject}) async {
    shared.add(text);
  }
}

void main() {
  late FakeSettingsRepository settings;
  late _FakeShare share;
  late FakeReportBackend backend;

  ReportAiService aiService() {
    final AiCommandService guard = AiCommandService(
      backend: FakeBackend(<Object>[kGoodJson]),
      usageStore: MemoryUsageStore(),
      readSettings: () => const AiSettings(noticeAccepted: true),
      promptTemplate: kTestPrompt,
      firebaseConfigured: true,
      now: () => DateTime(2026, 11, 4, 10),
      delay: (Duration d) async {},
    );
    return ReportAiService(guard: guard, backend: backend);
  }

  Future<ProviderContainer> pump(
    WidgetTester tester,
    ReportBundle bundle, {
    double width = 420,
    double textScale = 1,
    bool dark = false,
    bool aiReady = true,
    RecipeDiet diet = RecipeDiet.veg,
  }) async {
    tester.view.physicalSize = Size(width, 6000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final ProviderContainer container = ProviderContainer(
      overrides: [
        settingsRepositoryProvider.overrideWithValue(settings),
        reportBundleProvider.overrideWithValue(AsyncData<ReportBundle>(bundle)),
        recipePreferencesProvider.overrideWithValue(
          RecipePreferences(diet: diet),
        ),
        todayProvider.overrideWith(_FixedToday.new),
        shareServiceProvider.overrideWithValue(share),
        reportAiServiceProvider.overrideWithValue(aiService()),
        aiAvailabilityProvider.overrideWithValue(
          aiReady ? AiAvailability.ready : AiAvailability.notConfigured,
        ),
      ],
    );
    addTearDown(container.dispose);
    container.listen(settingsMapProvider, (_, __) {});
    await tester.runAsync(() => container.read(settingsMapProvider.future));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: dark ? AkshayaTheme.dark() : AkshayaTheme.light(),
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
            child: const FoodReportScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  setUp(() {
    settings = FakeSettingsRepository(<String, String>{});
    share = _FakeShare();
    backend = FakeReportBackend(<Object>[kGoodReview]);
  });

  testWidgets('shows every section, with real charts', (tester) async {
    await pump(tester, fullWeekBundle());
    for (final String title in <String>[
      'Food report',
      'Calories each day',
      'Where the energy came from',
      'Protein, carbs, fat and fibre',
      'Against the My Plate guide',
      'Your plate',
      'What was used',
      'Cook from your pantry',
      'Ask AI for a deeper review',
      'How this is worked out',
    ]) {
      expect(find.text(title), findsOneWidget, reason: title);
    }
    expect(find.byType(BarChart), findsOneWidget);
    expect(find.byType(PieChart), findsNWidgets(2), reason: 'gauge and donut');
    expect(find.textContaining('kcal'), findsWidgets);
    expect(
      find.text('Basmati Rice · 2.1 kg', skipOffstage: false),
      findsNothing,
    );
  });

  testWidgets('the hero shows the verdict, days logged and the streak', (
    tester,
  ) async {
    await pump(tester, fullWeekBundle());
    expect(find.textContaining('per person a day'), findsOneWidget);
    expect(find.textContaining('days'), findsWidgets);
    expect(find.textContaining('-day streak'), findsOneWidget);
  });

  testWidgets('compares with the week before', (tester) async {
    await pump(tester, fullWeekBundle());
    expect(
      find.textContaining('Compared with the 7 days before'),
      findsOneWidget,
    );
    expect(find.textContaining('Calories'), findsWidgets);
  });

  testWidgets('offline meal ideas from the pantry are listed', (tester) async {
    await pump(tester, fullWeekBundle());
    expect(find.textContaining('Uses '), findsWidgets);
    expect(find.textContaining('min'), findsWidgets);
    expect(
      find.textContaining('Assumes salt, oil and basic spices'),
      findsOneWidget,
    );
  });

  testWidgets('with nothing used it says so and still offers meal ideas', (
    tester,
  ) async {
    await pump(tester, emptyBundle());
    expect(find.textContaining('Nothing is marked as used'), findsOneWidget);
    expect(find.byType(BarChart), findsNothing);
    expect(find.text('Ask AI for a deeper review'), findsNothing);
    expect(find.text('Cook from your pantry'), findsOneWidget);
  });

  testWidgets('the target can be raised and lowered and is saved', (
    tester,
  ) async {
    await pump(tester, fullWeekBundle());
    expect(find.text('Target 2,000'), findsOneWidget);
    await tester.tap(find.byTooltip('Raise the daily target'));
    await tester.pumpAndSettle();
    expect(settings.values[kReportKcalTargetKey], '2100');
    await tester.tap(find.byTooltip('Lower the daily target'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Lower the daily target'));
    await tester.pumpAndSettle();
    expect(settings.values[kReportKcalTargetKey], '1900');
    expect(find.text('Target 1,900'), findsOneWidget);
  });

  group('the ICMR-NIN guide', () {
    testWidgets('the four reference adults are offered', (tester) async {
      await pump(tester, fullWeekBundle());
      for (final String chip in <String>[
        'Woman 1,660',
        'Man 2,080',
        'Woman, active 2,125',
        'Man, active 2,680',
      ]) {
        expect(find.text(chip), findsOneWidget, reason: chip);
      }
      expect(
        find.textContaining('Dietary Guidelines for Indians'),
        findsWidgets,
      );
    });

    testWidgets('choosing one sets the target and marks it chosen', (
      tester,
    ) async {
      await pump(tester, fullWeekBundle());
      await tester.tap(find.text('Man 2,080'));
      await tester.pumpAndSettle();
      expect(settings.values[kReportKcalTargetKey], '2080');
      expect(find.text('Target 2,080'), findsOneWidget);
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Man 2,080'))
            .selected,
        isTrue,
      );
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Woman 1,660'))
            .selected,
        isFalse,
      );
    });

    testWidgets('the protein guide follows the chosen adult', (tester) async {
      settings = FakeSettingsRepository(<String, String>{
        kReportKcalTargetKey: '2680',
      });
      await pump(tester, fullWeekBundle());
      expect(find.textContaining('of about 92 g'), findsOneWidget);
    });

    testWidgets('the plate lists every group with the amount used', (
      tester,
    ) async {
      await pump(tester, fullWeekBundle());
      for (final String group in <String>[
        'Grains and millets',
        'Dals and pulses',
        'Milk and curd',
        'Vegetables (without potato)',
        'Fruit',
        'Nuts and seeds',
        'Oils and ghee',
        'Sugar and jaggery',
      ]) {
        expect(find.text(group), findsWidgets, reason: group);
      }
      expect(
        find.textContaining('of up to'),
        findsWidgets,
        reason: 'oil and sugar are limits',
      );
      expect(find.text('Eggs'), findsNothing, reason: 'vegetarian');
    });

    testWidgets('with eggs the plate has an eggs line', (tester) async {
      await pump(tester, fullWeekBundle(), diet: RecipeDiet.egg);
      expect(find.text('Eggs'), findsOneWidget);
    });

    testWidgets('a person eating above the oil limit is shown the limit', (
      tester,
    ) async {
      await pump(
        tester,
        bundleFor(<ConsumptionEntry>[
          ...fullDayEntries(0),
          reportUsed('oil', 0.2, Unit.l),
        ], period: ReportPeriod.today),
      );
      expect(find.textContaining('Oil'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  group('exact amounts under each food', () {
    testWidgets('300 g of rice shows what is in 300 g', (tester) async {
      await pump(
        tester,
        bundleFor(
          <ConsumptionEntry>[reportUsed('rice', 300, Unit.g)],
          period: ReportPeriod.today,
          people: 1,
        ),
      );
      expect(
        find.text('Protein 21 g · Carbs 234 g · Fat 1.8 g · Fibre 3.9 g'),
        findsOneWidget,
      );
    });

    testWidgets('twice the rice shows twice the nutrients', (tester) async {
      await pump(
        tester,
        bundleFor(
          <ConsumptionEntry>[reportUsed('rice', 600, Unit.g)],
          period: ReportPeriod.today,
          people: 1,
        ),
      );
      expect(
        find.text('Protein 42 g · Carbs 468 g · Fat 3.6 g · Fibre 7.8 g'),
        findsOneWidget,
      );
    });

    testWidgets('a food whose amount cannot be weighed has no nutrient line', (
      tester,
    ) async {
      await pump(
        tester,
        bundleFor(<ConsumptionEntry>[
          reportUsed('rice', 300, Unit.g),
        ], period: ReportPeriod.today),
      );
      expect(find.textContaining('Protein 21 g'), findsOneWidget);
    });
  });

  testWidgets('the target stops at its limits', (tester) async {
    settings = FakeSettingsRepository(<String, String>{
      kReportKcalTargetKey: '1200',
    });
    await pump(tester, fullWeekBundle());
    final IconButton lower = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.remove_circle_outline_rounded),
    );
    expect(lower.onPressed, isNull);
  });

  testWidgets('sharing hands the summary to the share sheet', (tester) async {
    await pump(tester, fullWeekBundle());
    await tester.tap(find.byTooltip('Share this report'));
    await tester.pumpAndSettle();
    expect(share.shared.single, contains('Food report: 7 days'));
    expect(share.shared.single, contains('kcal per person a day'));
  });

  group('vegetarian or with eggs', () {
    testWidgets('both choices are offered, vegetarian first by default', (
      tester,
    ) async {
      await pump(tester, fullWeekBundle());
      final ChoiceChip veg = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'Vegetarian'),
      );
      final ChoiceChip eggs = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'With eggs'),
      );
      expect(veg.selected, isTrue);
      expect(eggs.selected, isFalse);
    });

    testWidgets('a person who eats eggs in Recipes starts with eggs on', (
      tester,
    ) async {
      await pump(tester, fullWeekBundle(), diet: RecipeDiet.egg);
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'With eggs'))
            .selected,
        isTrue,
      );
    });

    testWidgets('choosing with eggs is saved, and can be changed back', (
      tester,
    ) async {
      await pump(tester, fullWeekBundle());
      await tester.tap(find.text('With eggs'));
      await tester.pumpAndSettle();
      expect(settings.values[kReportEggsKey], 'true');
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'With eggs'))
            .selected,
        isTrue,
      );
      await tester.tap(find.text('Vegetarian'));
      await tester.pumpAndSettle();
      expect(settings.values[kReportEggsKey], 'false');
    });

    testWidgets('the saved choice beats the Recipes diet', (tester) async {
      settings = FakeSettingsRepository(<String, String>{
        kReportEggsKey: 'false',
      });
      await pump(tester, fullWeekBundle(), diet: RecipeDiet.egg);
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Vegetarian'))
            .selected,
        isTrue,
      );
    });

    testWidgets('with eggs on, egg dishes show up in the ideas', (
      tester,
    ) async {
      final ReportBundle b = bundleFor(<ConsumptionEntry>[
        ...fullDayEntries(0),
      ], vegetarian: false);
      expect(
        b.ideas.any((MealIdea i) => !i.dish.vegetarian),
        isTrue,
        reason: 'the bundle itself offers an egg dish',
      );
      await pump(tester, b, diet: RecipeDiet.egg);
      final MealIdea egg = b.ideas.firstWhere(
        (MealIdea i) => !i.dish.vegetarian,
      );
      expect(find.text(egg.dish.name), findsOneWidget);
    });

    testWidgets('as a vegetarian no egg dish is offered', (tester) async {
      final ReportBundle b = bundleFor(fullDayEntries(0));
      expect(b.ideas.every((MealIdea i) => i.dish.vegetarian), isTrue);
    });
  });

  group('the AI review', () {
    testWidgets('nothing is sent until the button is tapped', (tester) async {
      await pump(tester, fullWeekBundle());
      expect(backend.calls, 0);
      expect(find.text('Get AI review'), findsOneWidget);
      expect(
        find.textContaining('Uses 1 of your 50 daily AI calls'),
        findsOneWidget,
      );
    });

    testWidgets('tapping asks once, shows the answer and saves it', (
      tester,
    ) async {
      await pump(tester, fullWeekBundle());
      await tester.tap(find.text('Get AI review'));
      await tester.pumpAndSettle();
      expect(backend.calls, 1);
      expect(
        find.textContaining('Your plate leaned on rice and dal'),
        findsOneWidget,
      );
      expect(find.text('Write a new review'), findsOneWidget);
      expect(settings.values[kReportAiTextKey], kGoodReview);
    });

    testWidgets(
      'reopening the page shows the saved answer without a new call',
      (tester) async {
        await pump(tester, fullWeekBundle());
        await tester.tap(find.text('Get AI review'));
        await tester.pumpAndSettle();
        expect(backend.calls, 1);
        await pump(tester, fullWeekBundle());
        expect(
          find.textContaining('Your plate leaned on rice and dal'),
          findsOneWidget,
        );
        expect(backend.calls, 1);
      },
    );

    testWidgets('a different report does not show an old answer', (
      tester,
    ) async {
      settings = FakeSettingsRepository(<String, String>{
        kReportAiKeyKey: 'some|other|report',
        kReportAiTextKey: 'An old answer that no longer fits this report.',
      });
      await pump(tester, fullWeekBundle());
      expect(find.textContaining('An old answer'), findsNothing);
    });

    testWidgets('a failure says so kindly and keeps the offline report', (
      tester,
    ) async {
      backend = FakeReportBackend(<Object>[Exception('503 unavailable')]);
      await pump(tester, fullWeekBundle());
      await tester.tap(find.text('Get AI review'));
      await tester.pumpAndSettle();
      expect(backend.calls, 1, reason: 'no automatic retry');
      expect(
        find.textContaining('Everything above still works offline'),
        findsOneWidget,
      );
      expect(find.text('Calories each day'), findsOneWidget);
    });

    testWidgets('when AI is not available the button is off and says why', (
      tester,
    ) async {
      await pump(tester, fullWeekBundle(), aiReady: false);
      final FilledButton button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Get AI review'),
      );
      expect(button.onPressed, isNull);
      expect(find.textContaining('not set up'), findsOneWidget);
      expect(backend.calls, 0);
    });
  });

  group('looks right in tough conditions', () {
    testWidgets('a narrow phone with big text does not overflow', (
      tester,
    ) async {
      await pump(tester, fullWeekBundle(), width: 320, textScale: 1.6);
      expect(tester.takeException(), isNull);
      expect(find.text('Calories each day'), findsOneWidget);
    });

    testWidgets('dark mode renders', (tester) async {
      await pump(tester, fullWeekBundle(), dark: true);
      expect(tester.takeException(), isNull);
      expect(find.byType(BarChart), findsOneWidget);
    });

    testWidgets('a month view with thirty bars renders', (tester) async {
      await pump(
        tester,
        bundleFor(<ConsumptionEntry>[
          for (int d = 0; d < 20; d += 2) ...fullDayEntries(d),
        ], period: ReportPeriod.month),
      );
      expect(tester.takeException(), isNull);
      expect(find.textContaining('of 30 days'), findsOneWidget);
    });

    testWidgets('today view with one day renders', (tester) async {
      await pump(
        tester,
        bundleFor(fullDayEntries(0), period: ReportPeriod.today),
      );
      expect(tester.takeException(), isNull);
      expect(find.textContaining('per person today'), findsOneWidget);
    });
  });

  testWidgets('the period chips switch the view', (tester) async {
    final ProviderContainer c = await pump(tester, fullWeekBundle());
    await tester.tap(find.text('30 days'));
    await tester.pumpAndSettle();
    expect(c.read(reportPeriodProvider), ReportPeriod.month);
  });

  testWidgets('the daily summary is readable by a screen reader', (
    tester,
  ) async {
    final ReportBundle b = fullWeekBundle();
    final String summary = dailySummary(b.report.daily, 2000);
    expect(summary, contains('days logged'));
    expect(summary, contains('target 2,000'));
    expect(
      dailySummary(
        b.report.daily
            .map(
              (DailyPoint p) =>
                  DailyPoint(day: p.day, kcalPerPerson: 0, logged: false),
            )
            .toList(),
        2000,
      ),
      'No days with food marked as used.',
    );
  });
}
