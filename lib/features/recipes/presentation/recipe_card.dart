import 'package:akshaya/core/design/design.dart';
import 'package:flutter/material.dart';

import '../domain/recipe_matcher.dart';
import '../domain/recipe_models.dart';

/// One recipe in a list: title, time and servings, and one chip saying what
/// matters most (uses expiring food, ready to cook, or what is missing).
class RecipeCard extends StatelessWidget {
  const RecipeCard({super.key, required this.ranked, required this.onTap});

  final RankedRecipe ranked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Recipe recipe = ranked.recipe;
    final List<String> parts = <String>[
      '${recipe.timeMinutes} min',
      recipe.servings == 1 ? 'serves 1' : 'serves ${recipe.servings}',
      recipe.diet.label,
      if (ranked.expiringUsed.isNotEmpty)
        'uses ${ranked.expiringUsed.join(', ')}',
    ];
    final StatusKind status;
    final String label;
    if (ranked.expiringUsed.isNotEmpty) {
      status = StatusKind.expiring;
      final int count = ranked.expiringUsed.length;
      label = count == 1 ? 'Uses 1 expiring' : 'Uses $count expiring';
    } else if (ranked.canCookNow) {
      status = StatusKind.fresh;
      label = 'Ready to cook';
    } else {
      status = StatusKind.lowStock;
      label = '${ranked.missingCount} missing';
    }
    return ItemCard(
      name: recipe.title,
      subtitle: parts.join(' · '),
      icon: Icons.soup_kitchen_rounded,
      status: status,
      statusLabel: label,
      onTap: onTap,
    );
  }
}
