import 'package:akshaya/core/design/design.dart';
import 'package:flutter/material.dart';

import '../../../core/util/quantity.dart';
import '../domain/cook_plan.dart';
import '../domain/recipe_models.dart';

/// Shows what cooking would take from the pantry and lets the person tick,
/// untick and correct each amount. Returns the confirmed deductions, or null
/// when closed without confirming.
Future<List<CookRequest>?> showCookSheet(
  BuildContext context,
  CookPlan plan,
) {
  return showModalBottomSheet<List<CookRequest>>(
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

  bool get _canConfirm {
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
    Navigator.of(context).pop(out);
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
