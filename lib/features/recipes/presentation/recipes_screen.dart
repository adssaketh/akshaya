import 'package:akshaya/core/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/clock.dart';
import '../../../core/util/date_only.dart';
import '../../ai/domain/ai_gate.dart';
import '../../ai/presentation/ai_notice_dialog.dart';
import '../../ai/presentation/providers.dart';
import '../../commands/presentation/voice_mic_button.dart';
import '../../planner/presentation/meal_planner_screen.dart';
import '../domain/recipe_matcher.dart';
import '../domain/recipe_models.dart';
import '../domain/recipe_pantry.dart';
import 'preferences_sheet.dart';
import 'providers.dart';
import 'recipe_card.dart';
import 'recipe_detail_screen.dart';

enum _RecipesTab { ideas, saved }

/// The Recipes tab: ideas that use up what is expiring (from the AI, kept for
/// offline reading) and the recipes the household saved.
class RecipesScreen extends ConsumerStatefulWidget {
  const RecipesScreen({super.key});

  @override
  ConsumerState<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends ConsumerState<RecipesScreen> {
  _RecipesTab _tab = _RecipesTab.ideas;

  Future<void> _generate({bool force = false}) async {
    final bool ok = await ensureAiNotice(context, ref);
    if (!mounted) {
      return;
    }
    await ref
        .read(recipesControllerProvider.notifier)
        .generate(noticeAccepted: ok, force: force);
  }

  Future<void> _editPreferences() async {
    final RecipePreferences? updated = await showRecipePreferencesSheet(
      context,
      ref.read(recipePreferencesProvider),
    );
    if (updated == null || !mounted) {
      return;
    }
    await ref.read(recipesControllerProvider.notifier).savePreferences(updated);
  }

  void _open(Recipe recipe) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => RecipeDetailScreen(recipe: recipe),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        children: <Widget>[
          AkshayaHeader(
            actions: <Widget>[
              HeaderAction(
                tooltip: 'Meal plan',
                icon: Icons.calendar_month_rounded,
                onPressed: () => openMealPlanner(context),
              ),
              const VoiceMicButton(),
            ],
          ),
          ToolbarRow(
            child: SizedBox(
              width: double.infinity,
              child: AkshayaSegmented<_RecipesTab>(
                segments: const <AkshayaSegment<_RecipesTab>>[
                  AkshayaSegment<_RecipesTab>(
                    value: _RecipesTab.ideas,
                    label: 'Ideas',
                    icon: Icons.lightbulb_outline_rounded,
                  ),
                  AkshayaSegment<_RecipesTab>(
                    value: _RecipesTab.saved,
                    label: 'Saved',
                    icon: Icons.favorite_border_rounded,
                  ),
                ],
                selected: _tab,
                onChanged: (_RecipesTab t) => setState(() => _tab = t),
              ),
            ),
          ),
          Expanded(
            child: _tab == _RecipesTab.ideas
                ? _IdeasTab(
                    onGenerate: _generate,
                    onEditPreferences: _editPreferences,
                    onOpen: _open,
                  )
                : _SavedTab(onOpen: _open),
          ),
        ],
      ),
    );
  }
}

class _IdeasTab extends ConsumerWidget {
  const _IdeasTab({
    required this.onGenerate,
    required this.onEditPreferences,
    required this.onOpen,
  });

  final Future<void> Function({bool force}) onGenerate;
  final VoidCallback onEditPreferences;
  final void Function(Recipe recipe) onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TextTheme text = context.akText;
    final AkshayaColors colors = context.akColors;
    final RecipePreferences prefs = ref.watch(recipePreferencesProvider);
    final RecipesUiState ui = ref.watch(recipesControllerProvider);
    final List<PantryLine> lines = ref.watch(pantryLinesProvider);
    final Map<String, int> expiring = ref.watch(expiringDaysProvider);
    final RecipeCacheEntry? cache = ref.watch(recipeCacheProvider).value;
    final List<RankedRecipe> ideas = ref.watch(rankedIdeasProvider);
    final bool upToDate = ref.watch(ideasUpToDateProvider);
    final AiAvailability availability = ref.watch(aiAvailabilityProvider);
    final DateTime today = ref.watch(todayProvider);
    final bool hasFood = RecipePantry.stocked(lines).isNotEmpty;

    final List<PantryLine> useFirst = <PantryLine>[
      for (final PantryLine l in lines)
        if (expiring.containsKey(l.itemId)) l,
    ];

    // Why AI cannot run, shown next to the button (the cached ideas stay).
    final String? note = ui.message ??
        (availability.isReady ? null : availability.message);

    return ListView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xxl + context.navClearance,
      ),
      children: <Widget>[
        Material(
          color: colors.surface,
          borderRadius: AppRadius.cardBorder,
          child: InkWell(
            borderRadius: AppRadius.cardBorder,
            onTap: onEditPreferences,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: <Widget>[
                  Icon(Icons.tune_rounded, color: colors.primary),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(prefs.summary, style: text.titleSmall),
                        if (prefs.avoid.isNotEmpty)
                          Text(
                            'Avoiding ${prefs.avoid.join(', ')}',
                            style: text.bodySmall
                                ?.copyWith(color: colors.textSecondary),
                          ),
                      ],
                    ),
                  ),
                  Text('Change', style: text.labelLarge),
                ],
              ),
            ),
          ),
        ),
        if (useFirst.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          const SectionHeader(title: 'Use these first'),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              for (final PantryLine l in useFirst)
                Chip(
                  label: Text('${l.name} · ${_days(expiring[l.itemId] ?? 0)}'),
                ),
            ],
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        if (!hasFood && ideas.isEmpty)
          const EmptyState(
            icon: Icons.soup_kitchen_rounded,
            title: 'Your pantry is empty',
            body: 'Add some food to the pantry and Akshaya will suggest '
                'recipes that use it up.',
          )
        else ...<Widget>[
          if (ui.busy)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            FilledButton.icon(
              onPressed: hasFood
                  ? () => onGenerate(force: upToDate && cache != null)
                  : null,
              icon: Icon(
                upToDate ? Icons.refresh_rounded : Icons.auto_awesome_rounded,
              ),
              label: Text(
                upToDate && cache != null
                    ? 'Ask again anyway'
                    : 'Get recipe ideas',
              ),
            ),
          if (note != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            _Note(text: note),
          ],
          if (cache != null && !ui.busy) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(
              upToDate
                  ? 'Ideas made ${_when(cache.generatedAt, today)}.'
                  : 'Ideas made ${_when(cache.generatedAt, today)}. Your pantry has '
                      'changed since.',
              style: text.bodySmall?.copyWith(color: colors.textSecondary),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          if (ideas.isEmpty && !ui.busy)
            const EmptyState(
              icon: Icons.lightbulb_outline_rounded,
              title: 'No ideas yet',
              body: 'Tap "Get recipe ideas" to see what you can cook with '
                  'what you have. Only item names, amounts and dates are sent.',
            )
          else
            for (final (int i, RankedRecipe r) in ideas.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: RecipeCard(
                  ranked: r,
                  revealIndex: i,
                  onTap: () => onOpen(r.recipe),
                ),
              ),
        ],
      ],
    );
  }

  static String _days(int days) {
    if (days < 0) {
      return 'expired';
    }
    if (days == 0) {
      return 'today';
    }
    return days == 1 ? '1 day' : '$days days';
  }

  static String _when(DateTime at, DateTime today) {
    final int diff = daysBetween(dateOnly(at), today);
    if (diff <= 0) {
      return 'today';
    }
    return diff == 1 ? 'yesterday' : '$diff days ago';
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final AkshayaColors colors = context.akColors;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.surfaceAlt,
        borderRadius: AppRadius.controlBorder,
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.info_outline_rounded, color: colors.textSecondary),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(text, style: context.akText.bodyMedium)),
        ],
      ),
    );
  }
}

class _SavedTab extends ConsumerWidget {
  const _SavedTab({required this.onOpen});

  final void Function(Recipe recipe) onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<SavedRecipe>> saved =
        ref.watch(savedRecipesProvider);
    return saved.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object error, StackTrace stackTrace) => const EmptyState(
        icon: Icons.error_outline_rounded,
        title: 'Could not load saved recipes',
        body: 'Please try again in a moment.',
      ),
      data: (List<SavedRecipe> list) {
        if (list.isEmpty) {
          return const EmptyState(
            icon: Icons.favorite_border_rounded,
            title: 'No saved recipes',
            body: 'Tap the heart on a recipe to keep it here, shared with '
                'your household.',
          );
        }
        return ListView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.xxl + context.navClearance,
          ),
          children: <Widget>[
            for (final (int i, SavedRecipe s) in list.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: RecipeCard(
                  revealIndex: i,
                  ranked: rankOne(ref, s.recipe),
                  onTap: () => onOpen(s.recipe),
                ),
              ),
          ],
        );
      },
    );
  }
}
