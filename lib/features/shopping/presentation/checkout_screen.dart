import 'package:akshaya/core/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/clock.dart';
import '../../../core/ui/feedback.dart';
import '../../../core/util/date_only.dart';
import '../../../core/util/money.dart';
import '../../pantry/presentation/widgets/date_field.dart';
import '../domain/shopping_entities.dart';
import '../domain/shopping_repository.dart';
import 'providers.dart';

/// "Done shopping": asks only for expiry and price of what was checked off,
/// then moves it into the pantry.
class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key, required this.list, required this.entries});

  final ShoppingList list;

  /// The checked-off entries being bought.
  final List<ShoppingEntry> entries;

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

/// What the person entered for one entry.
class _LineInput {
  _LineInput(this.entry);

  final ShoppingEntry entry;
  final TextEditingController price = TextEditingController();
  DateTime? expiry;
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  static const List<({String label, int days, int months})> _shortcuts =
      <({String label, int days, int months})>[
    (label: '+3 days', days: 3, months: 0),
    (label: '+1 week', days: 7, months: 0),
    (label: '+1 month', days: 0, months: 1),
    (label: '+6 months', days: 0, months: 6),
  ];

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _store = TextEditingController();
  late final List<_LineInput> _lines = <_LineInput>[
    for (final ShoppingEntry e in widget.entries) _LineInput(e),
  ];
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _store.dispose();
    for (final _LineInput line in _lines) {
      line.price.dispose();
    }
    super.dispose();
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

  Future<void> _submit() async {
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

    final ShoppingRepository repo = ref.read(shoppingRepositoryProvider);
    final NavigatorState navigator = Navigator.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    try {
      final CheckoutResult result = await repo.completeShopping(
        listId: widget.list.id,
        lines: <CheckoutLine>[
          for (final _LineInput line in _lines)
            CheckoutLine(
              entryId: line.entry.id,
              expiryDate: line.expiry,
              price: parseMoney(line.price.text),
            ),
        ],
        store: _store.text,
      );
      if (!mounted) {
        return;
      }
      navigator.pop();
      showUndoSnackBar(
        messenger,
        message: result.count == 1
            ? 'Added 1 item to your pantry'
            : 'Added ${result.count} items to your pantry',
        onUndo: () => repo.undoCompleteShopping(result),
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
    final DateTime today = ref.watch(todayProvider);
    final int count = _lines.length;

    return Scaffold(
      appBar: AppBar(title: const Text('Done shopping')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: FilledButton(
            onPressed: _saving ? null : _submit,
            child: Text(
              _saving
                  ? 'Adding...'
                  : (count == 1
                      ? 'Add 1 item to pantry'
                      : 'Add $count items to pantry'),
            ),
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
            Text(
              'Expiry and price are optional. Skip any you do not need.',
              style: context.akText.bodyMedium!.copyWith(
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _store,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Store (optional)',
                hintText: 'Applies to everything below',
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            for (final _LineInput line in _lines) ...<Widget>[
              _buildLine(context, line, today),
              const SizedBox(height: AppSpacing.md),
            ],
            if (_error != null)
              Text(
                _error!,
                style: context.akText.bodyMedium!.copyWith(
                  color: colors.expired.foreground,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLine(BuildContext context, _LineInput line, DateTime today) {
    final AkshayaColors colors = context.akColors;

    return Material(
      color: colors.surface,
      borderRadius: AppRadius.cardBorder,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(line.entry.name, style: context.akText.titleSmall),
            Text(
              line.entry.quantityLabel,
              style: context.akText.bodySmall!.copyWith(
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            DateField(
              label: 'Expires on (optional)',
              value: line.expiry,
              clearable: true,
              onChanged: (DateTime? value) => setState(() => line.expiry = value),
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
                      line.expiry = s.months > 0
                          ? addMonths(today, s.months)
                          : addDays(today, s.days);
                    }),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: line.price,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Price paid ($kCurrencySymbol, optional)',
              ),
              validator: _validatePrice,
            ),
          ],
        ),
      ),
    );
  }
}
