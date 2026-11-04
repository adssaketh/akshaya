import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../domain/alert_plan.dart';
import '../domain/notification_gateway.dart';

/// [NotificationGateway] on top of flutter_local_notifications (Android).
///
/// Alerts are scheduled with `inexactAllowWhileIdle`: no special permission is
/// needed, and the system may deliver them a few minutes late.
class LocalNotificationGateway implements NotificationGateway {
  LocalNotificationGateway({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  /// The time zone the daily time is read in.
  static const String zoneName = 'Asia/Kolkata';

  /// Status-bar icon: the alpha-only launcher icon (res/drawable-*).
  static const String _smallIcon = 'ic_launcher_monochrome';

  /// An alert left unread this long is cleared by the system, so yesterday's
  /// alert never lingers beside today's.
  static const int _timeoutMillis = 18 * 60 * 60 * 1000;

  static bool _zonesReady = false;

  final FlutterLocalNotificationsPlugin _plugin;
  final StreamController<AlertTarget> _taps =
      StreamController<AlertTarget>.broadcast();
  bool _initialized = false;

  static void _ensureZones() {
    if (!_zonesReady) {
      tz_data.initializeTimeZones();
      _zonesReady = true;
    }
  }

  @override
  Future<void> initialize() async {
    _ensureZones();
    if (_initialized) {
      return;
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings(_smallIcon),
      ),
      onDidReceiveNotificationResponse: _onTapped,
    );
    _initialized = true;
  }

  void _onTapped(NotificationResponse response) {
    final AlertTarget? target = AlertTarget.fromPayload(response.payload);
    if (target != null) {
      _taps.add(target);
    }
  }

  @override
  DateTime nowInAlertZone() {
    _ensureZones();
    return tz.TZDateTime.now(tz.getLocation(zoneName));
  }

  AndroidFlutterLocalNotificationsPlugin? get _android {
    return _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
  }

  @override
  Future<bool> areNotificationsAllowed() async {
    await initialize();
    return (await _android?.areNotificationsEnabled()) ?? false;
  }

  @override
  Future<bool> requestPermission() async {
    await initialize();
    return (await _android?.requestNotificationsPermission()) ?? false;
  }

  @override
  Future<void> openSystemSettings() async {
    await initialize();
    await _plugin.openAppNotificationSettings();
  }

  NotificationDetails _details(AlertNotification alert) {
    final bool expiry = alert.channel == AlertChannelKind.expiry;
    return NotificationDetails(
      android: AndroidNotificationDetails(
        expiry ? 'akshaya_expiry' : 'akshaya_stock',
        expiry ? 'Expiry alerts' : 'Low-stock alerts',
        channelDescription: expiry
            ? 'Daily reminder about food that has expired or is expiring soon'
            : 'Daily reminder about items that are running low',
        importance: Importance.high,
        priority: Priority.high,
        icon: _smallIcon,
        category: AndroidNotificationCategory.reminder,
        timeoutAfter: _timeoutMillis,
        styleInformation: BigTextStyleInformation(alert.body),
      ),
    );
  }

  @override
  Future<void> replaceScheduled(List<ScheduledAlert> alerts) async {
    await initialize();
    // Pending alerts only: one already on screen is not removed.
    await _plugin.cancelAllPendingNotifications();
    for (final ScheduledAlert scheduled in alerts) {
      final DateTime at = scheduled.fireAt;
      final tz.TZDateTime when = tz.TZDateTime(
        tz.getLocation(zoneName),
        at.year,
        at.month,
        at.day,
        at.hour,
        at.minute,
      );
      for (final AlertNotification alert in scheduled.notifications) {
        await _plugin.zonedSchedule(
          id: alert.id,
          scheduledDate: when,
          notificationDetails: _details(alert),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          title: alert.title,
          body: alert.body,
          payload: alert.target.payload,
        );
      }
    }
  }

  @override
  Future<void> cancelScheduled() async {
    await initialize();
    await _plugin.cancelAllPendingNotifications();
  }

  @override
  Future<void> showNow(List<AlertNotification> notifications) async {
    await initialize();
    for (final AlertNotification alert in notifications) {
      await _plugin.show(
        id: alert.id,
        title: alert.title,
        body: alert.body,
        notificationDetails: _details(alert),
        payload: alert.target.payload,
      );
    }
  }

  @override
  Stream<AlertTarget> get taps => _taps.stream;

  @override
  Future<AlertTarget?> takeLaunchTarget() async {
    await initialize();
    final NotificationAppLaunchDetails? details =
        await _plugin.getNotificationAppLaunchDetails();
    if (details == null || !details.didNotificationLaunchApp) {
      return null;
    }
    return AlertTarget.fromPayload(details.notificationResponse?.payload);
  }
}
