import 'package:akshaya/core/design/design.dart';
import 'package:flutter/material.dart';

import '../../../../core/util/date_only.dart';
import '../../../../core/util/money.dart';
import '../../../../core/util/quantity.dart';
import '../../domain/entities.dart';
import '../../domain/storage_location.dart';
import '../../domain/unit.dart';
import 'date_field.dart';

String _numberText(double? value) => value == null ? '' : formatNumber(value);

/// Form state for one purchase: quantity, dates, price, store and location.
/// Used when adding stock and when editing a batch.
class StockFieldsController extends ChangeNotifier {
  StockFieldsController({
    required this.today,
    required Unit unit,
    required StorageLocation location,
    StockBatch? batch,
  })  : unit = batch?.unit ?? unit,
        location = batch?.storageLocation ?? location,
        purchaseDate = batch?.purchaseDate ?? today,
        expiryDate = batch?.expiryDate,
        openedDate = batch?.openedDate,
        opened = batch?.openedDate != null,
        quantity = TextEditingController(
          text: _numberText(batch?.quantityBought),
        ),
        remaining = TextEditingController(
          text: _numberText(batch?.quantityRemaining),
        ),
        price = TextEditingController(text: _numberText(batch?.price)),
        store = TextEditingController(text: batch?.store ?? ''),
        useWithinDays = TextEditingController(
          text: batch?.useWithinDaysAfterOpening?.toString() ?? '',
        ),
        container = TextEditingController(text: batch?.containerLabel ?? ''),
        checkBy = batch?.checkBy;

  final DateTime today;

  final TextEditingController quantity;
  final TextEditingController remaining;
  final TextEditingController price;
  final TextEditingController store;
  final TextEditingController useWithinDays;
  final TextEditingController container;

  Unit unit;
  StorageLocation location;
  DateTime purchaseDate;
  DateTime? expiryDate;
  bool opened;
  DateTime? openedDate;
  DateTime? checkBy;

  double? get quantityValue => parseQuantity(quantity.text);

  double? get remainingValue => parseQuantity(remaining.text);

  double? get priceValue => parseMoney(price.text);

  int? get useWithinValue => int.tryParse(useWithinDays.text.trim());

  void setUnit(Unit value) {
    unit = value;
    notifyListeners();
  }

  void setLocation(StorageLocation value) {
    location = value;
    notifyListeners();
  }

  void setPurchaseDate(DateTime? value) {
    if (value != null) {
      purchaseDate = value;
      notifyListeners();
    }
  }

  void setExpiryDate(DateTime? value) {
    expiryDate = value;
    notifyListeners();
  }

  void setCheckBy(DateTime? value) {
    checkBy = value;
    notifyListeners();
  }

  String? get _containerText {
    final String text = container.text.trim();
    return text.isEmpty ? null : text;
  }

  void setOpened(bool value) {
    opened = value;
    if (value) {
      openedDate ??= today;
    }
    notifyListeners();
  }

  void setOpenedDate(DateTime? value) {
    if (value != null) {
      openedDate = value;
      notifyListeners();
    }
  }

  String? get _storeText {
    final String text = store.text.trim();
    return text.isEmpty ? null : text;
  }

  DateTime? get _openedForSave => opened ? (openedDate ?? today) : null;

  int? get _useWithinForSave => opened ? useWithinValue : null;

  /// A new purchase of [itemId].
  BatchDraft toDraft(String itemId) {
    return BatchDraft(
      itemId: itemId,
      quantityBought: quantityValue ?? 0,
      unit: unit,
      purchaseDate: purchaseDate,
      expiryDate: expiryDate,
      openedDate: _openedForSave,
      useWithinDaysAfterOpening: _useWithinForSave,
      price: priceValue,
      store: _storeText,
      storageLocation: location,
      containerLabel: _containerText,
      checkBy: checkBy,
    );
  }

  /// The edited version of [original].
  StockBatch toBatch(StockBatch original) {
    final double bought = quantityValue ?? original.quantityBought;
    return StockBatch(
      id: original.id,
      itemId: original.itemId,
      quantityBought: bought,
      quantityRemaining: remainingValue ?? original.quantityRemaining,
      unit: unit,
      purchaseDate: purchaseDate,
      expiryDate: expiryDate,
      openedDate: _openedForSave,
      useWithinDaysAfterOpening: _useWithinForSave,
      price: priceValue,
      store: _storeText,
      storageLocation: location,
      containerLabel: _containerText,
      checkBy: checkBy,
      createdAt: original.createdAt,
    );
  }

  @override
  void dispose() {
    quantity.dispose();
    remaining.dispose();
    price.dispose();
    store.dispose();
    useWithinDays.dispose();
    container.dispose();
    super.dispose();
  }
}

/// Quantity, unit, dates, price, store and location inputs for a purchase.
/// Place inside a [Form] to get validation.
class StockFields extends StatelessWidget {
  const StockFields({
    super.key,
    required this.controller,
    required this.allowedUnits,
    this.showRemaining = false,
    this.quantityRequired = true,
    this.madeAtHome = false,
    this.madeOnLabel = 'Made on',
  });

  final StockFieldsController controller;

  /// Units the purchase can be in (those convertible to the item's unit).
  final List<Unit> allowedUnits;

  /// Show a "Remaining" field (editing an existing batch).
  final bool showRemaining;

  /// When false, an empty quantity is accepted (item added without stock).
  final bool quantityRequired;

  /// Cooked or homemade food: shows the container and check-by fields and
  /// labels the date "made on" instead of "purchased on".
  final bool madeAtHome;

  /// Label of the date field for made-at-home food ("Cooked on", "Made on").
  final String madeOnLabel;

  static const List<({String label, int days, int months})> _shortcuts =
      <({String label, int days, int months})>[
    (label: '+3 days', days: 3, months: 0),
    (label: '+1 week', days: 7, months: 0),
    (label: '+1 month', days: 0, months: 1),
    (label: '+6 months', days: 0, months: 6),
  ];

  String? _validateQuantity(String? text) {
    final String value = (text ?? '').trim();
    if (value.isEmpty && !quantityRequired) {
      return null;
    }
    final double? parsed = parseQuantity(value);
    if (parsed == null || parsed <= 0) {
      return 'Enter a quantity greater than zero';
    }
    return null;
  }

  String? _validateRemaining(String? text) {
    final double? parsed = parseQuantity((text ?? '').trim());
    if (parsed == null || parsed < 0) {
      return 'Enter 0 or more';
    }
    final double? bought = controller.quantityValue;
    if (bought != null && roundQty(parsed) > roundQty(bought)) {
      return 'Cannot be more than the quantity bought';
    }
    return null;
  }

  String? _validatePrice(String? text) {
    final String value = (text ?? '').trim();
    if (value.isEmpty) {
      return null;
    }
    final double? parsed = parseMoney(value);
    if (parsed == null || parsed < 0) {
      return 'Enter a valid price';
    }
    return null;
  }

  String? _validateUseWithin(String? text) {
    if (!controller.opened) {
      return null;
    }
    final String value = (text ?? '').trim();
    if (value.isEmpty) {
      return null;
    }
    final int? parsed = int.tryParse(value);
    if (parsed == null || parsed < 1) {
      return 'Enter whole days, 1 or more';
    }
    return null;
  }

  DropdownButtonFormField<Unit> _unitDropdown() {
    final Unit selected = allowedUnits.contains(controller.unit)
        ? controller.unit
        : allowedUnits.first;
    return DropdownButtonFormField<Unit>(
      key: ValueKey<String>('unit-${selected.name}-${allowedUnits.length}'),
      initialValue: selected,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Unit'),
      items: <DropdownMenuItem<Unit>>[
        for (final Unit u in allowedUnits)
          DropdownMenuItem<Unit>(value: u, child: Text(u.symbol)),
      ],
      onChanged: (Unit? value) {
        if (value != null) {
          controller.setUnit(value);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, Widget? _) {
        final DateTime base = controller.purchaseDate;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: controller.quantity,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: showRemaining ? 'Quantity bought' : 'Quantity',
                    ),
                    validator: _validateQuantity,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(flex: 2, child: _unitDropdown()),
              ],
            ),
            if (showRemaining) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: controller.remaining,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Quantity left'),
                validator: _validateRemaining,
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            DateField(
              label: madeAtHome ? madeOnLabel : 'Purchased on',
              value: controller.purchaseDate,
              onChanged: controller.setPurchaseDate,
            ),
            const SizedBox(height: AppSpacing.md),
            DateField(
              label: 'Expires on (optional)',
              value: controller.expiryDate,
              clearable: true,
              onChanged: controller.setExpiryDate,
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: <Widget>[
                for (final ({String label, int days, int months}) s
                    in _shortcuts)
                  ActionChip(
                    label: Text(s.label),
                    onPressed: () {
                      final DateTime target = s.months > 0
                          ? addMonths(base, s.months)
                          : addDays(base, s.days);
                      controller.setExpiryDate(target);
                    },
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: TextFormField(
                    controller: controller.price,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Price paid ($currentCurrencySymbol)',
                    ),
                    validator: _validatePrice,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: TextFormField(
                    controller: controller.store,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Store'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<StorageLocation>(
              key: ValueKey<String>('loc-${controller.location.name}'),
              initialValue: controller.location,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Stored in'),
              items: <DropdownMenuItem<StorageLocation>>[
                for (final StorageLocation l in StorageLocation.values)
                  DropdownMenuItem<StorageLocation>(
                    value: l,
                    child: Text(l.label),
                  ),
              ],
              onChanged: (StorageLocation? value) {
                if (value != null) {
                  controller.setLocation(value);
                }
              },
            ),
            if (madeAtHome) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: controller.container,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Container (optional)',
                  helperText: 'For example "steel dabba" or "blue box"',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              DateField(
                label: 'Check by (optional)',
                value: controller.checkBy,
                clearable: true,
                onChanged: controller.setCheckBy,
              ),
            ],
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Already opened'),
              subtitle: const Text('Opened items can spoil sooner'),
              value: controller.opened,
              onChanged: controller.setOpened,
            ),
            if (controller.opened) ...<Widget>[
              DateField(
                label: 'Opened on',
                value: controller.openedDate,
                onChanged: controller.setOpenedDate,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: controller.useWithinDays,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Use within (days after opening)',
                ),
                validator: _validateUseWithin,
              ),
            ],
          ],
        );
      },
    );
  }
}
