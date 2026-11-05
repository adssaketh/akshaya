import 'package:akshaya/core/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../recipes/domain/recipe_models.dart';
import '../../recipes/domain/recipe_pantry.dart';
import '../../recipes/presentation/providers.dart';
import '../domain/meal_plan_models.dart';
import '../domain/meal_slot.dart';
import '../domain/prep_rules.dart';

/// Lets the person choose what goes in a slot: free text, a leftover, a saved
/// recipe or one of the latest recipe ideas. Returns the meal to put on the
/// plan, or null when closed.
Future<MealPlanDraft?> showSlotPicker(
  BuildContext context, {
  required DateTime date,
  required MealSlot slot,
}) {
  return showModalBottomSheet<MealPlanDraft>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (BuildContext _) => _SlotPicker(date: date, slot: slot),
  );
}

class _SlotPicker extends ConsumerStatefulWidget {
  const _SlotPicker({required this.date, required this.slot});

  final DateTime date;
  final MealSlot slot;

  @override
  ConsumerState<_SlotPicker> createState() => _SlotPickerState();
}

class _SlotPickerState extends ConsumerState<_SlotPicker> {
  final TextEditingController _text = TextEditingController();

  static const List<String> _quick = <String>['Outside', 'Order in', 'Skip'];

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _pickText(String value) {
    final String? clean = MealPlanDraft.cleanText(value);
    if (clean == null) {
      return;
    }
    Navigator.of(context).pop(
      MealPlanDraft.text(date: widget.date, slot: widget.slot, text: clean),
    );
  }

  void _pickRecipe(Recipe recipe) {
    Navigator.of(context).pop(
      MealPlanDraft.fromRecipe(
        date: widget.date,
        slot: widget.slot,
        recipe: recipe,
        prep: PrepRules.suggest(recipe, widget.slot),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = context.akText;
    final AkshayaColors colors = context.akColors;
    final List<PantryLine> leftovers = <PantryLine>[
      for (final PantryLine l in ref.watch(pantryLinesProvider))
        if (l.item.isLeftover && l.hasStock) l,
    ];
    final List<SavedRecipe> saved =
        ref.watch(savedRecipesProvider).value ?? const <SavedRecipe>[];
    final List<Recipe> ideas =
        ref.watch(recipeCacheProvider).value?.recipes ?? const <Recipe>[];

    Widget heading(String label) => Padding(
          padding: const EdgeInsets.only(
            top: AppSpacing.lg,
            bottom: AppSpacing.sm,
          ),
          child: Text(label, style: text.titleSmall),
        );

    Widget recipeTile(Recipe r) => ListTile(
          contentPadding: EdgeInsets.zero,
          minVerticalPadding: AppSpacing.sm,
          title: Text(r.title),
          subtitle: Text('${r.timeMinutes} min · serves ${r.servings}'),
          trailing: Icon(Icons.chevron_right_rounded, color: colors.textSecondary),
          onTap: () => _pickRecipe(r),
        );

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.xl,
        ),
        shrinkWrap: true,
        children: <Widget>[
          Text(widget.slot.label, style: text.titleLarge),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _text,
            textInputAction: TextInputAction.done,
            textCapitalization: TextCapitalization.sentences,
            maxLength: MealPlanDraft.maxTitleLength,
            decoration: InputDecoration(
              labelText: 'Type a meal',
              hintText: 'Pesarattu',
              counterText: '',
              suffixIcon: IconButton(
                tooltip: 'Add',
                icon: const Icon(Icons.check_rounded),
                onPressed: () => _pickText(_text.text),
              ),
            ),
            onSubmitted: _pickText,
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            children: <Widget>[
              for (final String q in _quick)
                ActionChip(label: Text(q), onPressed: () => _pickText(q)),
            ],
          ),
          if (leftovers.isNotEmpty) ...<Widget>[
            heading('Leftovers'),
            for (final PantryLine l in leftovers)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l.name),
                subtitle: Text(
                  l.daysLeft == null
                      ? 'In your pantry'
                      : 'Use within ${l.daysLeft} days',
                ),
                trailing:
                    Icon(Icons.chevron_right_rounded, color: colors.textSecondary),
                onTap: () => Navigator.of(context).pop(
                  MealPlanDraft.leftover(
                    date: widget.date,
                    slot: widget.slot,
                    itemId: l.itemId,
                    name: l.name,
                  ),
                ),
              ),
          ],
          if (saved.isNotEmpty) ...<Widget>[
            heading('Saved recipes'),
            for (final SavedRecipe s in saved) recipeTile(s.recipe),
          ],
          if (ideas.isNotEmpty) ...<Widget>[
            heading('Recent ideas'),
            for (final Recipe r in ideas) recipeTile(r),
          ],
          if (saved.isEmpty && ideas.isEmpty && leftovers.isEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Save recipes or get recipe ideas to pick them here.',
              style: text.bodyMedium?.copyWith(color: colors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}
