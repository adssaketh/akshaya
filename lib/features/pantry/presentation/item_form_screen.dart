import 'package:akshaya/core/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/feedback.dart';
import '../domain/entities.dart';
import '../domain/pantry_repository.dart';
import 'providers.dart';
import 'widgets/item_fields.dart';

/// Edits an item definition: name, category, unit, aliases and so on. Stock
/// (batches) is edited from the item's detail screen.
class ItemFormScreen extends ConsumerStatefulWidget {
  const ItemFormScreen({super.key, required this.item});

  final Item item;

  @override
  ConsumerState<ItemFormScreen> createState() => _ItemFormScreenState();
}

class _ItemFormScreenState extends ConsumerState<ItemFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _name =
      TextEditingController(text: widget.item.name);
  late final ItemFieldsController _fields =
      ItemFieldsController(item: widget.item);

  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _fields.dispose();
    _name.dispose();
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
      final Item updated = await repo.updateItem(
        _fields.toItem(widget.item, _name.text.trim()),
      );
      if (!mounted) {
        return;
      }
      navigator.pop();
      showMessage(messenger, 'Saved ${updated.name}');
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
      appBar: AppBar(title: const Text('Edit item')),
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
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Item name'),
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
            ),
            const SizedBox(height: AppSpacing.md),
            ItemFields(controller: _fields),
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
