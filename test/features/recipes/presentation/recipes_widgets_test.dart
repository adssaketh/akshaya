import 'dart:async';

import 'package:akshaya/core/design/design.dart';
import 'package:akshaya/core/time/clock.dart';
import 'package:akshaya/features/ai/domain/ai_command_service.dart';
import 'package:akshaya/features/ai/domain/ai_settings.dart';
import 'package:akshaya/features/commands/presentation/providers.dart';
import 'package:akshaya/features/pantry/domain/consumption_type.dart';
import 'package:akshaya/features/pantry/domain/entities.dart';
import 'package:akshaya/features/pantry/domain/unit.dart';
import 'package:akshaya/features/pantry/presentation/providers.dart';
import 'package:akshaya/features/recipes/domain/ai_recipe_service.dart';
import 'package:akshaya/features/recipes/domain/recipe_models.dart';
import 'package:akshaya/features/recipes/domain/recipe_repository.dart';
import 'package:akshaya/features/recipes/presentation/providers.dart';
import 'package:akshaya/features/recipes/presentation/recipe_detail_screen.dart';
import 'package:akshaya/features/recipes/presentation/recipes_screen.dart';
import 'package:akshaya/features/settings/presentation/providers.dart';
import 'package:akshaya/features/shopping/domain/shopping_entities.dart';
import 'package:akshaya/features/shopping/presentation/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../ai/domain/ai_test_support.dart';
import '../../pantry/presentation/fake_repository.dart';
import '../../settings/fake_settings_repository.dart';
import '../../shopping/presentation/fake_shopping_repository.dart';
import '../domain/recipe_test_support.dart';

/// In-memory recipes, behaving like the database (streams re-emit).
class FakeRecipeRepository implements RecipeRepository {
  FakeRecipeRepository({this.cache});

  final List<SavedRecipe> _saved = <SavedRecipe>[];
  RecipeCacheEntry? cache;
  final StreamController<void> _changes = StreamController<void>.broadcast();
  final Set<String> removed = <String>{};

  @override
  Stream<List<SavedRecipe>> watchSaved() async* {
    yield _live();
    yield* _changes.stream.map((_) => _live());
  }

  List<SavedRecipe> _live() => <SavedRecipe>[
        for (final SavedRecipe s in _saved)
          if (!removed.contains(s.id)) s,
      ];

  @override
  Future<SavedRecipe> save(Recipe recipe) async {
    final SavedRecipe s = SavedRecipe(
      id: 's-${_saved.length}',
      recipe: recipe,
      savedAt: DateTime(2026, 11, 4),
    );
    _saved.add(s);
    _changes.add(null);
    return s;
  }

  @override
  Future<void> unsave(String savedId) async {
    removed.add(savedId);
    _changes.add(null);
  }

  @override
  Future<void> undoUnsave(String savedId) async {
    removed.remove(savedId);
    _changes.add(null);
  }

  @override
  Stream<RecipeCacheEntry?> watchCache() async* {
    yield cache;
    yield* _changes.stream.map((_) => cache);
  }

  @override
  Future<RecipeCacheEntry?> readCache() async => cache;

  @override
  Future<void> writeCache(RecipeCacheEntry entry) async {
    cache = entry;
    _changes.add(null);
  }
}

/// Pantry that also supports using stock (for "I cooked this").
class CookingPantry extends FakePantryRepository {
  CookingPantry({required super.items});

  final List<({String itemId, double quantity, Unit unit, ConsumptionType type})>
      used = <({String itemId, double quantity, Unit unit, ConsumptionType type})>[];
  final List<UseResult> undone = <UseResult>[];

  @override
  Future<UseResult> useStock({
    required String itemId,
    required double quantity,
    required Unit unit,
    ConsumptionType type = ConsumptionType.used,
  }) async {
    used.add((itemId: itemId, quantity: quantity, unit: unit, type: type));
    return UseResult(
      itemId: itemId,
      quantity: quantity,
      unit: unit,
      type: type,
      applied: const <AppliedDeduction>[],
    );
  }

  @override
  Future<void> undoUse(UseResult result) async => undone.add(result);
}

void main() {
  final DateTime now = DateTime(2026, 11, 4, 10);

  List<ItemWithBatches> pantryItems() => <ItemWithBatches>[
        stocked('rice', 'Rice', qty: 5),
        stocked('tom', 'Tomato', qty: 3, unit: Unit.pcs, expiry: DateTime(2026, 11, 5)),
      ];

  final Recipe tomatoRice = recipeOf('Tomato Rice', const <RecipeIngredient>[
    RecipeIngredient(name: 'Rice', quantity: 500, unit: Unit.g),
    RecipeIngredient(name: 'Tomato', quantity: 2, unit: Unit.pcs),
    RecipeIngredient(name: 'Ginger', quantity: 1, unit: Unit.pcs),
    RecipeIngredient(name: 'Salt'),
  ]);
  final Recipe plainRice = recipeOf('Plain Rice', const <RecipeIngredient>[
    RecipeIngredient(name: 'Rice', quantity: 1, unit: Unit.kg),
  ]);

  void bigScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Widget host({
    required Widget home,
    required FakeRecipeRepository recipes,
    required FakePantryRepository pantry,
    FakeShoppingRepository? shopping,
    Map<String, String> settings = const <String, String>{},
  }) {
    return ProviderScope(
      overrides: [
        recipeRepositoryProvider.overrideWithValue(recipes),
        pantryRepositoryProvider.overrideWithValue(pantry),
        shoppingRepositoryProvider
            .overrideWithValue(shopping ?? FakeShoppingRepository()),
        settingsRepositoryProvider
            .overrideWithValue(FakeSettingsRepository(settings)),
        groceryLexiconProvider.overrideWithValue(null),
        clockProvider.overrideWithValue(() => now),
      ],
      child: MaterialApp(theme: AkshayaTheme.light(), home: home),
    );
  }

  RecipeCacheEntry cacheOf(List<Recipe> list, {String fingerprint = 'old'}) {
    return RecipeCacheEntry(
      fingerprint: fingerprint,
      recipes: list,
      generatedAt: DateTime(2026, 11, 3, 9),
    );
  }

  testWidgets('cached ideas are shown ranked by expiring food, offline',
      (WidgetTester tester) async {
    bigScreen(tester);
    await tester.pumpWidget(
      host(
        home: const Scaffold(body: RecipesScreen()),
        recipes: FakeRecipeRepository(
          cache: cacheOf(<Recipe>[plainRice, tomatoRice]),
        ),
        pantry: FakePantryRepository(items: pantryItems()),
      ),
    );
    await tester.pumpAndSettle();

    // Tomato expires tomorrow, so the recipe that uses it comes first.
    final double tomatoY = tester.getTopLeft(find.text('Tomato Rice')).dy;
    final double plainY = tester.getTopLeft(find.text('Plain Rice')).dy;
    expect(tomatoY, lessThan(plainY));
    expect(find.text('Uses 1 expiring'), findsOneWidget);
    expect(find.text('Ready to cook'), findsOneWidget);
    expect(find.text('Use these first'), findsOneWidget);
    // AI cannot run in tests (no Firebase config): the reason is shown and
    // the cached ideas stay.
    expect(find.textContaining('using offline mode'), findsOneWidget);
  });

  testWidgets('AI declined: the screen says so and keeps the cache',
      (WidgetTester tester) async {
    bigScreen(tester);
    await tester.pumpWidget(
      host(
        home: const Scaffold(body: RecipesScreen()),
        recipes: FakeRecipeRepository(cache: cacheOf(<Recipe>[plainRice])),
        pantry: FakePantryRepository(items: pantryItems()),
        settings: const <String, String>{AiSettingKeys.enabled: 'false'},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('AI is turned off, using offline mode.'), findsOneWidget);
    await tester.tap(find.text('Get recipe ideas'));
    await tester.pumpAndSettle();
    expect(find.text('Plain Rice'), findsOneWidget);
    expect(find.text('AI is turned off, using offline mode.'), findsOneWidget);
  });

  testWidgets('an empty pantry explains what to do',
      (WidgetTester tester) async {
    bigScreen(tester);
    await tester.pumpWidget(
      host(
        home: const Scaffold(body: RecipesScreen()),
        recipes: FakeRecipeRepository(),
        pantry: FakePantryRepository(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Your pantry is empty'), findsOneWidget);
  });

  testWidgets('saved recipes appear on the Saved segment',
      (WidgetTester tester) async {
    bigScreen(tester);
    final FakeRecipeRepository repo = FakeRecipeRepository();
    await repo.save(plainRice);
    await tester.pumpWidget(
      host(
        home: const Scaffold(body: RecipesScreen()),
        recipes: repo,
        pantry: FakePantryRepository(items: pantryItems()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Saved'));
    await tester.pumpAndSettle();
    expect(find.text('Plain Rice'), findsOneWidget);
  });

  testWidgets('detail: saving a recipe keeps it, with Undo on removal',
      (WidgetTester tester) async {
    bigScreen(tester);
    final FakeRecipeRepository repo = FakeRecipeRepository();
    await tester.pumpWidget(
      host(
        home: RecipeDetailScreen(recipe: tomatoRice),
        recipes: repo,
        pantry: FakePantryRepository(items: pantryItems()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Save recipe'));
    await tester.pumpAndSettle();
    final List<SavedRecipe> saved = await repo.watchSaved().first;
    expect(saved.length, 1);
    // The matched pantry item is remembered as a hint.
    expect(saved.single.recipe.ingredients.first.itemId, 'rice');

    await tester.tap(find.byTooltip('Remove from saved'));
    await tester.pumpAndSettle();
    expect(repo.removed, <String>{'s-0'});
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(repo.removed, isEmpty);
  });

  testWidgets('detail: Add missing puts only what is missing on the list',
      (WidgetTester tester) async {
    bigScreen(tester);
    final FakeShoppingRepository shopping = FakeShoppingRepository();
    await tester.pumpWidget(
      host(
        home: RecipeDetailScreen(recipe: tomatoRice),
        recipes: FakeRecipeRepository(),
        pantry: FakePantryRepository(items: pantryItems()),
        shopping: shopping,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('In pantry'), findsNWidgets(2));
    expect(find.text('Missing'), findsOneWidget);
    expect(find.text('Assumed'), findsOneWidget);

    await tester.tap(find.text('Add missing'));
    await tester.pumpAndSettle();

    expect(shopping.addedDrafts.length, 1);
    expect(shopping.addedDrafts.single.name, 'Ginger');
    expect(shopping.addedDrafts.single.listId, kDefaultListId);
    expect(find.text('Added 1 item to your shopping list.'), findsOneWidget);
  });

  testWidgets('detail: a covered recipe has no Add missing button',
      (WidgetTester tester) async {
    bigScreen(tester);
    await tester.pumpWidget(
      host(
        home: RecipeDetailScreen(recipe: plainRice),
        recipes: FakeRecipeRepository(),
        pantry: FakePantryRepository(items: pantryItems()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Add missing'), findsNothing);
    expect(find.text('I cooked this'), findsOneWidget);
  });

  testWidgets('I cooked this: confirm, deduct as cooked in recipe, undo',
      (WidgetTester tester) async {
    bigScreen(tester);
    final CookingPantry pantry = CookingPantry(items: pantryItems());
    await tester.pumpWidget(
      host(
        home: RecipeDetailScreen(recipe: tomatoRice),
        recipes: FakeRecipeRepository(),
        pantry: pantry,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('I cooked this'));
    await tester.pumpAndSettle();

    // The confirmation lists the pantry items and their amounts.
    expect(find.text('Rice'), findsWidgets);
    expect(find.text('Take out of pantry'), findsOneWidget);
    expect(pantry.used, isEmpty);

    // Untick the tomatoes, keep the rice.
    final Finder boxes = find.byType(Checkbox);
    expect(boxes, findsNWidgets(2));
    await tester.tap(boxes.last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Take out of pantry'));
    await tester.pumpAndSettle();

    expect(pantry.used.length, 1);
    expect(pantry.used.single.itemId, 'rice');
    expect(pantry.used.single.quantity, 500);
    expect(pantry.used.single.unit, Unit.g);
    expect(pantry.used.single.type, ConsumptionType.cookedInRecipe);
    expect(find.text('Took 1 item out of your pantry.'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(pantry.undone.length, 1);
  });

  testWidgets('I cooked this: nothing is used when cancelled',
      (WidgetTester tester) async {
    bigScreen(tester);
    final CookingPantry pantry = CookingPantry(items: pantryItems());
    await tester.pumpWidget(
      host(
        home: RecipeDetailScreen(recipe: plainRice),
        recipes: FakeRecipeRepository(),
        pantry: pantry,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('I cooked this'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(pantry.used, isEmpty);
  });

  group('RecipesController', () {
    late FakeRecipeRepository repo;
    late FakeRecipeBackend backend;

    ProviderContainer container({
      AiSettings settings = const AiSettings(noticeAccepted: true),
      MemoryUsageStore? usage,
      List<ItemWithBatches>? items,
    }) {
      repo = FakeRecipeRepository();
      backend = FakeRecipeBackend(<Object>[kGoodRecipesJson]);
      final AiCommandService guard = AiCommandService(
        backend: FakeBackend(<Object>[kGoodJson]),
        usageStore: usage ?? MemoryUsageStore(),
        readSettings: () => settings,
        promptTemplate: kTestPrompt,
        firebaseConfigured: true,
        now: () => now,
        delay: (Duration d) async {},
      );
      final ProviderContainer c = ProviderContainer(
        overrides: [
          recipeRepositoryProvider.overrideWithValue(repo),
          pantryRepositoryProvider.overrideWithValue(
            FakePantryRepository(items: items ?? pantryItems()),
          ),
          settingsRepositoryProvider
              .overrideWithValue(FakeSettingsRepository()),
          groceryLexiconProvider.overrideWithValue(null),
          clockProvider.overrideWithValue(() => now),
          aiRecipeServiceProvider.overrideWithValue(
            AiRecipeService(
              guard: guard,
              backend: backend,
              promptTemplate: '{{pantry}}',
              now: () => now,
            ),
          ),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    Future<void> ready(ProviderContainer c) async {
      // Providers nobody listens to are paused, so keep the ones the
      // controller reads alive until their first values have arrived.
      c
        ..listen(pantryLinesProvider, (previous, next) {})
        ..listen(recipePreferencesProvider, (previous, next) {})
        ..listen(itemsStreamProvider, (previous, next) {})
        ..listen(settingsMapProvider, (previous, next) {});
      await c.read(itemsStreamProvider.future);
      await c.read(settingsMapProvider.future);
    }

    test('generates, caches, and does not ask again for the same pantry',
        () async {
      final ProviderContainer c = container();
      await ready(c);
      final RecipesController controller =
          c.read(recipesControllerProvider.notifier);

      await controller.generate(noticeAccepted: true);
      expect(backend.calls, 1);
      expect(c.read(recipesControllerProvider).message, isNull);
      final RecipeCacheEntry? cached = await repo.readCache();
      expect(cached!.recipes.single.title, 'Tomato Rice');

      await controller.generate(noticeAccepted: true);
      expect(backend.calls, 1);
      expect(
        c.read(recipesControllerProvider).message,
        contains('has not changed'),
      );

      await controller.generate(noticeAccepted: true, force: true);
      expect(backend.calls, 2);
    });

    test('a changed pantry asks again', () async {
      final ProviderContainer c = container();
      await ready(c);
      final RecipesController controller =
          c.read(recipesControllerProvider.notifier);
      await controller.generate(noticeAccepted: true);
      // Same preferences but different stock: a different fingerprint.
      await repo.writeCache(
        RecipeCacheEntry(
          fingerprint: 'stale',
          recipes: <Recipe>[plainRice],
          generatedAt: now,
        ),
      );
      await controller.generate(noticeAccepted: true);
      expect(backend.calls, 2);
      expect((await repo.readCache())!.recipes.single.title, 'Tomato Rice');
    });

    test('at the daily cap nothing is sent and the cache is untouched',
        () async {
      final ProviderContainer c = container(
        usage: MemoryUsageStore(
          const AiUsage(date: '2026-11-04', count: kDefaultAiDailyCap),
        ),
      );
      await ready(c);
      await repo.writeCache(cacheOf(<Recipe>[plainRice]));
      await c
          .read(recipesControllerProvider.notifier)
          .generate(noticeAccepted: true);
      expect(backend.calls, 0);
      expect(
        c.read(recipesControllerProvider).message,
        'AI limit reached for today, using offline mode.',
      );
      expect((await repo.readCache())!.recipes.single.title, 'Plain Rice');
    });

    test('a bad answer becomes a message and keeps the last ideas', () async {
      final ProviderContainer c = container();
      await ready(c);
      backend.script
        ..clear()
        ..add('sorry');
      await repo.writeCache(cacheOf(<Recipe>[plainRice]));
      await c
          .read(recipesControllerProvider.notifier)
          .generate(noticeAccepted: true);
      expect(
        c.read(recipesControllerProvider).message,
        contains('could not use'),
      );
      expect(c.read(recipesControllerProvider).busy, isFalse);
      expect((await repo.readCache())!.recipes.single.title, 'Plain Rice');
    });

    test('declining the notice sends nothing', () async {
      final ProviderContainer c = container();
      await ready(c);
      await c
          .read(recipesControllerProvider.notifier)
          .generate(noticeAccepted: false);
      expect(backend.calls, 0);
      expect(
        c.read(recipesControllerProvider).message,
        'AI is turned off, using offline mode.',
      );
    });

    test('an empty pantry is not sent', () async {
      final ProviderContainer c = container(items: const <ItemWithBatches>[]);
      await ready(c);
      await c
          .read(recipesControllerProvider.notifier)
          .generate(noticeAccepted: true);
      expect(backend.calls, 0);
      expect(
        c.read(recipesControllerProvider).message,
        'Add some food to your pantry first.',
      );
    });
  });
}
