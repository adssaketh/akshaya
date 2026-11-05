import '../../count/domain/count_settings.dart';
import '../../pantry/domain/entities.dart';
import '../../shopping/domain/shopping_entities.dart';
import 'alert_digest.dart';
import 'alert_plan.dart';
import 'alert_schedule.dart';
import 'alert_settings.dart';
import 'notification_gateway.dart';

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
  Future<List<ScheduledAlert>> refresh({
    required AlertSettings settings,
    required List<ItemWithBatches> items,
    required List<ShoppingEntry> entries,
    CountSettings counts = const CountSettings(),
  }) async {
    if (!settings.enabled) {
      await _gateway.cancelScheduled();
      return const <ScheduledAlert>[];
    }

    final DateTime first = AlertSchedule.nextFire(
      _gateway.nowInAlertZone(),
      settings.minutesOfDay,
    );
    final List<DateTime> times = AlertSchedule.fireTimes(first);

    final List<ScheduledAlert> alerts = <ScheduledAlert>[];
    for (int day = 0; day < times.length; day++) {
      final AlertDigest digest = AlertDigestBuilder.build(
        items: items,
        entries: entries,
        today: AlertSchedule.dateOf(times[day]),
        settings: settings,
      );
      final List<AlertNotification> plan = <AlertNotification>[
        ...AlertPlanner.plan(digest, dayOffset: day),
        if (counts.reminderDueOn(AlertSchedule.dateOf(times[day])))
          AlertPlanner.countReminder(dayOffset: day),
      ];
      if (plan.isNotEmpty) {
        alerts.add(ScheduledAlert(fireAt: times[day], notifications: plan));
      }
    }

    await _gateway.replaceScheduled(alerts);
    return alerts;
  }

  /// Shows today's alert right now, whatever the time setting says. Returns
  /// what was shown (empty when there is nothing to say).
  Future<List<AlertNotification>> showPreview({
    required AlertSettings settings,
    required List<ItemWithBatches> items,
    required List<ShoppingEntry> entries,
  }) async {
    final AlertDigest digest = AlertDigestBuilder.build(
      items: items,
      entries: entries,
      today: AlertSchedule.dateOf(_gateway.nowInAlertZone()),
      settings: settings,
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
