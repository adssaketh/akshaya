import 'package:akshaya/core/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../pantry/domain/entities.dart';
import '../../pantry/domain/stock_logic.dart';
import '../../pantry/presentation/pantry_actions.dart';
import '../../pantry/presentation/pantry_icons.dart';
import '../../pantry/presentation/pantry_screen.dart';
import '../../pantry/presentation/providers.dart';
import '../domain/produce.dart';

/// Opens the Vegetables & fruits quick-access screen.
void openProduce(BuildContext context) {
  Navigator.of(context).push<void>(
    MaterialPageRoute<void>(builder: (BuildContext _) => const ProduceScreen()),
  );
}

/// Every vegetable and fruit in one place, what spoils first on top. Rows work
/// like the Pantry: tap for details, swipe to use, long-press for all actions
/// (including Move).
class ProduceScreen extends ConsumerStatefulWidget {
  const ProduceScreen({super.key});

  @override
  ConsumerState<ProduceScreen> createState() => _ProduceScreenState();
}

class _ProduceScreenState extends ConsumerState<ProduceScreen> {
  ProduceKind? _only;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<ItemStock>> stocks = ref.watch(pantryStocksProvider);
    final Map<String, Category> categories = ref.watch(categoriesByIdProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Vegetables & fruits')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'produce-add-fab',
        onPressed: () => openAddItem(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add item'),
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            ToolbarRow(
              child: AkshayaSegmented<ProduceKind?>(
                selected: _only,
                onChanged: (ProduceKind? value) => setState(() => _only = value),
                segments: const <AkshayaSegment<ProduceKind?>>[
                  AkshayaSegment<ProduceKind?>(value: null, label: 'All'),
                  AkshayaSegment<ProduceKind?>(
                    value: ProduceKind.vegetable,
                    label: 'Vegetables',
                  ),
                  AkshayaSegment<ProduceKind?>(
                    value: ProduceKind.fruit,
                    label: 'Fruits',
                  ),
                ],
              ),
            ),
            Expanded(
              child: stocks.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (Object error, StackTrace stackTrace) =>
                    const EmptyState(
                  icon: Icons.error_outline_rounded,
                  title: 'Could not load your pantry',
                  body: 'Please try again in a moment.',
                ),
                data: (List<ItemStock> list) {
                  final List<ItemStock> shown =
                      produceStocks(list, categories, only: _only);
                  if (shown.isEmpty) {
                    return EmptyState(
                      icon: Icons.eco_rounded,
                      title: 'No vegetables or fruits yet',
                      body: 'Add them and they will show up here, with what '
                          'spoils first on top.',
                      actionLabel: 'Add item',
                      onAction: () => openAddItem(context),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.sm,
                      AppSpacing.lg,
                      AppSizes.fab + AppSpacing.xxl,
                    ),
                    itemCount: shown.length,
                    itemBuilder: (BuildContext context, int index) {
                      final ItemStock stock = shown[index];
                      return Padding(
                        key: ValueKey<String>('produce-${stock.item.id}'),
                        padding:
                            const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: PantryRow(
                          stock: stock,
                          icon: categoryIcon(
                            categories[stock.item.categoryId]?.iconKey,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
