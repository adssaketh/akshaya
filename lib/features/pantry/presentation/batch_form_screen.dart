import 'package:akshaya/core/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/clock.dart';
import '../../../core/ui/feedback.dart';
import '../domain/entities.dart';
import '../domain/item_kind.dart';
import '../domain/pantry_repository.dart';
import 'providers.dart';
import 'widgets/stock_fields.dart';

/// Edits one purchase (batch): quantities, dates, price, store, location.
class BatchFormScreen extends ConsumerStatefulWidget {
  const BatchFormScreen({super.key, required this.item, required this.batch});

  final Item item;
  final StockBatch batch;

  @override
  ConsumerState<BatchFormScreen> createState() => _BatchFormScreenState();
}

class _BatchFormScreenState extends ConsumerState<BatchFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final StockFieldsController _fields = StockFieldsController(
    today: ref.read(todayProvider),
    unit: widget.batch.unit,
    location: widget.batch.storageLocation,
    batch: widget.batch,
  );

  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _fields.dispose();
    super.dispose();
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

    try {
      await repo.updateBatch(_fields.toBatch(widget.batch));
      if (!mounted) {
        return;
      }
      navigator.pop();
      showMessage(messenger, 'Saved changes to ${widget.item.name}');
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

    return Scaffold(
      appBar: AppBar(title: Text('Edit ${widget.item.name} batch')),
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
            StockFields(
              controller: _fields,
              allowedUnits: widget.item.defaultUnit.compatibleUnits,
              showRemaining: true,
              madeAtHome: widget.item.kind.isMadeAtHome,
              madeOnLabel: widget.item.kind == ItemKind.cooked
                  ? 'Cooked on'
                  : 'Made on',
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
}
