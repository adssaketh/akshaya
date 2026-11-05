import 'package:akshaya/core/design/design.dart';
import 'package:flutter/material.dart';

import '../../../core/util/quantity.dart';
import '../../pantry/domain/unit.dart';
import '../domain/count_session.dart';

/// What the person found on the shelf for one item.
final class CountAnswer {
  const CountAnswer({
    required this.quantity,
    required this.unit,
    required this.asWaste,
  });

  final double quantity;
  final Unit unit;

  /// True when the missing amount should be logged as waste instead of an
  /// adjustment.
  final bool asWaste;
}

/// Asks how much of [line]'s item is really there. Returns null when the
/// sheet is dismissed.
Future<CountAnswer?> showCountAdjustSheet(BuildContext context, CountLine line) {
  return showModalBottomSheet<CountAnswer>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (BuildContext sheetContext) => CountAdjustSheet(line: line),
  );
}

class CountAdjustSheet extends StatefulWidget {
  const CountAdjustSheet({super.key, required this.line});

  final CountLine line;

  @override
  State<CountAdjustSheet> createState() => _CountAdjustSheetState();
}

class _CountAdjustSheetState extends State<CountAdjustSheet> {
  late final TextEditingController _amount =
      TextEditingController(text: formatNumber(widget.line.expected));
  late Unit _unit = widget.line.unit;
  bool _asWaste = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  /// True when the typed amount is less than what the app expects.
  bool get _isLower {
    final double? typed = parseQuantity(_amount.text);
    if (typed == null || typed < 0) {
      return false;
    }
    final double inItemUnit = _unit.convertTo(typed, widget.line.unit);
    return roundQty(inItemUnit) < roundQty(widget.line.expected);
  }

  void _setAmount(double amount) {
    setState(() {
      _amount.text = formatNumber(amount);
      _amount.selection = TextSelection.collapsed(offset: _amount.text.length);
      _error = null;
    });
  }

  double get _expectedInUnit =>
      widget.line.unit.convertTo(widget.line.expected, _unit);

  void _changeUnit(Unit next) {
    final double? typed = parseQuantity(_amount.text);
    setState(() {
      if (typed != null && typed >= 0) {
        _amount.text = formatNumber(_unit.convertTo(typed, next));
      }
      _unit = next;
    });
  }

  void _submit() {
    final double? typed = parseQuantity(_amount.text);
    if (typed == null || typed < 0) {
      setState(() => _error = 'Enter what is on the shelf (0 if none).');
      return;
    }
    Navigator.of(context).pop(
      CountAnswer(quantity: typed, unit: _unit, asWaste: _asWaste && _isLower),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AkshayaColors colors = context.akColors;
    final CountLine line = widget.line;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
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
            Text(line.item.name, style: context.akText.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'The app expects ${line.expectedLabel}',
              style: context.akText.bodyMedium!.copyWith(
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                ActionChip(
                  label: const Text('None'),
                  onPressed: () => _setAmount(0),
                ),
                ActionChip(
                  label: const Text('Half'),
                  onPressed: () => _setAmount(_expectedInUnit / 2),
                ),
                ActionChip(
                  label: const Text('Same'),
                  onPressed: () => _setAmount(_expectedInUnit),
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
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (String _) => setState(() => _error = null),
                    onSubmitted: (String _) => _submit(),
                    decoration: InputDecoration(
                      labelText: 'On the shelf',
                      errorText: _error,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<Unit>(
                    key: ValueKey<String>('count-unit-${_unit.name}'),
                    initialValue: _unit,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Unit'),
                    items: <DropdownMenuItem<Unit>>[
                      for (final Unit u in line.unit.compatibleUnits)
                        DropdownMenuItem<Unit>(value: u, child: Text(u.symbol)),
                    ],
                    onChanged: (Unit? value) {
                      if (value != null) {
                        _changeUnit(value);
                      }
                    },
                  ),
                ),
              ],
            ),
            if (_isLower)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('The missing amount was wasted'),
                subtitle: const Text('Otherwise it is logged as an adjustment'),
                value: _asWaste,
                onChanged: (bool value) => setState(() => _asWaste = value),
              ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: _submit,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(AppSizes.touchTarget),
              ),
              child: const Text('Save count'),
            ),
          ],
        ),
      ),
    );
  }
}
