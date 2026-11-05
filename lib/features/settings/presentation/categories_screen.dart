import 'package:akshaya/core/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/feedback.dart';
import '../../pantry/domain/default_categories.dart';
import '../../pantry/domain/entities.dart';
import '../../pantry/domain/pantry_repository.dart';
import '../../pantry/presentation/pantry_icons.dart';
import '../../pantry/presentation/providers.dart';

/// Icon keys a category can use.
const List<String> kCategoryIconKeys = <String>[
  'vegetables',
  'fruits',
  'dairy',
  'grains',
  'dals',
  'spices',
  'oils',
  'snacks',
  'beverages',
  'bakery',
  'frozen',
  'meat',
  'cleaning',
  'personal_care',
  'other',
];

/// Add, rename, re-icon and remove categories.
class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref, {
    Category? category,
  }) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final ({String name, String iconKey})? result =
        await showDialog<({String name, String iconKey})>(
      context: context,
      builder: (BuildContext _) => _CategoryDialog(category: category),
    );
    if (result == null) {
      return;
    }
    try {
      final PantryRepository repo = ref.read(pantryRepositoryProvider);
      if (category == null) {
        await repo.addCategory(name: result.name, iconKey: result.iconKey);
      } else {
        await repo.updateCategory(
          id: category.id,
          name: result.name,
          iconKey: result.iconKey,
        );
      }
    } on Object catch (error) {
      showMessage(messenger, failureMessage(error));
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    Category category,
  ) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text('Delete "${category.name}"?'),
        content: const Text('Only categories with no items can be deleted.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) {
      return;
    }
    try {
      await ref.read(pantryRepositoryProvider).deleteCategory(category.id);
      showMessage(messenger, 'Deleted ${category.name}');
    } on Object catch (error) {
      showMessage(messenger, failureMessage(error));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AkshayaColors colors = context.akColors;
    final List<Category> categories =
        ref.watch(categoriesProvider).value ?? const <Category>[];

    return Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add category'),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: <Widget>[
          for (final Category c in categories)
            ListTile(
              leading: Icon(categoryIcon(c.iconKey), color: colors.primary),
              title: Text(c.name),
              onTap: () => _edit(context, ref, category: c),
              trailing: c.id == kDefaultCategoryId
                  ? null
                  : IconButton(
                      tooltip: 'Delete ${c.name}',
                      icon: const Icon(Icons.delete_outline_rounded),
                      onPressed: () => _delete(context, ref, c),
                    ),
            ),
        ],
      ),
    );
  }
}

class _CategoryDialog extends StatefulWidget {
  const _CategoryDialog({this.category});

  final Category? category;

  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  late final TextEditingController _name =
      TextEditingController(text: widget.category?.name ?? '');
  late String _icon = widget.category?.iconKey ?? 'other';

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AkshayaColors colors = context.akColors;
    return AlertDialog(
      title: Text(widget.category == null ? 'New category' : 'Edit category'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            TextField(
              controller: _name,
              autofocus: true,
              maxLength: 60,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                for (final String key in kCategoryIconKeys)
                  Semantics(
                    label: 'Icon $key',
                    selected: key == _icon,
                    button: true,
                    child: InkResponse(
                      onTap: () => setState(() => _icon = key),
                      radius: AppSizes.touchTarget / 2,
                      child: Container(
                        width: AppSizes.touchTarget,
                        height: AppSizes.touchTarget,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: key == _icon
                              ? colors.primary
                              : colors.surfaceAlt,
                        ),
                        child: Icon(
                          categoryIcon(key),
                          color: key == _icon
                              ? colors.onPrimary
                              : colors.textSecondary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            (name: _name.text, iconKey: _icon),
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
