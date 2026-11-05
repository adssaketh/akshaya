import 'package:akshaya/core/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../pantry/domain/entities.dart';
import '../../pantry/presentation/pantry_icons.dart';
import '../../pantry/presentation/providers.dart';
import '../../shopping/domain/shopping_entities.dart';
import '../../shopping/presentation/providers.dart';
import '../domain/what_to_buy.dart';
import 'forecast_actions.dart';
import 'providers.dart';

/// Opens the "What should I buy?" screen.
void openWhatToBuy(BuildContext context) {
  Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (BuildContext _) => const WhatToBuyScreen(),
    ),
  );
}

/// Items predicted to run out soon, each with a suggested amount. Tick what to
/// buy, adjust the amounts, and add them to a shopping list in one go.
class WhatToBuyScreen extends ConsumerStatefulWidget {
  const WhatToBuyScreen({super.key});

  @override
  ConsumerState<WhatToBuyScreen> createState() => _WhatToBuyScreenState();
}

class _WhatToBuyScreenState extends ConsumerState<WhatToBuyScreen> {
  /// Items the person un-ticked (everything is ticked to start with).
  final Set<String> _unticked = <String>{};

  /// Amounts the person changed, by item id.
  final Map<String, double> _quantities = <String, double>{};

  String? _listId;
  bool _adding = false;

  BuyRecommendation _edited(BuyRecommendation r) {
    final double? quantity = _quantities[r.item.id];
    return quantity == null ? r : r.withQuantity(quantity);
  }

  /// The list the items go to: the one picked here, else the one the Shopping
  /// tab is showing.
  String? _targetListId(List<ShoppingList> lists) {
    if (lists.isEmpty) {
      return null;
    }
    for (final ShoppingList l in lists) {
      if (l.id == _listId) {
        return l.id;
      }
    }
    return ref.watch(selectedListProvider)?.id ?? lists.first.id;
  }

  void _step(BuyRecommendation r, {required bool up}) {
    final double next = up ? r.quantity + r.packSize : r.quantity - r.packSize;
    if (next < r.packSize - 0.0005) {
      return;
    }
    setState(() => _quantities[r.item.id] = next);
  }

  Future<void> _add(List<BuyRecommendation> chosen, String listId) async {
    setState(() => _adding = true);
    final bool added = await addRecommendations(
      context,
      ref,
      listId: listId,
      recommendations: chosen,
    );
    if (!mounted) {
      return;
    }
    setState(() => _adding = false);
    if (added) {
      // The added items are on a list now, so they drop out of this screen.
      setState(() {
        for (final BuyRecommendation r in chosen) {
          _quantities.remove(r.item.id);
          _unticked.remove(r.item.id);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final AkshayaColors colors = context.akColors;
    final int horizon = ref.watch(buyHorizonProvider);
    final List<BuyRecommendation> all =
        ref.watch(buyRecommendationsProvider(horizon));
    final List<ShoppingList> lists =
        ref.watch(shoppingListsProvider).value ?? const <ShoppingList>[];
    final Map<String, Category> categories = ref.watch(categoriesByIdProvider);
    final String? listId = _targetListId(lists);

    final List<BuyRecommendation> chosen = <BuyRecommendation>[
      for (final BuyRecommendation r in all)
        if (!_unticked.contains(r.item.id)) _edited(r),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('What should I buy?')),
      bottomNavigationBar: chosen.isEmpty || listId == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: FilledButton.icon(
                  onPressed: _adding ? null : () => _add(chosen, listId),
                  icon: const Icon(Icons.add_shopping_cart_rounded),
                  label: Text(
                    _adding
                        ? 'Adding...'
                        : 'Add ${chosen.length} to the list',
                  ),
                ),
              ),
            ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.xl,
        ),
        children: <Widget>[
          Text(
            'Worked out on your phone from how fast you use things.',
            style: context.akText.bodyMedium!.copyWith(
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Running out within', style: context.akText.labelLarge),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.sm,
            children: <Widget>[
              for (final int days in WhatToBuy.horizonChoices)
                ChoiceChip(
                  label: Text('$days days'),
                  selected: horizon == days,
                  onSelected: (bool _) =>
                      ref.read(buyHorizonProvider.notifier).choose(days),
                ),
            ],
          ),
          if (lists.length > 1 && listId != null) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String>(
              key: ValueKey<String>('buy-list-$listId'),
              initialValue: listId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Add to list'),
              items: <DropdownMenuItem<String>>[
                for (final ShoppingList l in lists)
                  DropdownMenuItem<String>(value: l.id, child: Text(l.name)),
              ],
              onChanged: (String? value) {
                if (value != null) {
                  setState(() => _listId = value);
                }
              },
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          if (all.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Text(
                'Nothing is predicted to run out within $horizon days. Items '
                'already on a shopping list are not repeated here, and an '
                'item needs a few days of logged use before it can be '
                'predicted.',
                style: context.akText.bodyMedium!.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            )
          else ...<Widget>[
            SectionHeader(
              title: '${all.length} to buy',
              actionLabel: _unticked.isEmpty ? 'Untick all' : 'Tick all',
              onAction: () => setState(() {
                if (_unticked.isEmpty) {
                  _unticked.addAll(
                    all.map((BuyRecommendation r) => r.item.id),
                  );
                } else {
                  _unticked.clear();
                }
              }),
            ),
            for (final BuyRecommendation r in all)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _RecommendationCard(
                  recommendation: _edited(r),
                  icon: categoryIcon(categories[r.item.categoryId]?.iconKey),
                  selected: !_unticked.contains(r.item.id),
                  onSelected: (bool value) => setState(() {
                    if (value) {
                      _unticked.remove(r.item.id);
                    } else {
                      _unticked.add(r.item.id);
                    }
                  }),
                  onLess: () => _step(_edited(r), up: false),
                  onMore: () => _step(_edited(r), up: true),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({
    required this.recommendation,
    required this.icon,
    required this.selected,
    required this.onSelected,
    required this.onLess,
    required this.onMore,
  });

  final BuyRecommendation recommendation;
  final IconData icon;
  final bool selected;
  final ValueChanged<bool> onSelected;
  final VoidCallback onLess;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final AkshayaColors colors = context.akColors;
    final BuyRecommendation r = recommendation;
    final String? usage = r.forecast.usageLabel;

    return Material(
      color: colors.surface,
      borderRadius: AppRadius.cardBorder,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Checkbox(
              value: selected,
              onChanged: (bool? value) => onSelected(value ?? false),
            ),
            Container(
              width: AppSizes.avatar,
              height: AppSizes.avatar,
              margin: const EdgeInsets.only(top: AppSpacing.sm),
              decoration: BoxDecoration(
                color: colors.surfaceAlt,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: AppSizes.iconMd, color: colors.primary),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      r.item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.akText.titleSmall,
                    ),
                    Text(
                      r.reason,
                      style: context.akText.bodySmall!.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                    if (usage != null)
                      Text(
                        usage,
                        style: context.akText.bodySmall!.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    Row(
                      children: <Widget>[
                        IconButton(
                          tooltip: 'Buy less of ${r.item.name}',
                          icon: const Icon(Icons.remove_circle_outline_rounded),
                          onPressed: onLess,
                        ),
                        Flexible(
                          child: Text(
                            r.quantityLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.akText.titleSmall,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Buy more of ${r.item.name}',
                          icon: const Icon(Icons.add_circle_outline_rounded),
                          onPressed: onMore,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
