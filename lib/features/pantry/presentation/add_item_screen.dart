import 'package:akshaya/core/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/clock.dart';
import '../../../core/ui/feedback.dart';
import '../domain/entities.dart';
import '../domain/pantry_query.dart';
import '../domain/pantry_repository.dart';
import '../domain/unit.dart';
import 'providers.dart';
import 'widgets/item_fields.dart';
import 'widgets/stock_fields.dart';

/// Adds stock to the pantry.
///
/// Type a name: matching items (by name or any alias) are suggested. Pick one
/// to add a purchase to it, or carry on to create a new item. Quantity and
/// expiry shortcuts make adding fast.
class AddItemScreen extends ConsumerStatefulWidget {
  const AddItemScreen({super.key, this.initialItem});

  /// Item to add stock to (opened from an item's detail screen).
  final Item? initialItem;

  @override
  ConsumerState<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends ConsumerState<AddItemScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final FocusNode _nameFocus = FocusNode();

  late final ItemFieldsController _itemFields;
  late final StockFieldsController _stock;

  Item? _existing;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final Item? initial = widget.initialItem;
    final DateTime today = ref.read(todayProvider);

    _existing = initial;
    _itemFields = ItemFieldsController(item: initial);
    _stock = StockFieldsController(
      today: today,
      unit: initial?.defaultUnit ?? _itemFields.unit,
      location: initial?.defaultStorageLocation ?? _itemFields.location,
    );
    if (initial != null) {
      _name.text = initial.name;
    }
    _itemFields.addListener(_syncStockWithItemFields);
  }

  /// While creating a new item, the purchase follows the item's unit and
  /// usual location.
  void _syncStockWithItemFields() {
    if (_existing != null) {
      return;
    }
    if (!_stock.unit.isCompatibleWith(_itemFields.unit)) {
      _stock.setUnit(_itemFields.unit);
    }
    if (_stock.location != _itemFields.location) {
      _stock.setLocation(_itemFields.location);
    }
    if (mounted) {
      // The allowed purchase units depend on the item's unit.
      setState(() {});
    }
  }

  @override
  void dispose() {
    _itemFields.removeListener(_syncStockWithItemFields);
    _itemFields.dispose();
    _stock.dispose();
    _name.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  void _selectExisting(Item item) {
    setState(() {
      _existing = item;
      _error = null;
      _stock.setUnit(item.defaultUnit);
      _stock.setLocation(item.defaultStorageLocation);
    });
  }

  void _onNameChanged(String text) {
    final Item? existing = _existing;
    if (existing != null &&
        normalizeForSearch(text) != normalizeForSearch(existing.name)) {
      setState(() => _existing = null);
    }
    if (_error != null) {
      setState(() => _error = null);
    }
  }

  Iterable<Item> _suggestions(String text) {
    final String needle = normalizeForSearch(text);
    if (needle.isEmpty) {
      return const <Item>[];
    }
    final List<ItemWithBatches> all =
        ref.read(itemsStreamProvider).value ?? const <ItemWithBatches>[];
    final List<Item> matches = <Item>[];
    for (final ItemWithBatches record in all) {
      final Item item = record.item;
      final bool hit = normalizeForSearch(item.name).contains(needle) ||
          item.aliases.any(
            (String a) => normalizeForSearch(a).contains(needle),
          );
      if (hit) {
        matches.add(item);
      }
    }
    matches.sort((Item a, Item b) => a.name.compareTo(b.name));
    return matches.take(5);
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }
    final FormState? form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final PantryRepository repo = ref.read(pantryRepositoryProvider);
    final NavigatorState navigator = Navigator.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final String name = _name.text.trim();
    final double? quantity = _stock.quantityValue;

    try {
      Item? item = _existing;
      bool wasExisting = item != null;
      if (item == null) {
        // A typed name that already exists adds stock to that item rather than
        // failing with a duplicate error.
        item = await repo.findItemByName(name);
        wasExisting = item != null;
      }
      if (wasExisting && quantity == null) {
        if (!mounted) {
          return;
        }
        setState(() {
          _saving = false;
          _error = 'That item already exists. Enter a quantity to add stock.';
        });
        return;
      }
      item ??= await repo.addItem(_itemFields.toDraft(name));

      if (quantity != null) {
        await repo.addBatch(_stock.toDraft(item.id));
      }

      if (!mounted) {
        return;
      }
      final String message = quantity == null
          ? 'Added ${item.name}'
          : 'Added ${_stock.unit.format(quantity)} of ${item.name}';
      navigator.pop();
      showMessage(messenger, message);
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
    final Item? existing = _existing;
    final Unit baseUnit = existing?.defaultUnit ?? _itemFields.unit;

    return Scaffold(
      appBar: AppBar(
        title: Text(existing == null ? 'Add item' : 'Add stock'),
      ),
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
            const SizedBox(height: AppSpacing.md),
            if (existing != null)
              _ExistingItemNote(item: existing)
            else ...<Widget>[
              const SectionHeader(title: 'Item details'),
              ItemFields(controller: _itemFields),
            ],
            const SizedBox(height: AppSpacing.lg),
            const SectionHeader(title: 'Stock'),
            StockFields(
              controller: _stock,
              allowedUnits: baseUnit.compatibleUnits,
              quantityRequired: existing != null,
            ),
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
          onSelected: _selectExisting,
          fieldViewBuilder: (
            BuildContext context,
            TextEditingController controller,
            FocusNode focusNode,
            VoidCallback onFieldSubmitted,
          ) {
            return TextFormField(
              controller: controller,
              focusNode: focusNode,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              onChanged: _onNameChanged,
              decoration: const InputDecoration(
                labelText: 'Item name',
                helperText: 'Type to find an item you already have',
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

class _ExistingItemNote extends StatelessWidget {
  const _ExistingItemNote({required this.item});

  final Item item;

  @override
  Widget build(BuildContext context) {
    final AkshayaColors colors = context.akColors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceAlt,
        borderRadius: AppRadius.cardBorder,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: <Widget>[
            Icon(
              Icons.inventory_2_rounded,
              size: AppSizes.iconMd,
              color: colors.primary,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                'You already have this item. This purchase will be added to '
                'it, counted in ${item.defaultUnit.symbol}.',
                style: context.akText.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
