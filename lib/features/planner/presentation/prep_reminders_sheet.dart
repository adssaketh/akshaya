import 'package:akshaya/core/design/design.dart';
import 'package:flutter/material.dart';

import '../../alerts/domain/alert_settings.dart';
import '../../recipes/domain/recipe_models.dart';
import '../domain/meal_plan_models.dart';
import '../domain/prep_rules.dart';

/// Edits the prep reminders of one meal. Returns the new list, or null when
/// closed without saving.
Future<List<PrepReminder>?> showPrepReminders(
  BuildContext context,
  MealPlanEntry entry,
) {
  return showModalBottomSheet<List<PrepReminder>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (BuildContext _) => _PrepSheet(entry: entry),
  );
}

class _Row {
  _Row(PrepReminder r)
      : controller = TextEditingController(text: r.text),
        daysBefore = r.daysBefore,
        minutes = r.minutesOfDay;

  final TextEditingController controller;
  int daysBefore;
  int minutes;
}

class _PrepSheet extends StatefulWidget {
  const _PrepSheet({required this.entry});

  final MealPlanEntry entry;

  @override
  State<_PrepSheet> createState() => _PrepSheetState();
}

class _PrepSheetState extends State<_PrepSheet> {
  late final List<_Row> _rows = <_Row>[
    for (final PrepReminder r in widget.entry.prep) _Row(r),
  ];

  static const int _maxRows = 6;

  @override
  void dispose() {
    for (final _Row r in _rows) {
      r.controller.dispose();
    }
    super.dispose();
  }

  void _add(PrepReminder r) {
    if (_rows.length >= _maxRows) {
      return;
    }
    setState(() => _rows.add(_Row(r)));
  }

  void _suggest() {
    final Recipe? recipe = widget.entry.recipe;
    if (recipe == null) {
      return;
    }
    final List<PrepReminder> found =
        PrepRules.suggest(recipe, widget.entry.slot);
    setState(() {
      for (final _Row r in _rows) {
        r.controller.dispose();
      }
      _rows
        ..clear()
        ..addAll(found.map(_Row.new));
    });
  }

  Future<void> _pickTime(_Row row) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: row.minutes ~/ 60, minute: row.minutes % 60),
    );
    if (picked != null) {
      setState(() => row.minutes = picked.hour * 60 + picked.minute);
    }
  }

  void _save() {
    final List<PrepReminder> out = <PrepReminder>[];
    for (final _Row r in _rows) {
      final String text = PrepReminder.clean(r.controller.text);
      if (text.isNotEmpty) {
        out.add(
          PrepReminder(
            text: text,
            daysBefore: r.daysBefore,
            minutesOfDay: r.minutes,
          ),
        );
      }
    }
    Navigator.of(context).pop(out);
  }

  static String _dayLabel(int d) {
    switch (d) {
      case 0:
        return 'Same day';
      case 1:
        return '1 day before';
      default:
        return '$d days before';
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = context.akText;
    final AkshayaColors colors = context.akColors;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.xl,
        ),
        children: <Widget>[
          Text('Prep reminders', style: text.titleLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'For ${widget.entry.title}. Reminders arrive as notifications.',
            style: text.bodyMedium?.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          if (_rows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Text(
                'No reminders yet.',
                style: text.bodyMedium?.copyWith(color: colors.textSecondary),
              ),
            ),
          for (int i = 0; i < _rows.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    children: <Widget>[
                      TextField(
                        controller: _rows[i].controller,
                        maxLength: PrepReminder.maxTextLength,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          labelText: 'Reminder',
                          hintText: 'Soak rajma',
                          counterText: '',
                          suffixIcon: IconButton(
                            tooltip: 'Delete reminder',
                            icon: const Icon(Icons.delete_outline_rounded),
                            onPressed: () => setState(() {
                              _rows.removeAt(i).controller.dispose();
                            }),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: DropdownButton<int>(
                              isExpanded: true,
                              value: _rows[i].daysBefore,
                              items: <DropdownMenuItem<int>>[
                                for (int d = 0;
                                    d <= PrepReminder.maxDaysBefore;
                                    d++)
                                  DropdownMenuItem<int>(
                                    value: d,
                                    child: Text(_dayLabel(d)),
                                  ),
                              ],
                              onChanged: (int? v) {
                                if (v != null) {
                                  setState(() => _rows[i].daysBefore = v);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          OutlinedButton.icon(
                            onPressed: () => _pickTime(_rows[i]),
                            icon: const Icon(Icons.schedule_rounded),
                            label: Text(formatMinutesOfDay(_rows[i].minutes)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Wrap(
            spacing: AppSpacing.sm,
            children: <Widget>[
              if (_rows.length < _maxRows)
                ActionChip(
                  avatar: const Icon(Icons.add_rounded),
                  label: const Text('Add reminder'),
                  onPressed: () => _add(const PrepReminder(text: '')),
                ),
              if (widget.entry.recipe != null)
                ActionChip(
                  avatar: const Icon(Icons.auto_fix_high_rounded),
                  label: const Text('Suggest from recipe'),
                  onPressed: _suggest,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
    );
  }
}
