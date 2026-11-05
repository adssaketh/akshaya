import '../../alerts/domain/alert_plan.dart';
import '../../alerts/domain/alert_schedule.dart';
import '../../alerts/domain/notification_gateway.dart';
import 'meal_plan_models.dart';

/// Turns the prep reminders of planned meals into notifications at the times
/// they are due. Pure Dart, English only.
///
/// Times are wall-clock times in the alert time zone, carried in UTC-labelled
/// [DateTime]s exactly like the daily alert (see `AlertSchedule`).
abstract final class PrepReminderPlanner {
  /// Reminders due further ahead than this are left for a later refresh (the
  /// app and the background check re-plan every few hours).
  static const int horizonDays = 7;

  /// Most reminders scheduled at once.
  static const int maxReminders = 40;

  static const int _baseId = 6000;

  static const List<String> _weekdays = <String>[
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  /// The reminders still to come after [now] (wall-clock, alert zone), soonest
  /// first. Cooked meals and reminders already due are skipped.
  static List<ScheduledAlert> plan(
    List<MealPlanEntry> entries, {
    required DateTime now,
  }) {
    final DateTime nowWall = DateTime.utc(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute,
      now.second,
    );
    final DateTime earliest = nowWall.add(AlertSchedule.minLead);
    final DateTime latest = nowWall.add(const Duration(days: horizonDays));

    final List<({DateTime at, MealPlanEntry entry, PrepReminder reminder})> due =
        <({DateTime at, MealPlanEntry entry, PrepReminder reminder})>[];
    for (final MealPlanEntry entry in entries) {
      if (entry.isCooked) {
        continue;
      }
      for (final PrepReminder reminder in entry.prep) {
        final DateTime at = DateTime.utc(
          entry.date.year,
          entry.date.month,
          entry.date.day - reminder.daysBefore,
          reminder.minutesOfDay ~/ 60,
          reminder.minutesOfDay % 60,
        );
        if (at.isAfter(earliest) && at.isBefore(latest)) {
          due.add((at: at, entry: entry, reminder: reminder));
        }
      }
    }
    due.sort((a, b) {
      final int byTime = a.at.compareTo(b.at);
      if (byTime != 0) {
        return byTime;
      }
      return a.entry.slot.index.compareTo(b.entry.slot.index);
    });

    final List<ScheduledAlert> out = <ScheduledAlert>[];
    for (int i = 0; i < due.length && i < maxReminders; i++) {
      final ({DateTime at, MealPlanEntry entry, PrepReminder reminder}) item =
          due[i];
      out.add(
        ScheduledAlert(
          fireAt: item.at,
          notifications: <AlertNotification>[
            AlertNotification(
              id: _baseId + i,
              target: AlertTarget.mealPlan,
              channel: AlertChannelKind.prep,
              title: item.reminder.text,
              body: '${_when(item.entry, item.reminder)} '
                  '${item.entry.slot.label.toLowerCase()}: ${item.entry.title}',
            ),
          ],
        ),
      );
    }
    return out;
  }

  /// "For today's", "For tomorrow's" or "For Friday's".
  static String _when(MealPlanEntry entry, PrepReminder reminder) {
    switch (reminder.daysBefore) {
      case 0:
        return "For today's";
      case 1:
        return "For tomorrow's";
      default:
        return "For ${_weekdays[entry.date.weekday - 1]}'s";
    }
  }
}
