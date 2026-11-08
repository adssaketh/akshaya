import 'package:akshaya/core/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/feedback.dart';
import '../../shopping/domain/shopping_entities.dart';
import '../../shopping/domain/shopping_repository.dart';
import '../../shopping/presentation/providers.dart';
import '../domain/entities.dart';
import '../domain/item_moves.dart';
import '../domain/pantry_repository.dart';
import '../domain/stock_logic.dart';
import '../domain/storage_location.dart';
import '../domain/unit.dart';
import 'pantry_icons.dart';
import 'providers.dart';

/// Bottom sheet that lists [categories] and returns the one tapped (null when
/// dismissed). The current one is ticked.
Future<Category?> pickCategory(
  BuildContext context, {
  required List<Category> categories,
  required String currentId,
  required String title,
}) {
  return showModalBottomSheet<Category>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext sheetContext) {
      final AkshayaColors colors = sheetContext.akColors;
      final double maxHeight = MediaQuery.sizeOf(sheetContext).height * 0.8;
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppSpacing.sm,
                ),
                child: Text(title, style: sheetContext.akText.titleLarge),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: <Widget>[
                    for (final Category c in categories)
                      ListTile(
                        leading: Icon(
                          categoryIcon(c.iconKey),
                          color: colors.primary,
                        ),
                        title: Text(c.name),
                        selected: c.id == currentId,
                        trailing: c.id == currentId
                            ? Icon(Icons.check_rounded, color: colors.primary)
                            : null,
                        onTap: () => Navigator.of(sheetContext).pop(c),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Bottom sheet that returns the storage place tapped (null when dismissed).
Future<StorageLocation?> _pickLocation(
  BuildContext context, {
  required StorageLocation current,
  required String title,
}) {
  return showModalBottomSheet<StorageLocation>(
    context: context,
    showDragHandle: true,
    builder: (BuildContext sheetContext) {
      final AkshayaColors colors = sheetContext.akColors;
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Text(title, style: sheetContext.akText.titleLarge),
            ),
            for (final StorageLocation place in StorageLocation.values)
              ListTile(
                leading: Icon(locationIcon(place), color: colors.primary),
                title: Text(place.label),
                selected: place == current,
                trailing: place == current
                    ? Icon(Icons.check_rounded, color: colors.primary)
                    : null,
                onTap: () => Navigator.of(sheetContext).pop(place),
              ),
          ],
        ),
      );
    },
  );
}

/// Asks for a category and moves [item] there, with Undo.
Future<void> moveItemToCategory(
  BuildContext context,
  WidgetRef ref,
  Item item,
) async {
  // Everything needed after the sheet closes is read first: the row this was
  // opened from moves to another section as soon as the item is moved.
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  final PantryRepository repo = ref.read(pantryRepositoryProvider);
  final List<Category> categories =
      ref.read(categoriesProvider).value ?? const <Category>[];

  final Category? target = await pickCategory(
    context,
    categories: categories,
    currentId: item.categoryId,
    title: 'Move ${item.name} to',
  );
  if (target == null || target.id == item.categoryId) {
    return;
  }
  try {
    await repo.updateItem(item.inCategory(target.id));
    showUndoSnackBar(
      messenger,
      message: 'Moved ${item.name} to ${target.name}',
      onUndo: () async {
        await repo.updateItem(item);
      },
    );
  } on Object catch (error) {
    showMessage(messenger, failureMessage(error));
  }
}

/// Asks for a storage place and moves the item's usual place and everything
/// in stock there, with Undo.
Future<void> moveStockToPlace(
  BuildContext context,
  WidgetRef ref,
  ItemStock stock,
) async {
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  final PantryRepository repo = ref.read(pantryRepositoryProvider);

  final StorageLocation? target = await _pickLocation(
    context,
    current: stock.primaryLocation,
    title: 'Keep ${stock.item.name} in',
  );
  if (target == null) {
    return;
  }
  final bool itemChanges = stock.item.defaultStorageLocation != target;
  final List<StockBatch> moving = <StockBatch>[
    for (final StockBatch b in stock.inStock)
      if (b.storageLocation != target) b,
  ];
  if (!itemChanges && moving.isEmpty) {
    return;
  }
  try {
    if (itemChanges) {
      await repo.updateItem(stock.item.keptIn(target));
    }
    for (final StockBatch b in moving) {
      await repo.updateBatch(b.storedIn(target));
    }
    showUndoSnackBar(
      messenger,
      message: 'Moved ${stock.item.name} to ${target.label}',
      onUndo: () async {
        if (itemChanges) {
          await repo.updateItem(stock.item);
        }
        for (final StockBatch b in moving) {
          await repo.updateBatch(b);
        }
      },
    );
  } on Object catch (error) {
    showMessage(messenger, failureMessage(error));
  }
}

/// Marks the item as an essential, or takes the mark off.
Future<void> toggleEssential(
  BuildContext context,
  WidgetRef ref,
  Item item,
) async {
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  final PantryRepository repo = ref.read(pantryRepositoryProvider);
  final bool essential = !item.isEssential;
  try {
    await repo.updateItem(item.asEssential(essential: essential));
    showMessage(
      messenger,
      essential
          ? '${item.name} is now an essential: it is suggested for the '
              'shopping list when it runs out.'
          : '${item.name} is no longer an essential.',
    );
  } on Object catch (error) {
    showMessage(messenger, failureMessage(error));
  }
}

/// Adds the item to the shopping list being shown, in the amount bought last
/// time (one of its usual unit when it was never bought).
Future<void> addItemToShoppingList(
  BuildContext context,
  WidgetRef ref,
  ItemStock stock,
) async {
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  final ShoppingRepository repo = ref.read(shoppingRepositoryProvider);
  final String listId = ref.read(selectedListProvider)?.id ?? kDefaultListId;

  StockBatch? latest;
  for (final StockBatch b in stock.batches) {
    if (latest == null || b.purchaseDate.isAfter(latest.purchaseDate)) {
      latest = b;
    }
  }
  final double quantity = latest?.quantityBought ?? 1;
  final Unit unit = latest?.unit ?? stock.item.defaultUnit;
  try {
    await repo.addEntry(
      ShoppingEntryDraft(
        listId: listId,
        itemId: stock.item.id,
        name: stock.item.name,
        quantity: quantity,
        unit: unit,
      ),
    );
    showMessage(messenger, 'Added ${stock.item.name} to your shopping list');
  } on Object catch (error) {
    showMessage(messenger, failureMessage(error));
  }
}
