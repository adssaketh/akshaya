import 'alert_action.dart';
import 'alert_plan.dart';

/// Alerts due at one moment.
final class ScheduledAlert {
  const ScheduledAlert({required this.fireAt, required this.notifications});

  /// Wall-clock time in the alert time zone (see `AlertSchedule`).
  final DateTime fireAt;
  final List<AlertNotification> notifications;
}

/// A tap on a notification button that does its work without opening the app,
/// handed to the running app so it can do that work on its own data.
final class AlertActionRequest {
  const AlertActionRequest(this.action, this.payload);

  final AlertAction action;

  /// What the notification carried: the group it listed and, for an alert
  /// about one item, that item.
  final AlertPayload payload;
}

/// What the alert logic needs from the phone's notification system. The real
/// implementation uses flutter_local_notifications; tests use a fake.
abstract interface class NotificationGateway {
  /// Prepares the plugin and time zones. Safe to call more than once.
  Future<void> initialize();

  /// The current wall-clock time in the alert time zone (Asia/Kolkata).
  DateTime nowInAlertZone();

  /// Whether the system lets this app show notifications.
  Future<bool> areNotificationsAllowed();

  /// Asks the system for permission to show notifications. Returns whether it
  /// is now allowed.
  Future<bool> requestPermission();

  /// Opens the system page where notifications can be switched on for this
  /// app (for when the permission was refused and cannot be asked again).
  Future<void> openSystemSettings();

  /// Replaces everything scheduled so far with [alerts].
  Future<void> replaceScheduled(List<ScheduledAlert> alerts);

  /// Forgets every scheduled alert (one already on screen stays).
  Future<void> cancelScheduled();

  /// Shows [notifications] right away.
  Future<void> showNow(List<AlertNotification> notifications);

  /// Alerts the person taps while the app is running.
  Stream<AlertTarget> get taps;

  /// Buttons the person taps while the app is running that work without
  /// opening it (Used it, Add to list, Snooze). When the app is not running
  /// the phone does the work in a background task instead.
  Stream<AlertActionRequest> get actionRequests;

  /// The alert that started the app, once; null when the app was started any
  /// other way.
  Future<AlertTarget?> takeLaunchTarget();
}
