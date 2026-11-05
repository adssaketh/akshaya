import 'package:akshaya/core/design/design.dart';
import 'package:flutter/material.dart';

import '../../../core/util/date_only.dart';
import '../domain/ai_plan_service.dart';
import '../domain/meal_slot.dart';
import '../domain/plan_prompt.dart';
import '../domain/plan_validator.dart';

/// Asks which empty days and meals "Plan my week" should fill. Returns the
/// slots, or null when closed.
Future<List<PlanSlot>?> showPlanWeekSheet(
  BuildContext context, {
  required DateTime weekStart,
  required DateTime today,
  required Set<String> taken,
}) {
  return showModalBottomSheet<List<PlanSlot>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (BuildContext _) =>
        _PlanWeekSheet(weekStart: weekStart, today: today, taken: taken),
  );
}

const List<String> _dayNames = <String>[
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];

class _PlanWeekSheet extends StatefulWidget {
  const _PlanWeekSheet({
    required this.weekStart,
    required this.today,
    required this.taken,
  });

  final DateTime weekStart;
  final DateTime today;
  final Set<String> taken;

  @override
  State<_PlanWeekSheet> createState() => _PlanWeekSheetState();
}

class _PlanWeekSheetState extends State<_PlanWeekSheet> {
  late final Set<int> _days = <int>{
    for (int i = 0; i < 7; i++)
      if (!_isPast(i)) i,
  };
  final Set<MealSlot> _slots = <MealSlot>{MealSlot.lunch, MealSlot.dinner};

  bool _isPast(int i) =>
      addDays(widget.weekStart, i).isBefore(dateOnly(widget.today));

  List<PlanSlot> _chosen() {
    final List<PlanSlot> out = <PlanSlot>[];
    for (int i = 0; i < 7; i++) {
      if (!_days.contains(i)) {
        continue;
      }
      final DateTime day = addDays(widget.weekStart, i);
      for (final MealSlot s in MealSlot.values) {
        if (_slots.contains(s) &&
            !widget.taken.contains(PlanResponseValidator.slotKey(day, s))) {
          out.add(PlanSlot(day, s));
        }
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = context.akText;
    final AkshayaColors colors = context.akColors;
    final List<PlanSlot> chosen = _chosen();
    final int count =
        chosen.length > AiPlanService.maxSlots
            ? AiPlanService.maxSlots
            : chosen.length;
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      children: <Widget>[
        Text('Plan my week', style: text.titleLarge),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Fills only empty slots, using what is expiring first. Your own '
          'meals are never changed.',
          style: text.bodyMedium?.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Days', style: text.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          children: <Widget>[
            for (int i = 0; i < 7; i++)
              FilterChip(
                label: Text(_dayNames[i]),
                selected: _days.contains(i),
                onSelected: _isPast(i)
                    ? null
                    : (bool on) => setState(() {
                          on ? _days.add(i) : _days.remove(i);
                        }),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Meals', style: text.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          children: <Widget>[
            for (final MealSlot s in MealSlot.values)
              FilterChip(
                label: Text(s.label),
                selected: _slots.contains(s),
                onSelected: (bool on) => setState(() {
                  on ? _slots.add(s) : _slots.remove(s);
                }),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Sends only your item names, amounts, units, expiry dates and cooking '
          'preferences to Google. Uses one AI call'
          '${chosen.length > AiPlanService.maxSlots ? ' for the first ${AiPlanService.maxSlots} meals' : ''}.',
          style: text.bodySmall?.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton.icon(
          onPressed: count == 0
              ? null
              : () => Navigator.of(context).pop(chosen),
          icon: const Icon(Icons.auto_awesome_rounded),
          label: Text(count == 0 ? 'Nothing to plan' : 'Plan $count meals'),
        ),
      ],
    );
  }
}
