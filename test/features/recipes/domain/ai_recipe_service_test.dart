import 'package:akshaya/features/ai/domain/ai_command_service.dart';
import 'package:akshaya/features/ai/domain/ai_failures.dart';
import 'package:akshaya/features/ai/domain/ai_settings.dart';
import 'package:akshaya/features/pantry/domain/entities.dart';
import 'package:akshaya/features/recipes/domain/ai_recipe_service.dart';
import 'package:akshaya/features/recipes/domain/recipe_models.dart';
import 'package:akshaya/features/recipes/domain/recipe_pantry.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../ai/domain/ai_test_support.dart';
import 'recipe_test_support.dart';

void main() {
  late DateTime clock;
  late MemoryUsageStore usage;
  AiSettings settings = const AiSettings(noticeAccepted: true);

  AiRecipeService build(FakeRecipeBackend backend) {
    final AiCommandService guard = AiCommandService(
      backend: FakeBackend(<Object>[kGoodJson]),
      usageStore: usage,
      readSettings: () => settings,
      promptTemplate: kTestPrompt,
      firebaseConfigured: true,
      now: () => clock,
      delay: (Duration d) async {},
    );
    return AiRecipeService(
      guard: guard,
      backend: backend,
      promptTemplate: 'today={{today}} {{pantry}}',
      now: () => clock,
    );
  }

  final List<PantryLine> pantry = linesFor(<ItemWithBatches>[
    stocked('rice', 'Rice'),
  ]);

  Future<List<Recipe>> run(AiRecipeService s, {RecipePreferences? prefs}) {
    return s.generate(
      pantry: pantry,
      preferences: prefs ?? const RecipePreferences(),
    );
  }

  setUp(() {
    clock = DateTime(2026, 11, 4, 10);
    usage = MemoryUsageStore();
    settings = const AiSettings(noticeAccepted: true);
  });

  test('a good answer is validated, filtered by diet and counted once',
      () async {
    final FakeRecipeBackend backend =
        FakeRecipeBackend(<Object>[kGoodRecipesJson]);
    final List<Recipe> recipes = await run(build(backend));
    expect(recipes.map((Recipe r) => r.title).toList(), <String>['Tomato Rice']);
    expect(backend.calls, 1);
    expect(backend.lastPrompt, contains('today=2026-11-04'));
    expect(backend.lastPrompt, contains('- Rice: 1 kg'));
    expect(usage.usage.countOn(DateTime(2026, 11, 4)), 1);
  });

  test('an unusable answer is not retried and still counts', () async {
    final FakeRecipeBackend backend = FakeRecipeBackend(<Object>['sorry']);
    await expectLater(
      run(build(backend)),
      throwsA(isA<AiInvalidResponseFailure>()),
    );
    expect(backend.calls, 1);
    expect(usage.usage.countOn(DateTime(2026, 11, 4)), 1);
  });

  test('when nothing fits the diet the answer is rejected', () async {
    final FakeRecipeBackend backend = FakeRecipeBackend(<Object>[
      '{"recipes":[{"title":"Egg Curry","time_minutes":30,"servings":2,'
          '"diet":"egg","ingredients":[{"name":"Egg"}],"steps":["Boil."]}]}',
    ]);
    await expectLater(
      run(build(backend)),
      throwsA(isA<AiInvalidResponseFailure>()),
    );
  });

  test('the daily cap stops the call before it is made', () async {
    usage = MemoryUsageStore(
      AiUsage(date: '2026-11-04', count: settings.dailyCap),
    );
    final FakeRecipeBackend backend =
        FakeRecipeBackend(<Object>[kGoodRecipesJson]);
    await expectLater(
      run(build(backend)),
      throwsA(isA<AiUnavailableFailure>()),
    );
    expect(backend.calls, 0);
  });

  test('AI switched off means no call', () async {
    settings = const AiSettings(enabled: false, noticeAccepted: true);
    final FakeRecipeBackend backend =
        FakeRecipeBackend(<Object>[kGoodRecipesJson]);
    await expectLater(
      run(build(backend)),
      throwsA(isA<AiUnavailableFailure>()),
    );
    expect(backend.calls, 0);
  });

  test('an empty pantry is refused without a call', () async {
    final FakeRecipeBackend backend =
        FakeRecipeBackend(<Object>[kGoodRecipesJson]);
    await expectLater(
      build(backend).generate(
        pantry: const <PantryLine>[],
        preferences: const RecipePreferences(),
      ),
      throwsA(isA<AiInvalidResponseFailure>()),
    );
    expect(backend.calls, 0);
  });
}
