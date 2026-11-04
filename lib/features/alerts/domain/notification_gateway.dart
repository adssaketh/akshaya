import 'alert_plan.dart';

/// Alerts due at one moment.
final class ScheduledAlert {
  const ScheduledAlert({required this.fireAt, required this.notifications});

  /// Wall-clock time in the alert time zone (see `AlertSchedule`).
  final DateTime fireAt;
  final List<AlertNotification> notifications;
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

  /// The alert that started the app, once; null when the app was started any
  /// other way.
  Future<AlertTarget?> takeLaunchTarget();
}
