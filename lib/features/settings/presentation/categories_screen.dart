import 'package:akshaya/core/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/feedback.dart';
import '../../pantry/domain/default_categories.dart';
import '../../pantry/domain/entities.dart';
import '../../pantry/domain/pantry_repository.dart';
import '../../pantry/domain/suggested_categories.dart';
import '../../pantry/presentation/pantry_icons.dart';
import '../../pantry/presentation/providers.dart';

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

  /// Offers the suggested categories that are not there yet and adds the
  /// ones that were ticked.
  Future<void> _suggest(BuildContext context, WidgetRef ref) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final List<Category> existing =
        ref.read(categoriesProvider).value ?? const <Category>[];
    final List<SuggestedCategory> options = missingSuggestions(existing);
    if (options.isEmpty) {
      showMessage(messenger, 'You already have every suggested category.');
      return;
    }
    final List<SuggestedCategory>? chosen =
        await showModalBottomSheet<List<SuggestedCategory>>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext _) => _SuggestionsSheet(options: options),
    );
    if (chosen == null || chosen.isEmpty) {
      return;
    }
    final PantryRepository repo = ref.read(pantryRepositoryProvider);
    int added = 0;
    for (final SuggestedCategory s in chosen) {
      try {
        await repo.addCategory(name: s.name, iconKey: s.iconKey);
        added++;
      } on Object catch (error) {
        showMessage(messenger, failureMessage(error));
      }
    }
    if (added > 0) {
      showMessage(
        messenger,
        added == 1 ? 'Added 1 category' : 'Added $added categories',
      );
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
      appBar: AppBar(
        title: const Text('Categories'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Suggested categories',
            icon: const Icon(Icons.playlist_add_rounded),
            onPressed: () => _suggest(context, ref),
          ),
        ],
      ),
      floatingActionButton: AkshayaFabCluster(
        heroTag: 'categories-add-fab',
        label: 'Add category',
        onPressed: () => _edit(context, ref),
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
                  Tooltip(
                    message: categoryIconLabel(key),
                    child: Semantics(
                      label: 'Icon ${categoryIconLabel(key)}',
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

/// Bottom sheet listing suggested categories to tick; pops the ticked ones.
class _SuggestionsSheet extends StatefulWidget {
  const _SuggestionsSheet({required this.options});

  final List<SuggestedCategory> options;

  @override
  State<_SuggestionsSheet> createState() => _SuggestionsSheetState();
}

class _SuggestionsSheetState extends State<_SuggestionsSheet> {
  final Set<String> _picked = <String>{};

  void _toggleAll() {
    setState(() {
      if (_picked.length == widget.options.length) {
        _picked.clear();
      } else {
        _picked.addAll(<String>[for (final SuggestedCategory s in widget.options) s.name]);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final AkshayaColors colors = context.akColors;
    final double maxHeight = MediaQuery.sizeOf(context).height * 0.85;
    final bool all = _picked.length == widget.options.length;

    final List<Widget> rows = <Widget>[];
    String? group;
    for (final SuggestedCategory s in widget.options) {
      if (s.group != group) {
        rows.add(
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              group == null ? AppSpacing.md : AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.xs,
            ),
            child: Text(
              s.group,
              style: context.akText.labelLarge!
                  .copyWith(color: colors.primary),
            ),
          ),
        );
        group = s.group;
      }
      rows.add(
        CheckboxListTile(
          value: _picked.contains(s.name),
          onChanged: (bool? on) => setState(() {
            if (on ?? false) {
              _picked.add(s.name);
            } else {
              _picked.remove(s.name);
            }
          }),
          secondary: Icon(categoryIcon(s.iconKey), color: colors.primary),
          title: Text(s.name),
        ),
      );
    }

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.sm,
                0,
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Suggested categories',
                      style: context.akText.titleLarge,
                    ),
                  ),
                  TextButton(
                    onPressed: _toggleAll,
                    child: Text(all ? 'Clear' : 'Select all'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Text(
                'Tick the ones you want. You can rename, re-icon or delete '
                'any of them later.',
                style: context.akText.bodyMedium!
                    .copyWith(color: colors.textSecondary),
              ),
            ),
            Flexible(
              child: ListView(shrinkWrap: true, children: rows),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: FilledButton(
                onPressed: _picked.isEmpty
                    ? null
                    : () => Navigator.of(context).pop(
                          <SuggestedCategory>[
                            for (final SuggestedCategory s in widget.options)
                              if (_picked.contains(s.name)) s,
                          ],
                        ),
                child: Text(
                  _picked.isEmpty
                      ? 'Add categories'
                      : _picked.length == 1
                          ? 'Add 1 category'
                          : 'Add ${_picked.length} categories',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
