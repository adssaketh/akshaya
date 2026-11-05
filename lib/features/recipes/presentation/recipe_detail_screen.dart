import 'package:akshaya/core/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/clock.dart';
import '../../../core/ui/feedback.dart';
import '../../pantry/domain/pantry_repository.dart';
import '../../pantry/presentation/providers.dart';
import '../../shopping/domain/shopping_entities.dart';
import '../../shopping/presentation/providers.dart';
import '../domain/cook_plan.dart';
import '../domain/recipe_matcher.dart';
import '../domain/recipe_models.dart';
import '../domain/recipe_repository.dart';
import '../domain/recipe_shopping.dart';
import 'cook_sheet.dart';
import 'providers.dart';

/// One recipe: ingredients against the live pantry, steps, keep/unkeep,
/// "Add missing to shopping list" and "I cooked this".
class RecipeDetailScreen extends ConsumerWidget {
  const RecipeDetailScreen({super.key, required this.recipe});

  final Recipe recipe;

  SavedRecipe? _savedCopy(List<SavedRecipe> saved) {
    for (final SavedRecipe s in saved) {
      if (s.recipe.contentKey == recipe.contentKey) {
        return s;
      }
    }
    return null;
  }

  Future<void> _toggleSaved(
    BuildContext context,
    WidgetRef ref,
    RankedRecipe ranked,
    SavedRecipe? existing,
  ) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final RecipeRepository repository = ref.read(recipeRepositoryProvider);
    try {
      if (existing != null) {
        await repository.unsave(existing.id);
        showUndoSnackBar(
          messenger,
          message: 'Removed from saved recipes.',
          onUndo: () => repository.undoUnsave(existing.id),
        );
        return;
      }
      // Remember which pantry item each ingredient matched, as a hint.
      final List<RecipeIngredient> hinted = <RecipeIngredient>[
        for (final IngredientMatch m in ranked.matches)
          m.itemId == null
              ? m.ingredient
              : m.ingredient.withItemId(m.itemId),
      ];
      await repository.save(recipe.copyWith(ingredients: hinted));
      showMessage(messenger, 'Saved to your recipes.');
    } on Object catch (error) {
      showMessage(messenger, failureMessage(error));
    }
  }

  Future<void> _addMissing(
    BuildContext context,
    WidgetRef ref,
    RankedRecipe ranked,
  ) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final String listId =
        ref.read(selectedListProvider)?.id ?? kDefaultListId;
    final List<ShoppingEntryDraft> drafts = RecipeShoppingPlanner.drafts(
      recipe: recipe,
      matches: ranked.matches,
      listId: listId,
    );
    if (drafts.isEmpty) {
      showMessage(messenger, 'Nothing is missing.');
      return;
    }
    try {
      await ref.read(shoppingRepositoryProvider).addEntries(drafts);
      showMessage(
        messenger,
        drafts.length == 1
            ? 'Added 1 item to your shopping list.'
            : 'Added ${drafts.length} items to your shopping list.',
      );
    } on Object catch (error) {
      showMessage(messenger, failureMessage(error));
    }
  }

  Future<void> _cooked(
    BuildContext context,
    WidgetRef ref,
    RankedRecipe ranked,
  ) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final CookSheetResult? result =
        await showCookSheet(context, CookPlanner.plan(ranked.matches));
    if (result == null || result.requests.isEmpty) {
      return;
    }
    final PantryRepository pantry = ref.read(pantryRepositoryProvider);
    final CookOutcome outcome = await CookExecutor.run(
      pantry,
      result.requests,
      leftover: result.leftover,
      recipeTitle: recipe.title,
      today: ref.read(todayProvider),
    );
    if (outcome.failures.isNotEmpty) {
      showMessage(
        messenger,
        'Some items could not be used: ${outcome.failures.join(' ')}',
      );
      return;
    }
    showUndoSnackBar(
      messenger,
      message: (outcome.usedCount == 1
              ? 'Took 1 item out of your pantry.'
              : 'Took ${outcome.usedCount} items out of your pantry.') +
          (outcome.leftover != null ? ' Leftovers saved.' : ''),
      onUndo: () => CookExecutor.undo(pantry, outcome),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TextTheme text = context.akText;
    final AkshayaColors colors = context.akColors;
    final RankedRecipe ranked = rankOne(ref, recipe);
    final SavedRecipe? saved = _savedCopy(
      ref.watch(savedRecipesProvider).value ?? const <SavedRecipe>[],
    );
    final bool anyMissing = ranked.missingCount > 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(recipe.title, overflow: TextOverflow.ellipsis),
        actions: <Widget>[
          IconButton(
            tooltip: saved == null ? 'Save recipe' : 'Remove from saved',
            onPressed: () => _toggleSaved(context, ref, ranked, saved),
            icon: Icon(
              saved == null
                  ? Icons.favorite_border_rounded
                  : Icons.favorite_rounded,
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Row(
            children: <Widget>[
              if (anyMissing) ...<Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _addMissing(context, ref, ranked),
                    icon: const Icon(Icons.add_shopping_cart_rounded),
                    label: const Text('Add missing'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
              ],
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _cooked(context, ref, ranked),
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('I cooked this'),
                ),
              ),
            ],
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: <Widget>[
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              _Fact(icon: Icons.schedule_rounded, text: '${recipe.timeMinutes} min'),
              _Fact(
                icon: Icons.people_alt_rounded,
                text: recipe.servings == 1
                    ? 'Serves 1'
                    : 'Serves ${recipe.servings}',
              ),
              _Fact(icon: Icons.eco_rounded, text: recipe.diet.label),
              if (recipe.cuisine != null)
                _Fact(icon: Icons.public_rounded, text: recipe.cuisine!),
            ],
          ),
          if (ranked.expiringUsed.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: <Widget>[
                const StatusChip(kind: StatusKind.expiring, label: 'Uses up'),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    ranked.expiringUsed.join(', '),
                    style: text.bodyMedium,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          const SectionHeader(title: 'Ingredients'),
          for (final IngredientMatch m in ranked.matches)
            _IngredientRow(match: m),
          const SizedBox(height: AppSpacing.lg),
          const SectionHeader(title: 'Steps'),
          for (int i = 0; i < recipe.steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  CircleAvatar(
                    radius: AppSpacing.md,
                    backgroundColor: colors.surfaceAlt,
                    child: Text('${i + 1}', style: text.labelMedium),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(child: Text(recipe.steps[i], style: text.bodyLarge)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: AppSizes.iconSm),
      label: Text(text),
    );
  }
}

class _IngredientRow extends StatelessWidget {
  const _IngredientRow({required this.match});

  final IngredientMatch match;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = context.akText;
    final AkshayaColors colors = context.akColors;
    final String amount = match.ingredient.quantityLabel;
    final Widget status;
    switch (match.availability) {
      case IngredientAvailability.inPantry:
        status = const StatusChip(kind: StatusKind.fresh, label: 'In pantry');
      case IngredientAvailability.short:
        status = const StatusChip(kind: StatusKind.lowStock, label: 'Short');
      case IngredientAvailability.missing:
        status =
            const StatusChip(kind: StatusKind.outOfStock, label: 'Missing');
      case IngredientAvailability.assumed:
        status = Text(
          'Assumed',
          style: text.labelMedium?.copyWith(color: colors.textSecondary),
        );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSizes.touchTarget),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(match.ingredient.name, style: text.bodyLarge),
                  if (amount.isNotEmpty)
                    Text(
                      amount,
                      style: text.bodySmall
                          ?.copyWith(color: colors.textSecondary),
                    ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            status,
          ],
        ),
      ),
    );
  }
}
