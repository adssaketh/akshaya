import 'package:flutter/material.dart';
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
  return showModalBottomSheet<void>(
    context: context,
    builder: (BuildContext sheetContext) {
      void close() => Navigator.of(sheetContext).pop();

      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
                deleteItemWithUndo(context, ref, stock.item);
              },
            ),
          ],
        ),
      );
    },
  );
}
