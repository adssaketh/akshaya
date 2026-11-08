import 'dart:async';

import 'package:akshaya/core/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/feedback.dart';
import '../../scanning/domain/scan_service.dart';
import '../../scanning/presentation/barcode_scan_screen.dart';
import '../../scanning/presentation/scan_flow.dart';
import '../domain/entities.dart';
import '../domain/item_kind.dart';
import '../domain/pantry_repository.dart';
import '../domain/stock_logic.dart';
import 'add_item_screen.dart';
import 'batch_form_screen.dart';
import 'item_detail_screen.dart';
import 'item_form_screen.dart';
import 'move_actions.dart';
import 'providers.dart';
import 'use_stock_sheet.dart';

/// Opens the add-item screen. Pass [existing] to add stock to that item.
void openAddItem(
  BuildContext context, {
  Item? existing,
  ItemKind kind = ItemKind.stocked,
}) {
  Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (BuildContext _) =>
          AddItemScreen(initialItem: existing, initialKind: kind),
    ),
  );
}

/// Asks whether to add cooked food or a homemade item, then opens the add
/// screen for that kind.
Future<void> showQuickAddMadeAtHome(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (BuildContext sheetContext) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.soup_kitchen_rounded),
              title: const Text('Cooked food'),
              subtitle: const Text('Leftovers: curry, rice, batter, chutney'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                openAddItem(context, kind: ItemKind.cooked);
              },
            ),
            ListTile(
              leading: const Icon(Icons.rice_bowl_rounded),
              title: const Text('Homemade item'),
              subtitle: const Text('Pickle, ghee, podi, masala, papad'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                openAddItem(context, kind: ItemKind.homemade);
              },
            ),
          ],
        ),
      );
    },
  );
}

/// Scans a barcode, looks it up, then opens the add-item screen ready to
/// fill in (or to add stock to the item the barcode already belongs to).
Future<void> openScanToAdd(BuildContext context, WidgetRef ref) async {
  final String? code = await scanBarcode(context);
  if (code == null || !context.mounted) {
    return;
  }
  final ScanOutcome outcome = await resolveScan(context, ref, code);
  if (!context.mounted) {
    return;
  }
  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (BuildContext _) => AddItemScreen(initialScan: outcome),
    ),
  );
}

void openItemDetail(BuildContext context, String itemId) {
  Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (BuildContext _) => ItemDetailScreen(itemId: itemId),
    ),
  );
}

void openEditItem(BuildContext context, Item item) {
  Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (BuildContext _) => ItemFormScreen(item: item),
    ),
  );
}

void openEditBatch(BuildContext context, Item item, StockBatch batch) {
  Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (BuildContext _) => BatchFormScreen(item: item, batch: batch),
    ),
  );
}

/// Deletes [item] and offers Undo. Returns true when the item was deleted.
Future<bool> deleteItemWithUndo(
  BuildContext context,
  WidgetRef ref,
  Item item,
) async {
  final PantryRepository repo = ref.read(pantryRepositoryProvider);
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  try {
    final DeleteToken token = await repo.deleteItem(item.id);
    showUndoSnackBar(
      messenger,
      message: 'Deleted ${item.name}',
      onUndo: () => repo.undoDeleteItem(token),
    );
    return true;
  } on Object catch (error) {
    showMessage(messenger, failureMessage(error));
    return false;
  }
}

/// Bottom sheet with every action for one pantry item (long-press menu).
Future<void> showItemActionsSheet(
  BuildContext context,
  WidgetRef ref,
  ItemStock stock,
) {
  HapticFeedback.selectionClick();
  final List<Category> categories =
      ref.read(categoriesProvider).value ?? const <Category>[];
  String categoryName = 'Other';
  for (final Category c in categories) {
    if (c.id == stock.item.categoryId) {
      categoryName = c.name;
    }
  }

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext sheetContext) {
      void close() => Navigator.of(sheetContext).pop();
      final double maxHeight = MediaQuery.sizeOf(sheetContext).height * 0.85;

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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      stock.item.name,
                      style: sheetContext.akText.titleLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      stock.summaryLine,
                      style: sheetContext.akText.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: <Widget>[
                    ListTile(
                      leading: const Icon(Icons.remove_circle_outline_rounded),
                      title: const Text('Use'),
                      enabled: stock.inStock.isNotEmpty,
                      onTap: () {
                        close();
                        showUseStockSheet(context, stock);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.add_rounded),
                      title: const Text('Add stock'),
                      onTap: () {
                        close();
                        openAddItem(context, existing: stock.item);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.add_shopping_cart_rounded),
                      title: const Text('Add to shopping list'),
                      onTap: () {
                        close();
                        unawaited(addItemToShoppingList(context, ref, stock));
                      },
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.drive_file_move_rounded),
                      title: const Text('Move to category'),
                      subtitle: Text('Now in $categoryName'),
                      onTap: () {
                        close();
                        unawaited(moveItemToCategory(context, ref, stock.item));
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.place_outlined),
                      title: const Text('Move to place'),
                      subtitle: Text('Now in ${stock.primaryLocation.label}'),
                      onTap: () {
                        close();
                        unawaited(moveStockToPlace(context, ref, stock));
                      },
                    ),
                    ListTile(
                      leading: Icon(
                        stock.item.isEssential
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                      ),
                      title: Text(
                        stock.item.isEssential
                            ? 'Remove from essentials'
                            : 'Mark as essential',
                      ),
                      onTap: () {
                        close();
                        unawaited(toggleEssential(context, ref, stock.item));
                      },
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.info_outline_rounded),
                      title: const Text('View details'),
                      onTap: () {
                        close();
                        openItemDetail(context, stock.item.id);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.edit_rounded),
                      title: const Text('Edit item'),
                      onTap: () {
                        close();
                        openEditItem(context, stock.item);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.delete_outline_rounded),
                      title: const Text('Delete'),
                      onTap: () {
                        close();
                        unawaited(deleteItemWithUndo(context, ref, stock.item));
                      },
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
