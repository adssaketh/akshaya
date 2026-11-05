import '../../count/domain/count_settings.dart';
import '../../pantry/domain/entities.dart';
import '../../shopping/domain/shopping_entities.dart';
import 'alert_digest.dart';
import 'alert_plan.dart';
import 'alert_schedule.dart';
import 'alert_settings.dart';
import 'alert_snoozes.dart';
import 'notification_gateway.dart';
import 'quiet_hours.dart';

/// Works out the alerts for the next few days and hands them to the phone.
///
/// A scheduled notification carries fixed text, so each refresh computes the
/// text for every scheduled day from the pantry as it is now. The app calls
/// [refresh] when something changes and the background check calls it every
/// few hours; the latest call wins.
class AlertScheduler {
  AlertScheduler(this._gateway);

  final NotificationGateway _gateway;

  /// Replaces the scheduled alerts. With alerts off, schedules nothing.
  /// Returns what was scheduled (empty when off or nothing to say).
  ///
  /// With [counts], the monthly "time to count" reminder joins the alert of
  /// its day (at the same time) unless a count was already finished that
  /// month.
  ///
  /// [prep] are the meal planner's prep reminders, each due at its own time.
  /// They are scheduled whether or not the daily alert is on, unless the
  /// settings switch prep reminders off.
  ///
  /// Anything due inside the quiet hours moves to the moment they end, and
  /// items in [snoozes] are left out of the alert of the days they are
  /// snoozed.
  Future<List<ScheduledAlert>> refresh({
    required AlertSettings settings,
    required List<ItemWithBatches> items,
    required List<ShoppingEntry> entries,
    CountSettings counts = const CountSettings(),
    List<ScheduledAlert> prep = const <ScheduledAlert>[],
    AlertSnoozes snoozes = const AlertSnoozes(),
  }) async {
    final List<ScheduledAlert> prepAlerts = settings.prep
        ? <ScheduledAlert>[
            for (final ScheduledAlert alert in prep)
              ScheduledAlert(
                fireAt: QuietHours.shift(alert.fireAt, settings),
                notifications: alert.notifications,
              ),
          ]
        : const <ScheduledAlert>[];

    if (!settings.enabled) {
      if (prepAlerts.isEmpty) {
        await _gateway.cancelScheduled();
        return const <ScheduledAlert>[];
      }
      await _gateway.replaceScheduled(prepAlerts);
      return prepAlerts;
    }

    final DateTime first = AlertSchedule.nextFire(
      _gateway.nowInAlertZone(),
      settings.minutesOfDay,
    );
    final List<DateTime> times = AlertSchedule.fireTimes(first);

    final List<ScheduledAlert> alerts = <ScheduledAlert>[];
    for (int day = 0; day < times.length; day++) {
      // The alert shows when the quiet hours end, so it is about that day.
      final DateTime fireAt = QuietHours.shift(times[day], settings);
      final DateTime date = AlertSchedule.dateOf(fireAt);
      final AlertDigest digest = AlertDigestBuilder.build(
        items: items,
        entries: entries,
        today: date,
        settings: settings,
        snoozes: snoozes,
      );
      final List<AlertNotification> plan = <AlertNotification>[
        ...AlertPlanner.plan(digest, dayOffset: day),
        if (counts.reminderDueOn(date))
          AlertPlanner.countReminder(dayOffset: day),
      ];
      if (plan.isNotEmpty) {
        alerts.add(ScheduledAlert(fireAt: fireAt, notifications: plan));
      }
    }

    final List<ScheduledAlert> all = <ScheduledAlert>[...alerts, ...prepAlerts];
    await _gateway.replaceScheduled(all);
    return all;
  }

  /// Shows today's alert right now, whatever the time setting says. Returns
  /// what was shown (empty when there is nothing to say).
  Future<List<AlertNotification>> showPreview({
    required AlertSettings settings,
    required List<ItemWithBatches> items,
    required List<ShoppingEntry> entries,
    AlertSnoozes snoozes = const AlertSnoozes(),
  }) async {
    final AlertDigest digest = AlertDigestBuilder.build(
      items: items,
      entries: entries,
      today: AlertSchedule.dateOf(_gateway.nowInAlertZone()),
      settings: settings,
      snoozes: snoozes,
    );
    final List<AlertNotification> plan = AlertPlanner.plan(
      digest,
      dayOffset: AlertPlanner.previewDayOffset,
    );
    if (plan.isNotEmpty) {
      await _gateway.showNow(plan);
    }
    return plan;
  }
}
