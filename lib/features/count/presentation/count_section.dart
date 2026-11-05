import 'dart:async';

import 'package:akshaya/core/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../alerts/domain/alert_settings.dart';
import '../../alerts/presentation/providers.dart';
import '../../settings/presentation/providers.dart';
import '../domain/count_settings.dart';
import 'count_flow.dart';
import 'providers.dart';

/// The "Count mode" block of the Settings tab: a shortcut to start a count
/// and the optional monthly reminder.
class CountSection extends ConsumerWidget {
  const CountSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CountSettings settings = ref.watch(countSettingsProvider);
    final AlertSettings alerts = ref.watch(alertSettingsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            0,
          ),
          child: SectionHeader(title: 'Count mode'),
        ),
        ListTile(
          leading: const Icon(Icons.fact_check_outlined),
          title: const Text('Count the shelf'),
          subtitle: Text(settings.lastCountedLabel),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => unawaited(openCountMode(context)),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.event_repeat_rounded),
          title: const Text('Monthly count reminder'),
          subtitle: Text(
            alerts.enabled
                ? 'Comes with the daily alert at ${alerts.timeLabel}, unless '
                    'you already counted that month'
                : 'Needs the Daily alert above to be switched on',
          ),
          value: settings.reminderEnabled,
          onChanged: (bool value) =>
              _save(ref, settings.copyWith(reminderEnabled: value)),
        ),
        ListTile(
          enabled: settings.reminderEnabled,
          leading: const Icon(Icons.calendar_today_outlined),
          title: const Text('Remind me on day'),
          subtitle: const Text('Day of the month (1 to 28)'),
          trailing: DropdownButton<int>(
            value: settings.reminderDay,
            onChanged: settings.reminderEnabled
                ? (int? day) {
                    if (day != null) {
                      _save(ref, settings.copyWith(reminderDay: day));
                    }
                  }
                : null,
            items: <DropdownMenuItem<int>>[
              for (int d = CountSettings.minReminderDay;
                  d <= CountSettings.maxReminderDay;
                  d++)
                DropdownMenuItem<int>(value: d, child: Text('$d')),
            ],
          ),
        ),
      ],
    );
  }

  void _save(WidgetRef ref, CountSettings updated) {
    unawaited(ref.read(settingsRepositoryProvider).writeAll(updated.toMap()));
  }
}
