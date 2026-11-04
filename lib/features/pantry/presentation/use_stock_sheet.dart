import 'package:akshaya/core/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/feedback.dart';
import '../../../core/util/quantity.dart';
import '../domain/consumption_type.dart';
import '../domain/entities.dart';
import '../domain/pantry_repository.dart';
import '../domain/stock_logic.dart';
import '../domain/unit.dart';
import 'providers.dart';

/// Opens the "Use" sheet for [stock]: quick amounts, a custom amount, a unit
/// and a reason (used, wasted, expired, given away).
Future<void> showUseStockSheet(BuildContext context, ItemStock stock) {
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (BuildContext sheetContext) {
      return UseStockSheet(stock: stock, messenger: messenger);
    },
  );
}

class UseStockSheet extends ConsumerStatefulWidget {
  const UseStockSheet({
    super.key,
    required this.stock,
    required this.messenger,
  });

  final ItemStock stock;

  /// Shows the result and Undo after the sheet closes.
  final ScaffoldMessengerState messenger;

  @override
  ConsumerState<UseStockSheet> createState() => _UseStockSheetState();
}

class _UseStockSheetState extends ConsumerState<UseStockSheet> {
  static const List<ConsumptionType> _reasons = <ConsumptionType>[
    ConsumptionType.used,
    ConsumptionType.wasted,
    ConsumptionType.expired,
    ConsumptionType.givenAway,
  ];

  final TextEditingController _amount = TextEditingController();
  late Unit _unit = widget.stock.item.defaultUnit;
  ConsumptionType _type = ConsumptionType.used;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  String _quickLabel(double amount) {
    String text;
    if (amount == 0.25) {
      text = '¼';
    } else if (amount == 0.5) {
      text = '½';
    } else if (amount == 0.75) {
      text = '¾';
    } else {
      text = formatNumber(amount);
    }
    return '$text ${_unit.symbol}';
  }

  void _setAmount(double amount) {
    setState(() {
      _amount.text = formatNumber(amount);
      _amount.selection = TextSelection.collapsed(offset: _amount.text.length);
      _error = null;
    });
  }

  void _useAll() {
    final ItemStock stock = widget.stock;
    final double all = stock.item.defaultUnit.convertTo(
      stock.totalRemaining,
      _unit,
    );
    _setAmount(all);
  }

  String get _actionLabel {
    return _type == ConsumptionType.used
        ? 'Use'
        : 'Log ${_type.label.toLowerCase()}';
  }

  Future<void> _submit() async {
    final double? quantity = parseQuantity(_amount.text);
    if (quantity == null || isZeroQty(quantity)) {
      setState(() => _error = 'Enter an amount greater than zero.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    final PantryRepository repo = ref.read(pantryRepositoryProvider);
    final NavigatorState navigator = Navigator.of(context);
    final ItemStock stock = widget.stock;
    final ConsumptionType type = _type;
    final Unit unit = _unit;

    try {
      final UseResult result = await repo.useStock(
        itemId: stock.item.id,
        quantity: quantity,
        unit: unit,
        type: type,
      );
      if (!mounted) {
        return;
      }
      navigator.pop();
      showUndoSnackBar(
        widget.messenger,
        message: '${type.label} ${unit.format(quantity)} of ${stock.item.name}',
        onUndo: () => repo.undoUse(result),
      );
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _error = failureMessage(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ItemStock stock = widget.stock;
    final AkshayaColors colors = context.akColors;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(stock.item.name, style: context.akText.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${stock.remainingLabel} left',
              style: context.akText.bodyMedium!.copyWith(
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                for (final double amount in _unit.quickAmounts)
                  ActionChip(
                    label: Text(_quickLabel(amount)),
                    onPressed: _busy ? null : () => _setAmount(amount),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _amount,
                    enabled: !_busy,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (String _) {
                      if (_error != null) {
                        setState(() => _error = null);
                      }
                    },
                    decoration: InputDecoration(
                      labelText: 'Amount',
                      errorText: _error,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<Unit>(
                    key: ValueKey<String>('use-unit-${_unit.name}'),
                    initialValue: _unit,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Unit'),
                    items: <DropdownMenuItem<Unit>>[
                      for (final Unit u in stock.item.defaultUnit.compatibleUnits)
                        DropdownMenuItem<Unit>(
                          value: u,
                          child: Text(u.symbol),
                        ),
                    ],
                    onChanged: _busy
                        ? null
                        : (Unit? value) {
                            if (value != null) {
                              setState(() => _unit = value);
                            }
                          },
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<ConsumptionType>(
              key: ValueKey<String>('use-type-${_type.name}'),
              initialValue: _type,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Reason'),
              items: <DropdownMenuItem<ConsumptionType>>[
                for (final ConsumptionType t in _reasons)
                  DropdownMenuItem<ConsumptionType>(
                    value: t,
                    child: Text(t.label),
                  ),
              ],
              onChanged: _busy
                  ? null
                  : (ConsumptionType? value) {
                      if (value != null) {
                        setState(() => _type = value);
                      }
                    },
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: <Widget>[
                TextButton(
                  onPressed: _busy ? null : _useAll,
                  child: const Text('Use all'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: Text(_actionLabel),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
