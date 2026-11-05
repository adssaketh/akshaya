import 'package:akshaya/core/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/feedback.dart';
import '../../pantry/domain/entities.dart';
import '../../pantry/presentation/pantry_icons.dart';
import '../../pantry/presentation/providers.dart';
import '../../settings/presentation/providers.dart';
import '../domain/freeze_rules.dart';
import 'providers.dart';

/// "60 days" or "Not offered".
String freezeDaysLabel(int? days) {
  if (days == null) {
    return 'Freeze not offered';
  }
  return days == 1 ? '1 day' : '$days days';
}

/// Settings: how long frozen food of each category keeps. The Freeze button
/// moves a batch to the freezer and sets its date this many days from today
/// (or keeps a later printed date).
class FreezeRulesScreen extends ConsumerWidget {
  const FreezeRulesScreen({super.key});

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    Category category,
    FreezeSettings settings,
  ) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final ({bool reset, int? days})? result =
        await showDialog<({bool reset, int? days})>(
      context: context,
      builder: (BuildContext _) => _FreezeDaysDialog(
        category: category,
        current: settings.daysFor(category.id),
        isCustom: settings.isCustom(category.id),
      ),
    );
    if (result == null) {
      return;
    }
    final FreezeSettings next = result.reset
        ? settings.reset(category.id)
        : settings.withDays(category.id, result.days);
    try {
      await ref.read(settingsRepositoryProvider).writeAll(next.toMap());
    } on Object catch (error) {
      showMessage(messenger, failureMessage(error));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<Category> categories =
        ref.watch(categoriesProvider).value ?? const <Category>[];
    final FreezeSettings settings = ref.watch(freezeSettingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Freezing rules')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(
              'How long bought food of each category keeps once frozen. '
              'Cooked and homemade food use their own shelf life. Food that '
              'has already expired is never offered Freeze.',
              style: context.akText.bodyMedium!.copyWith(
                color: context.akColors.textSecondary,
              ),
            ),
          ),
          for (final Category category in categories)
            ListTile(
              leading: Icon(categoryIcon(category.iconKey)),
              title: Text(category.name),
              subtitle: Text(
                '${freezeDaysLabel(settings.daysFor(category.id))}'
                '${settings.isCustom(category.id) ? ' (changed)' : ''}',
              ),
              trailing: const Icon(Icons.edit_outlined),
              onTap: () => _edit(context, ref, category, settings),
            ),
        ],
      ),
    );
  }
}

class _FreezeDaysDialog extends StatefulWidget {
  const _FreezeDaysDialog({
    required this.category,
    required this.current,
    required this.isCustom,
  });

  final Category category;
  final int? current;
  final bool isCustom;

  @override
  State<_FreezeDaysDialog> createState() => _FreezeDaysDialogState();
}

class _FreezeDaysDialogState extends State<_FreezeDaysDialog> {
  late final TextEditingController _days = TextEditingController(
    text: (widget.current ?? FreezeDefaults.unknownCategoryDays).toString(),
  );
  late bool _offered = widget.current != null;
  String? _error;

  @override
  void dispose() {
    _days.dispose();
    super.dispose();
  }

  void _save() {
    if (!_offered) {
      Navigator.of(context).pop((reset: false, days: null));
      return;
    }
    final int? days = int.tryParse(_days.text.trim());
    if (days == null || days < 1 || days > kMaxFreezeDays) {
      setState(() => _error = 'Enter 1 to $kMaxFreezeDays days.');
      return;
    }
    Navigator.of(context).pop((reset: false, days: days));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.category.name),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Offer Freeze'),
            value: _offered,
            onChanged: (bool value) => setState(() => _offered = value),
          ),
          if (_offered)
            TextField(
              controller: _days,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Keeps in the freezer (days)',
                errorText: _error,
              ),
              onChanged: (String _) {
                if (_error != null) {
                  setState(() => _error = null);
                }
              },
            ),
        ],
      ),
      actions: <Widget>[
        if (widget.isCustom)
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop((reset: true, days: null)),
            child: const Text('Reset'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
