import 'package:akshaya/core/design/design.dart';
import 'package:flutter/material.dart';

import '../../../core/util/quantity.dart';
import '../../pantry/domain/storage_location.dart';
import '../domain/cook_plan.dart';
import '../domain/recipe_models.dart';

/// What the cook sheet confirmed: the amounts to take out and, optionally,
/// leftovers to store.
final class CookSheetResult {
  const CookSheetResult({required this.requests, this.leftover});

  final List<CookRequest> requests;
  final LeftoverPlan? leftover;
}

/// Shows what cooking would take from the pantry and lets the person tick,
/// untick and correct each amount, and optionally record leftovers. Returns
/// the confirmation, or null when closed without confirming.
Future<CookSheetResult?> showCookSheet(
  BuildContext context,
  CookPlan plan,
) {
  return showModalBottomSheet<CookSheetResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (BuildContext sheetContext) => _CookSheet(plan: plan),
  );
}

class _CookSheet extends StatefulWidget {
  const _CookSheet({required this.plan});

  final CookPlan plan;

  @override
  State<_CookSheet> createState() => _CookSheetState();
}

class _CookSheetState extends State<_CookSheet> {
  late final List<bool> _checked;
  late final List<TextEditingController> _controllers;
  final TextEditingController _portions = TextEditingController(text: '1');
  bool _hasLeftover = false;
  StorageLocation _leftoverLocation = StorageLocation.fridge;

  @override
  void initState() {
    super.initState();
    _checked = <bool>[
      for (final CookLine line in widget.plan.lines) line.startsChecked,
    ];
    _controllers = <TextEditingController>[
      for (final CookLine line in widget.plan.lines)
        TextEditingController(
          text: line.quantity == null ? '' : formatNumber(line.quantity!),
        ),
    ];
  }

  @override
  void dispose() {
    for (final TextEditingController c in _controllers) {
      c.dispose();
    }
    _portions.dispose();
    super.dispose();
  }

  double? _amount(int index) {
    final double? value =
        double.tryParse(_controllers[index].text.trim().replaceAll(',', '.'));
    if (value == null || !value.isFinite || value <= 0) {
      return null;
    }
    return value;
  }

  double? get _portionsValue {
    final double? value =
        double.tryParse(_portions.text.trim().replaceAll(',', '.'));
    if (value == null || !value.isFinite || value <= 0) {
      return null;
    }
    return value;
  }

  bool get _canConfirm {
    if (_hasLeftover && _portionsValue == null) {
      return false;
    }
    bool any = false;
    for (int i = 0; i < _checked.length; i++) {
      if (_checked[i]) {
        if (_amount(i) == null) {
          return false;
        }
        any = true;
      }
    }
    return any;
  }

  void _confirm() {
    final List<CookRequest> out = <CookRequest>[];
    for (int i = 0; i < widget.plan.lines.length; i++) {
      final double? amount = _amount(i);
      if (_checked[i] && amount != null) {
        final CookLine line = widget.plan.lines[i];
        out.add(
          CookRequest(
            itemId: line.line.itemId,
            itemName: line.line.name,
            quantity: amount,
            unit: line.unit,
          ),
        );
      }
    }
    final double? portions = _portionsValue;
    Navigator.of(context).pop(
      CookSheetResult(
        requests: out,
        leftover: _hasLeftover && portions != null
            ? LeftoverPlan(portions: portions, location: _leftoverLocation)
            : null,
      ),
    );
  }

  String? _hint(CookLine line) {
    switch (line.state) {
      case CookLineState.ready:
        return null;
      case CookLineState.short:
        return 'Only ${line.line.quantityLabel} left';
      case CookLineState.needsAmount:
        return 'How much did you use? (${line.line.quantityLabel} in stock)';
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = context.akText;
    final AkshayaColors colors = context.akColors;
    final List<CookLine> lines = widget.plan.lines;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('I cooked this', style: text.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(
              lines.isEmpty
                  ? 'Nothing in your pantry matches this recipe, so there is '
                      'nothing to take out.'
                  : 'These amounts will be taken from your pantry, oldest '
                      'stock first. Untick or change anything that is wrong.',
              style: text.bodyMedium?.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.md),
            for (int i = 0; i < lines.length; i++) ...<Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Checkbox(
                    value: _checked[i],
                    onChanged: (bool? v) =>
                        setState(() => _checked[i] = v ?? false),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.sm),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(lines[i].line.name, style: text.titleSmall),
                          if (_hint(lines[i]) case final String hint)
                            Text(
                              hint,
                              style: text.bodySmall
                                  ?.copyWith(color: colors.textSecondary),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  SizedBox(
                    width: 96,
                    child: TextField(
                      controller: _controllers[i],
                      enabled: _checked[i],
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        isDense: true,
                        suffixText: lines[i].unit.symbol,
                        errorText: _checked[i] && _amount(i) == null
                            ? 'Enter amount'
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            if (widget.plan.notInPantry.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Not in your pantry: '
                '${widget.plan.notInPantry.map((RecipeIngredient i) => i.name).join(', ')}',
                style: text.bodySmall?.copyWith(color: colors.textSecondary),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Some food is left over'),
              subtitle: const Text('Keep it in your pantry as cooked food'),
              value: _hasLeftover,
              onChanged: (bool v) => setState(() => _hasLeftover = v),
            ),
            if (_hasLeftover)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _portions,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: 'Portions left',
                        errorText:
                            _portionsValue == null ? 'Enter portions' : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: DropdownButtonFormField<StorageLocation>(
                      initialValue: _leftoverLocation,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Stored in'),
                      items: <DropdownMenuItem<StorageLocation>>[
                        for (final StorageLocation l in StorageLocation.values)
                          DropdownMenuItem<StorageLocation>(
                            value: l,
                            child: Text(l.label),
                          ),
                      ],
                      onChanged: (StorageLocation? v) {
                        if (v != null) {
                          setState(() => _leftoverLocation = v);
                        }
                      },
                    ),
                  ),
                ],
              ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _canConfirm ? _confirm : null,
                child: const Text('Take out of pantry'),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
