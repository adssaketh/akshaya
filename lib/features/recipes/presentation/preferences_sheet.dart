import 'package:akshaya/core/design/design.dart';
import 'package:flutter/material.dart';

import '../domain/recipe_models.dart';

/// Lets the person change what they want to cook. Returns the new
/// preferences, or null when closed without saving.
Future<RecipePreferences?> showRecipePreferencesSheet(
  BuildContext context,
  RecipePreferences current,
) {
  return showModalBottomSheet<RecipePreferences>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (BuildContext sheetContext) =>
        _PreferencesSheet(initial: current),
  );
}

class _PreferencesSheet extends StatefulWidget {
  const _PreferencesSheet({required this.initial});

  final RecipePreferences initial;

  @override
  State<_PreferencesSheet> createState() => _PreferencesSheetState();
}

class _PreferencesSheetState extends State<_PreferencesSheet> {
  late RecipeDiet _diet = widget.initial.diet;
  late RecipeCuisine _cuisine = widget.initial.cuisine;
  late int _minutes = widget.initial.maxMinutes;
  late int _people = widget.initial.people;
  late final TextEditingController _avoid =
      TextEditingController(text: widget.initial.avoid.join(', '));

  @override
  void dispose() {
    _avoid.dispose();
    super.dispose();
  }

  void _save() {
    Navigator.of(context).pop(
      RecipePreferences(
        diet: _diet,
        cuisine: _cuisine,
        maxMinutes: _minutes,
        people: _people,
        avoid: RecipePreferences.parseAvoid(_avoid.text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = context.akText;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Recipe preferences', style: text.titleLarge),
            const SizedBox(height: AppSpacing.lg),
            Text('Diet', style: text.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                // Non-veg is only offered to someone who already chose it.
                for (final RecipeDiet diet in RecipeDiet.values)
                  if (diet != RecipeDiet.nonVeg || _diet == RecipeDiet.nonVeg)
                    ChoiceChip(
                      label: Text(diet.label),
                      selected: _diet == diet,
                      onSelected: (_) => setState(() => _diet = diet),
                    ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Cuisine', style: text.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                for (final RecipeCuisine cuisine in RecipeCuisine.values)
                  ChoiceChip(
                    label: Text(cuisine.label),
                    selected: _cuisine == cuisine,
                    onSelected: (_) => setState(() => _cuisine = cuisine),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Longest cooking time', style: text.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                for (final int m in kRecipeTimeChoices)
                  ChoiceChip(
                    label: Text('$m min'),
                    selected: _minutes == m,
                    onSelected: (_) => setState(() => _minutes = m),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: <Widget>[
                Expanded(child: Text('People eating', style: text.titleSmall)),
                IconButton(
                  tooltip: 'Fewer people',
                  onPressed:
                      _people > 1 ? () => setState(() => _people--) : null,
                  icon: const Icon(Icons.remove_circle_outline_rounded),
                ),
                Text('$_people', style: text.titleMedium),
                IconButton(
                  tooltip: 'More people',
                  onPressed: _people < kMaxRecipePeople
                      ? () => setState(() => _people++)
                      : null,
                  icon: const Icon(Icons.add_circle_outline_rounded),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _avoid,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Allergies or foods to avoid',
                helperText: 'Separate with commas, e.g. peanuts, mushroom',
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _save,
                child: const Text('Save preferences'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
