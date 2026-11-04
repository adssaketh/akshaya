import 'package:akshaya/core/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/feedback.dart';
import '../../../core/util/quantity.dart';
import '../../pantry/domain/entities.dart';
import '../../pantry/domain/pantry_query.dart';
import '../../pantry/domain/unit.dart';
import '../../pantry/presentation/providers.dart';
import '../domain/shopping_entities.dart';
import '../domain/shopping_enums.dart';
import '../domain/shopping_repository.dart';
import 'providers.dart';

/// Adds an entry to a shopping list, or edits one.
///
/// Type a name: pantry items that match (by name or any alias) are suggested.
/// Picking one links the entry to it, so "Done shopping" adds stock to that
/// item. A name that matches nothing is a free-text entry.
class EntryFormScreen extends ConsumerStatefulWidget {
  const EntryFormScreen({super.key, required this.listId, this.entry});

  final String listId;

  /// The entry to edit; null adds a new one.
  final ShoppingEntry? entry;

  @override
  ConsumerState<EntryFormScreen> createState() => _EntryFormScreenState();
}

class _EntryFormScreenState extends ConsumerState<EntryFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final FocusNode _nameFocus = FocusNode();
  final TextEditingController _quantity = TextEditingController(text: '1');
  final TextEditingController _notes = TextEditingController();

  Item? _item;
  Unit _unit = Unit.pcs;
  bool _urgent = false;
  Recurrence _recurrence = Recurrence.none;
  late String _listId = widget.listId;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final ShoppingEntry? entry = widget.entry;
    if (entry != null) {
      _name.text = entry.name;
      _quantity.text = formatNumber(entry.quantity);
      _notes.text = entry.notes ?? '';
      _unit = entry.unit;
      _urgent = entry.priority == ShoppingPriority.high;
      _recurrence = entry.recurrence;
      _listId = entry.listId;
      _item = _itemById(entry.itemId);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _nameFocus.dispose();
    _quantity.dispose();
    _notes.dispose();
    super.dispose();
  }

  List<ItemWithBatches> get _allItems {
    return ref.read(itemsStreamProvider).value ?? const <ItemWithBatches>[];
  }

  Item? _itemById(String? id) {
    if (id == null) {
      return null;
    }
    for (final ItemWithBatches r in _allItems) {
      if (r.item.id == id) {
        return r.item;
      }
    }
    return null;
  }

  /// The picked item, or the pantry item whose name or alias is exactly what
  /// was typed.
  Item? _resolveItem(String typed) {
    final Item? picked = _item;
    if (picked != null) {
      return picked;
    }
    final String needle = normalizeForSearch(typed);
    for (final ItemWithBatches r in _allItems) {
      if (normalizeForSearch(r.item.name) == needle ||
          r.item.aliases.any((String a) => normalizeForSearch(a) == needle)) {
        return r.item;
      }
    }
    return null;
  }

  Iterable<Item> _suggestions(String text) {
    final String needle = normalizeForSearch(text);
    if (needle.isEmpty) {
      return const <Item>[];
    }
    final List<Item> matches = <Item>[
      for (final ItemWithBatches r in _allItems)
        if (normalizeForSearch(r.item.name).contains(needle) ||
            r.item.aliases.any(
              (String a) => normalizeForSearch(a).contains(needle),
            ))
          r.item,
    ]..sort((Item a, Item b) => a.name.compareTo(b.name));
    return matches.take(5);
  }

  void _selectItem(Item item) {
    setState(() {
      _item = item;
      _unit = item.defaultUnit;
      _error = null;
    });
  }

  void _onNameChanged(String text) {
    final Item? picked = _item;
    if (picked != null &&
        normalizeForSearch(text) != normalizeForSearch(picked.name)) {
      setState(() => _item = null);
    }
    if (_error != null) {
      setState(() => _error = null);
    }
  }

  List<Unit> get _allowedUnits => _item?.defaultUnit.compatibleUnits ?? Unit.values;

  Future<void> _save() async {
    if (_saving) {
      return;
    }
    final FormState? form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    final String typed = _name.text.trim();
    final Item? item = _resolveItem(typed);
    final List<Unit> allowed = item?.defaultUnit.compatibleUnits ?? Unit.values;
    final Unit unit = allowed.contains(_unit) ? _unit : allowed.first;
    if (item != null && !unit.isCompatibleWith(item.defaultUnit)) {
      setState(() {
        _error = '${item.name} is counted in ${item.defaultUnit.symbol}. '
            'Pick a unit that converts to it.';
      });
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final ShoppingRepository repo = ref.read(shoppingRepositoryProvider);
    final NavigatorState navigator = Navigator.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final double quantity = parseQuantity(_quantity.text) ?? 0;
    final String name = item?.name ?? typed;
    final String notes = _notes.text.trim();
    final ShoppingPriority priority =
        _urgent ? ShoppingPriority.high : ShoppingPriority.normal;
    final ShoppingEntry? editing = widget.entry;

    try {
      if (editing == null) {
        await repo.addEntry(
          ShoppingEntryDraft(
            listId: _listId,
            itemId: item?.id,
            name: name,
            quantity: quantity,
            unit: unit,
            priority: priority,
            notes: notes.isEmpty ? null : notes,
            recurrence: _recurrence,
          ),
        );
      } else {
        await repo.updateEntry(
          editing.copyWith(
            listId: _listId,
            itemId: item?.id,
            clearItemId: item == null,
            name: name,
            quantity: quantity,
            unit: unit,
            priority: priority,
            notes: notes,
            clearNotes: notes.isEmpty,
            recurrence: _recurrence,
            clearDueOn: !_recurrence.repeats,
          ),
        );
      }
      if (!mounted) {
        return;
      }
      navigator.pop();
      showMessage(
        messenger,
        editing == null ? 'Added $name' : 'Saved changes to $name',
      );
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _error = failureMessage(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final AkshayaColors colors = context.akColors;
    final bool editing = widget.entry != null;
    // Keeps the pantry items loaded for the name suggestions and linking.
    ref.watch(itemsStreamProvider);
    final List<ShoppingList> lists =
        ref.watch(shoppingListsProvider).value ?? const <ShoppingList>[];
    final List<Unit> allowed = _allowedUnits;
    final Unit selectedUnit = allowed.contains(_unit) ? _unit : allowed.first;

    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'Edit entry' : 'Add to list')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving...' : 'Save'),
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          children: <Widget>[
            _buildNameField(context),
            if (_item != null) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Linked to your pantry item. Buying it adds stock there.',
                style: context.akText.bodySmall!.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _quantity,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Quantity'),
                    validator: (String? text) {
                      final double? value = parseQuantity(text ?? '');
                      if (value == null || value <= 0) {
                        return 'Enter a quantity greater than zero';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<Unit>(
                    key: ValueKey<String>(
                      'unit-${selectedUnit.name}-${allowed.length}',
                    ),
                    initialValue: selectedUnit,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Unit'),
                    items: <DropdownMenuItem<Unit>>[
                      for (final Unit u in allowed)
                        DropdownMenuItem<Unit>(value: u, child: Text(u.symbol)),
                    ],
                    onChanged: (Unit? value) {
                      if (value != null) {
                        setState(() => _unit = value);
                      }
                    },
                  ),
                ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Urgent'),
              subtitle: const Text('Shown first in its category'),
              value: _urgent,
              onChanged: (bool value) => setState(() => _urgent = value),
            ),
            DropdownButtonFormField<Recurrence>(
              key: ValueKey<String>('repeat-${_recurrence.name}'),
              initialValue: _recurrence,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Repeat',
                helperText: 'Comes back on the list after you buy it',
              ),
              items: <DropdownMenuItem<Recurrence>>[
                for (final Recurrence r in Recurrence.values)
                  DropdownMenuItem<Recurrence>(value: r, child: Text(r.label)),
              ],
              onChanged: (Recurrence? value) {
                if (value != null) {
                  setState(() => _recurrence = value);
                }
              },
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _notes,
              textCapitalization: TextCapitalization.sentences,
              maxLength: 200,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                hintText: 'Brand, size, shop...',
              ),
            ),
            if (lists.length > 1) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              DropdownButtonFormField<String>(
                key: ValueKey<String>('list-$_listId'),
                initialValue: lists.any((ShoppingList l) => l.id == _listId)
                    ? _listId
                    : lists.first.id,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'List'),
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
            if (_error != null) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              Text(
                _error!,
                style: context.akText.bodyMedium!.copyWith(
                  color: colors.expired.foreground,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNameField(BuildContext context) {
    final AkshayaColors colors = context.akColors;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;

        return RawAutocomplete<Item>(
          textEditingController: _name,
          focusNode: _nameFocus,
          displayStringForOption: (Item item) => item.name,
          optionsBuilder: (TextEditingValue value) => _suggestions(value.text),
          onSelected: _selectItem,
          fieldViewBuilder: (
            BuildContext context,
            TextEditingController controller,
            FocusNode focusNode,
            VoidCallback onFieldSubmitted,
          ) {
            return TextFormField(
              controller: controller,
              focusNode: focusNode,
              autofocus: widget.entry == null,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              onChanged: _onNameChanged,
              decoration: const InputDecoration(
                labelText: 'What do you need?',
                helperText: 'Type to find an item from your pantry',
              ),
              validator: (String? text) {
                final String value = (text ?? '').trim();
                if (value.isEmpty) {
                  return 'Enter a name';
                }
                if (value.length > 120) {
                  return 'That name is too long';
                }
                return null;
              },
            );
          },
          optionsViewBuilder: (
            BuildContext context,
            AutocompleteOnSelected<Item> onSelected,
            Iterable<Item> options,
          ) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                color: colors.surface,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.cardBorder,
                  side: BorderSide(color: colors.outline),
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: width),
                  child: ListView(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    children: <Widget>[
                      for (final Item option in options)
                        ListTile(
                          title: Text(option.name),
                          subtitle: option.aliases.isEmpty
                              ? null
                              : Text(
                                  option.aliases.join(', '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                          onTap: () => onSelected(option),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
