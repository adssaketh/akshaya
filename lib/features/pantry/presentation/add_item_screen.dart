import 'package:akshaya/core/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/clock.dart';
import '../../../core/ui/feedback.dart';
import '../../../core/util/quantity.dart';
import '../../scanning/domain/product_info.dart';
import '../../scanning/domain/scan_service.dart';
import '../../scanning/presentation/barcode_scan_screen.dart';
import '../../scanning/presentation/scan_flow.dart';
import '../../settings/presentation/providers.dart';
import '../domain/entities.dart';
import '../domain/item_kind.dart';
import '../domain/pantry_query.dart';
import '../domain/pantry_repository.dart';
import '../domain/shelf_life.dart';
import '../domain/storage_location.dart';
import '../domain/unit.dart';
import 'providers.dart';
import 'widgets/item_fields.dart';
import 'widgets/stock_fields.dart';

/// Adds stock to the pantry.
///
/// Type a name: matching items (by name or any alias) are suggested. Pick one
/// to add a purchase to it, or carry on to create a new item. Quantity and
/// expiry shortcuts make adding fast. The scan button reads a barcode and
/// fills the form from the pantry or from Open Food Facts.
class AddItemScreen extends ConsumerStatefulWidget {
  const AddItemScreen({
    super.key,
    this.initialItem,
    this.initialScan,
    this.initialKind = ItemKind.stocked,
  });

  /// Kind of a new item (quick-add of cooked or homemade food).
  final ItemKind initialKind;

  /// Item to add stock to (opened from an item's detail screen).
  final Item? initialItem;

  /// A barcode that was just scanned, to prefill the form from.
  final ScanOutcome? initialScan;

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

  /// Barcode from the last scan that is not yet saved anywhere. Saved with
  /// the item when the form is saved.
  String? _scannedBarcode;
  ScanNotice? _scanNotice;

  late ItemKind _lastKind;

  /// Cooked food is counted in portions and kept in the fridge; homemade food
  /// keeps in the pantry. The user can change both afterwards.
  void _applyKindDefaults(ItemKind kind) {
    switch (kind) {
      case ItemKind.stocked:
        return;
      case ItemKind.cooked:
        _itemFields.unit = Unit.portion;
        _itemFields.location = StorageLocation.fridge;
      case ItemKind.homemade:
        if (_itemFields.unit == Unit.portion) {
          _itemFields.unit = Unit.pcs;
        }
        _itemFields.location = StorageLocation.pantry;
    }
  }

  ItemKind get _kind => _existing?.kind ?? _itemFields.kind;

  @override
  void initState() {
    super.initState();
    final Item? initial = widget.initialItem;
    final DateTime today = ref.read(todayProvider);

    _existing = initial;
    _itemFields = ItemFieldsController(
      item: initial,
      fallbackUnit: ref.read(appSettingsProvider).defaultUnit,
      initialKind: widget.initialKind,
    );
    _lastKind = _itemFields.kind;
    if (initial == null && _lastKind != ItemKind.stocked) {
      _applyKindDefaults(_lastKind);
    }
    _stock = StockFieldsController(
      today: today,
      unit: initial?.defaultUnit ?? _itemFields.unit,
      location: initial?.defaultStorageLocation ?? _itemFields.location,
    );
    if (initial != null) {
      _name.text = initial.name;
    }
    final ScanOutcome? scan = widget.initialScan;
    if (scan != null) {
      // Before the listener below exists, so nothing rebuilds half-way.
      _applyScan(scan);
    }
    _itemFields.addListener(_syncStockWithItemFields);
  }

  /// Fills the form from a scan. Callers rebuild afterwards.
  void _applyScan(ScanOutcome outcome) {
    switch (outcome) {
      case ScanKnownItem(:final Item item):
        _existing = item;
        _scannedBarcode = null;
        _scanNotice = null;
        _name.text = item.name;
        _stock.setUnit(item.defaultUnit);
        _stock.setLocation(item.defaultStorageLocation);
      case ScanNewProduct(
          :final String barcode,
          :final ProductInfo? info,
          :final ScanNotice notice,
        ):
        _existing = null;
        _scannedBarcode = barcode;
        _scanNotice = notice;
        _itemFields.barcode.text = barcode;
        if (info != null) {
          _name.text = info.name;
          _itemFields.brand.text = info.brand ?? '';
          _itemFields.categoryId = info.suggestedCategoryId;
          final PackSize? pack = info.packSize;
          if (pack != null) {
            _itemFields.unit = pack.unit;
            _stock.setUnit(pack.unit);
            _stock.quantity.text = formatNumber(pack.amount);
          }
        }
    }
  }

  Future<void> _scanNow() async {
    final String? code = await scanBarcode(context);
    if (code == null || !mounted) {
      return;
    }
    final ScanOutcome outcome = await resolveScan(context, ref, code);
    if (!mounted) {
      return;
    }
    _applyScan(outcome);
    setState(() => _error = null);
  }

  /// While creating a new item, the purchase follows the item's unit and
  /// usual location.
  void _syncStockWithItemFields() {
    if (_existing != null) {
      return;
    }
    if (_itemFields.kind != _lastKind) {
      _lastKind = _itemFields.kind;
      if (_lastKind == ItemKind.stocked) {
        if (_itemFields.unit == Unit.portion) {
          _itemFields.unit = Unit.pcs;
        }
      } else {
        _applyKindDefaults(_lastKind);
      }
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
      final String? scanned = _scannedBarcode;
      if (item != null && scanned != null) {
        // The scanned code now identifies this item, so the next scan of it
        // goes straight to the pantry.
        await repo.addBarcode(item.id, scanned);
      }
      item ??= await repo.addItem(_itemFields.toDraft(name));

      if (quantity != null) {
        if (item.kind.isMadeAtHome && _stock.expiryDate == null) {
          _stock.expiryDate = ShelfLife.expiryFor(
            kind: item.kind,
            location: _stock.location,
            madeOn: _stock.purchaseDate,
            own: item.shelfLifeDays,
            usualLocation: item.defaultStorageLocation,
          );
        }
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
        title: Text(_title(existing)),
        actions: <Widget>[
          IconButton(
            tooltip: 'Scan barcode',
            icon: const Icon(Icons.qr_code_scanner_rounded),
            onPressed: _saving ? null : _scanNow,
          ),
        ],
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
            if (_scanNotice != null && existing == null) ...<Widget>[
              _ScanNote(notice: _scanNotice!),
              const SizedBox(height: AppSpacing.md),
            ],
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
              quantityRequired: existing != null || _kind.isMadeAtHome,
              madeAtHome: _kind.isMadeAtHome,
              madeOnLabel:
                  _kind == ItemKind.cooked ? 'Cooked on' : 'Made on',
            ),
            if (_kind.isMadeAtHome) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              Text(
                _shelfLifeHint(),
                style: context.akText.bodySmall!.copyWith(
                  color: colors.textSecondary,
                ),
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

  String _title(Item? existing) {
    if (existing != null) {
      return 'Add stock';
    }
    switch (_itemFields.kind) {
      case ItemKind.stocked:
        return 'Add item';
      case ItemKind.cooked:
        return 'Add cooked food';
      case ItemKind.homemade:
        return 'Add homemade item';
    }
  }

  String _shelfLifeHint() {
    final Item? existing = _existing;
    final int? days = existing != null
        ? ShelfLife.daysForItem(existing, _stock.location)
        : ShelfLife.daysFor(
            kind: _itemFields.kind,
            location: _stock.location,
            own: _itemFields.shelfLifeValue,
            usualLocation: _itemFields.location,
          );
    if (days == null) {
      return '';
    }
    return 'Left empty, the use-by date is ${ShelfLife.label(days)} after '
        'the date above.';
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

/// What the barcode lookup found, shown above the form after a scan.
class _ScanNote extends StatelessWidget {
  const _ScanNote({required this.notice});

  final ScanNotice notice;

  String get _text {
    switch (notice) {
      case ScanNotice.none:
        return 'Filled in from Open Food Facts. Check the details before '
            'saving.';
      case ScanNotice.notFound:
        return 'Open Food Facts does not know this barcode. Fill in the '
            'details; the barcode is saved with the item.';
      case ScanNotice.offline:
        return 'Could not reach Open Food Facts. Fill in the details; the '
            'barcode is saved with the item.';
    }
  }

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
              Icons.qr_code_scanner_rounded,
              size: AppSizes.iconMd,
              color: colors.primary,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Text(_text, style: context.akText.bodyMedium)),
          ],
        ),
      ),
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
