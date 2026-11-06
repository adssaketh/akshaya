import 'package:akshaya/core/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/clock.dart';
import '../../../core/util/date_only.dart';
import '../../../core/util/money.dart';
import '../../../core/util/quantity.dart';
import '../../pantry/domain/entities.dart';
import '../../pantry/domain/storage_location.dart';
import '../../pantry/domain/unit.dart';
import '../../pantry/presentation/providers.dart';
import '../../pantry/presentation/widgets/date_field.dart';
import '../domain/order_models.dart';

/// Edits one line of the review screen. Returns the changed line, or null when
/// the person closes the sheet.
Future<OrderDraft?> showOrderDraftSheet(
  BuildContext context,
  OrderDraft draft,
) {
  return showModalBottomSheet<OrderDraft>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (BuildContext sheetContext) => _DraftSheet(draft: draft),
  );
}

class _DraftSheet extends ConsumerStatefulWidget {
  const _DraftSheet({required this.draft});

  final OrderDraft draft;

  @override
  ConsumerState<_DraftSheet> createState() => _DraftSheetState();
}

class _DraftSheetState extends ConsumerState<_DraftSheet> {
  static const List<({String label, int days, int months})> _shortcuts =
      <({String label, int days, int months})>[
    (label: '+3 days', days: 3, months: 0),
    (label: '+1 week', days: 7, months: 0),
    (label: '+1 month', days: 0, months: 1),
    (label: '+6 months', days: 0, months: 6),
  ];

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _name =
      TextEditingController(text: widget.draft.name);
  late final TextEditingController _quantity =
      TextEditingController(text: formatNumber(widget.draft.quantity));
  late final TextEditingController _price = TextEditingController(
    text: widget.draft.price == null ? '' : formatNumber(widget.draft.price!),
  );
  late Unit _unit = widget.draft.unit;
  late String _categoryId = widget.draft.categoryId;
  late StorageLocation _location = widget.draft.location;
  late DateTime? _expiry = widget.draft.expiry;
  late int? _estimateDays = widget.draft.estimateDays;

  @override
  void dispose() {
    _name.dispose();
    _quantity.dispose();
    _price.dispose();
    super.dispose();
  }

  String? _validateQuantity(String? text) {
    final double? value = double.tryParse((text ?? '').trim());
    if (value == null || value <= 0 || !value.isFinite || value > 100000) {
      return 'Enter an amount above zero';
    }
    return null;
  }

  String? _validatePrice(String? text) {
    final String value = (text ?? '').trim();
    if (value.isEmpty) {
      return null;
    }
    final double? parsed = parseMoney(value);
    if (parsed == null || parsed < 0 || !parsed.isFinite) {
      return 'Enter a valid price';
    }
    return null;
  }

  void _save() {
    final FormState? form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }
    final String priceText = _price.text.trim();
    final DateTime? chosen = _expiry;
    OrderDraft next = widget.draft.copyWith(
      name: _name.text.trim(),
      quantity: roundQty(double.parse(_quantity.text.trim())),
      unit: _unit,
      categoryId: _categoryId,
      location: _location,
      clearPrice: priceText.isEmpty,
      price: priceText.isEmpty ? null : parseMoney(priceText),
      notes: const <DraftNote>[],
    );
    if (chosen != null) {
      next = next.copyWith(expiry: chosen);
    } else if (_estimateDays == null) {
      next = next.copyWith(clearExpiry: true);
    }
    Navigator.of(context).pop(next);
  }

  @override
  Widget build(BuildContext context) {
    final AkshayaColors colors = context.akColors;
    final DateTime today = ref.watch(todayProvider);
    final List<Category> categories =
        ref.watch(categoriesProvider).value ?? const <Category>[];
    final bool hasCategory =
        categories.any((Category c) => c.id == _categoryId);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Form(
        key: _formKey,
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          children: <Widget>[
            Text(
              widget.draft.sourceName,
              style: context.akText.bodySmall!.copyWith(
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Pantry name'),
              validator: (String? text) =>
                  (text ?? '').trim().isEmpty ? 'Enter a name' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: TextFormField(
                    controller: _quantity,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Amount'),
                    validator: _validateQuantity,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: DropdownButtonFormField<Unit>(
                    initialValue: _unit,
                    decoration: const InputDecoration(labelText: 'Unit'),
                    items: <DropdownMenuItem<Unit>>[
                      for (final Unit u in Unit.values)
                        DropdownMenuItem<Unit>(
                          value: u,
                          child: Text(u.symbol),
                        ),
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
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _price,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Price paid ($currentCurrencySymbol, optional)',
              ),
              validator: _validatePrice,
            ),
            const SizedBox(height: AppSpacing.md),
            if (categories.isNotEmpty)
              DropdownButtonFormField<String>(
                initialValue: hasCategory ? _categoryId : null,
                decoration: const InputDecoration(labelText: 'Category'),
                items: <DropdownMenuItem<String>>[
                  for (final Category c in categories)
                    DropdownMenuItem<String>(value: c.id, child: Text(c.name)),
                ],
                onChanged: (String? value) {
                  if (value != null) {
                    setState(() => _categoryId = value);
                  }
                },
              ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<StorageLocation>(
              initialValue: _location,
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
                  setState(() => _location = value);
                }
              },
            ),
            const SizedBox(height: AppSpacing.md),
            DateField(
              label: _expiry == null && _estimateDays != null
                  ? 'Expires on (guessed: ${formatDateShort(addDays(today, _estimateDays!))})'
                  : 'Expires on (optional)',
              value: _expiry,
              clearable: true,
              onChanged: (DateTime? value) => setState(() {
                _expiry = value;
                // Choosing or clearing a date replaces the guess.
                _estimateDays = null;
              }),
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
                    onPressed: () => setState(() {
                      _expiry = s.months > 0
                          ? addMonths(today, s.months)
                          : addDays(today, s.days);
                      _estimateDays = null;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(onPressed: _save, child: const Text('Done')),
          ],
        ),
      ),
    );
  }
}
