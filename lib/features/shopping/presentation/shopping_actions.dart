import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/share/share_service.dart';
import '../../../core/ui/feedback.dart';
import '../domain/shopping_entities.dart';
import '../domain/shopping_repository.dart';
import '../domain/shopping_share.dart';
import '../domain/shopping_suggestions.dart';
import '../domain/shopping_view.dart';
import 'checkout_screen.dart';
import 'entry_form_screen.dart';
import 'providers.dart';

/// Opens the add/edit entry screen. Pass [entry] to edit it.
void openEntryForm(
  BuildContext context, {
  required String listId,
  ShoppingEntry? entry,
}) {
  Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (BuildContext _) => EntryFormScreen(listId: listId, entry: entry),
    ),
  );
}

/// Opens "Done shopping" for the checked [entries] of [list].
void openCheckout(
  BuildContext context, {
  required ShoppingList list,
  required List<ShoppingEntry> entries,
}) {
  Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (BuildContext _) => CheckoutScreen(list: list, entries: entries),
    ),
  );
}

/// Removes [entry] from its list and offers Undo.
Future<void> deleteEntryWithUndo(
  BuildContext context,
  WidgetRef ref,
  ShoppingEntry entry,
) async {
  final ShoppingRepository repo = ref.read(shoppingRepositoryProvider);
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  try {
    await repo.deleteEntry(entry.id);
    showUndoSnackBar(
      messenger,
      message: 'Removed ${entry.name}',
      onUndo: () => repo.undoDeleteEntry(entry.id),
    );
  } on Object catch (error) {
    showMessage(messenger, failureMessage(error));
  }
}

/// Adds the accepted [suggestions] to the list.
Future<void> addSuggestions(
  BuildContext context,
  WidgetRef ref, {
  required String listId,
  required List<ShoppingSuggestion> suggestions,
}) async {
  if (suggestions.isEmpty) {
    return;
  }
  final ShoppingRepository repo = ref.read(shoppingRepositoryProvider);
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  try {
    await repo.addEntries(<ShoppingEntryDraft>[
      for (final ShoppingSuggestion s in suggestions) s.toDraft(listId),
    ]);
    showMessage(
      messenger,
      suggestions.length == 1
          ? 'Added ${suggestions.first.item.name}'
          : 'Added ${suggestions.length} items',
    );
  } on Object catch (error) {
    showMessage(messenger, failureMessage(error));
  }
}

/// Asks for a list name, then creates the list and switches to it.
Future<void> createListFlow(BuildContext context, WidgetRef ref) async {
  final ShoppingRepository repo = ref.read(shoppingRepositoryProvider);
  final SelectedListNotifier selected =
      ref.read(selectedListIdProvider.notifier);
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

  final String? name = await showDialog<String>(
    context: context,
    builder: (BuildContext _) => const ListNameDialog(
      title: 'New list',
      confirmLabel: 'Create',
    ),
  );
  if (name == null) {
    return;
  }
  try {
    final ShoppingList list = await repo.addList(name);
    selected.select(list.id);
  } on Object catch (error) {
    showMessage(messenger, failureMessage(error));
  }
}

/// Asks for a new name for [list] and renames it.
Future<void> renameListFlow(
  BuildContext context,
  WidgetRef ref,
  ShoppingList list,
) async {
  final ShoppingRepository repo = ref.read(shoppingRepositoryProvider);
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

  final String? name = await showDialog<String>(
    context: context,
    builder: (BuildContext _) => ListNameDialog(
      title: 'Rename list',
      confirmLabel: 'Save',
      initialName: list.name,
    ),
  );
  if (name == null || name == list.name) {
    return;
  }
  try {
    await repo.renameList(list.id, name);
  } on Object catch (error) {
    showMessage(messenger, failureMessage(error));
  }
}

/// Deletes [list] with its entries and offers Undo. The last list cannot be
/// deleted.
Future<void> deleteListFlow(
  BuildContext context,
  WidgetRef ref,
  ShoppingList list,
) async {
  final ShoppingRepository repo = ref.read(shoppingRepositoryProvider);
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  try {
    final ListDeleteToken token = await repo.deleteList(list.id);
    showUndoSnackBar(
      messenger,
      message: 'Deleted ${list.name}',
      onUndo: () => repo.undoDeleteList(token),
    );
  } on Object catch (error) {
    showMessage(messenger, failureMessage(error));
  }
}

/// Shares what is still to buy on [list] as plain text. If the share sheet
/// cannot open, the text is copied to the clipboard instead.
Future<void> shareList(
  BuildContext context,
  WidgetRef ref, {
  required ShoppingList list,
  required ShoppingListView view,
}) async {
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  final ShareService share = ref.read(shareServiceProvider);

  final String text = ShoppingShare.build(listName: list.name, view: view);
  if (text.isEmpty) {
    showMessage(messenger, 'Nothing to share: this list has nothing to buy.');
    return;
  }
  try {
    await share.shareText(text, subject: list.name);
  } on Object {
    await Clipboard.setData(ClipboardData(text: text));
    showMessage(
      messenger,
      'Sharing is not available here. The list was copied instead.',
    );
  }
}

/// Dialog with one text field for a list name. Pops the trimmed name.
class ListNameDialog extends StatefulWidget {
  const ListNameDialog({
    super.key,
    required this.title,
    required this.confirmLabel,
    this.initialName = '',
  });

  final String title;
  final String confirmLabel;
  final String initialName;

  @override
  State<ListNameDialog> createState() => _ListNameDialogState();
}

class _ListNameDialogState extends State<ListNameDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialName);
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final String name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Enter a name');
      return;
    }
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.done,
        maxLength: 60,
        onSubmitted: (String _) => _submit(),
        decoration: InputDecoration(
          labelText: 'List name',
          hintText: 'Weekly, Monthly, DMart',
          errorText: _error,
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.confirmLabel)),
      ],
    );
  }
}
