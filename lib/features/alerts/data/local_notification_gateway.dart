import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// Ten years of zone history instead of all of it: about a quarter of the
// size, so the one-time parse on the UI thread is that much shorter. The
// alerts only ever look at the next few days.
import 'package:timezone/data/latest_10y.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../../core/platform/device_bridge.dart';
import '../domain/alert_action.dart';
import '../domain/alert_plan.dart';
import '../domain/notification_gateway.dart';

/// [NotificationGateway] on top of flutter_local_notifications (Android).
///
/// Alerts are scheduled with `inexactAllowWhileIdle`: no special permission is
/// needed, and the system may deliver them a few minutes late.
class LocalNotificationGateway implements NotificationGateway {
  /// [backgroundHandler] is the top-level function the phone runs when a
  /// notification button that does not open the app is tapped while the app
  /// is not running. Only the app's own gateway needs one: background tasks
  /// that merely schedule alerts do not.
  LocalNotificationGateway({
    FlutterLocalNotificationsPlugin? plugin,
    this.backgroundHandler,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final void Function(NotificationResponse response)? backgroundHandler;

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
  final StreamController<AlertActionRequest> _actions =
      StreamController<AlertActionRequest>.broadcast();
  bool _initialized = false;

  /// What the last [replaceScheduled] on this isolate put in place, or null
  /// when that is not known (nothing yet, a failure, or a cancel since).
  String? _lastScheduled;

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
      onDidReceiveBackgroundNotificationResponse: backgroundHandler,
    );
    _initialized = true;
  }

  /// A tap on the notification or on one of its buttons while the app runs.
  void _onTapped(NotificationResponse response) {
    final AlertAction? action = AlertAction.fromId(response.actionId);
    final AlertPayload? payload = AlertPayload.parse(response.payload);
    if (action == null) {
      if (payload != null) {
        _taps.add(payload.target);
      }
      return;
    }
    if (action.opensApp) {
      _taps.add(_targetOf(action, payload));
    } else if (payload != null) {
      _actions.add(AlertActionRequest(action, payload));
    }
  }

  /// Where a button that opens the app leads.
  static AlertTarget _targetOf(AlertAction action, AlertPayload? payload) {
    if (action == AlertAction.showRecipes) {
      return AlertTarget.recipes;
    }
    return payload?.target ?? AlertTarget.pantryExpiring;
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
    final String id;
    final String name;
    final String description;
    switch (alert.channel) {
      case AlertChannelKind.expiry:
        id = 'akshaya_expiry';
        name = 'Expiry alerts';
        description =
            'Daily reminder about food that has expired or is expiring soon';
      case AlertChannelKind.stock:
        id = 'akshaya_stock';
        name = 'Low-stock alerts';
        description = 'Daily reminder about items that are running low';
      case AlertChannelKind.household:
        id = 'akshaya_household';
        name = 'Household changes';
        description = 'When someone in your household changes a shared list';
      case AlertChannelKind.prep:
        id = 'akshaya_prep';
        name = 'Meal prep reminders';
        description = 'Reminders to soak, thaw or start something before a meal';
    }
    return NotificationDetails(
      android: AndroidNotificationDetails(
        id,
        name,
        channelDescription: description,
        importance: Importance.high,
        priority: Priority.high,
        icon: _smallIcon,
        category: AndroidNotificationCategory.reminder,
        timeoutAfter: _timeoutMillis,
        styleInformation: BigTextStyleInformation(alert.body),
        actions: <AndroidNotificationAction>[
          for (final AlertAction action in alert.actions)
            AndroidNotificationAction(
              action.id,
              action.label,
              showsUserInterface: action.opensApp,
              cancelNotification: true,
            ),
        ],
      ),
    );
  }

  @override
  Future<void> replaceScheduled(List<ScheduledAlert> alerts) async {
    await initialize();
    // The plan is worked out again after almost every change in the app, and
    // usually comes out the same. Re-scheduling means a cancel plus one call
    // per notification, all handled on the phone's main thread (which, in
    // current Flutter, is the thread that draws the app), so an unchanged
    // plan is left alone. The pending list is checked as well, in case the
    // background task scheduled something else since.
    final String signature = _signatureOf(alerts);
    if (signature == _lastScheduled && await _pendingMatches(alerts)) {
      return;
    }
    _lastScheduled = null;
    // Pending alerts only: one already on screen is not removed.
    await _plugin.cancelAllPendingNotifications();
    final List<OverlayAlert> overlays = <OverlayAlert>[];
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
          payload: alert.payload,
        );
      }
      if (scheduled.notifications.isNotEmpty) {
        overlays.add(
          OverlayAlert(
            id: scheduled.notifications.first.id,
            title: 'Akshaya Patra',
            body: scheduled.notifications
                .map((AlertNotification a) => a.title)
                .join('\n'),
            at: when.millisecondsSinceEpoch,
          ),
        );
      }
    }
    await DeviceBridge.scheduleOverlays(overlays);
    _lastScheduled = signature;
  }

  /// Everything about [alerts] that ends up in the scheduled notifications.
  static String _signatureOf(List<ScheduledAlert> alerts) {
    final StringBuffer out = StringBuffer();
    for (final ScheduledAlert scheduled in alerts) {
      out
        ..write(scheduled.fireAt.toIso8601String())
        ..write('\u0001');
      for (final AlertNotification a in scheduled.notifications) {
        out
          ..write(a.id)
          ..write('\u0000')
          ..write(a.channel.name)
          ..write('\u0000')
          ..write(a.title)
          ..write('\u0000')
          ..write(a.body)
          ..write('\u0000')
          ..write(a.payload)
          ..write('\u0000')
          ..write(a.actions.map((AlertAction x) => x.id).join(','))
          ..write('\u0002');
      }
    }
    return out.toString();
  }

  /// True when the phone's pending notifications are exactly [alerts].
  Future<bool> _pendingMatches(List<ScheduledAlert> alerts) async {
    try {
      final List<PendingNotificationRequest> pending =
          await _plugin.pendingNotificationRequests();
      final Map<int, AlertNotification> wanted = <int, AlertNotification>{
        for (final ScheduledAlert s in alerts)
          for (final AlertNotification a in s.notifications) a.id: a,
      };
      if (pending.length != wanted.length) {
        return false;
      }
      for (final PendingNotificationRequest p in pending) {
        final AlertNotification? a = wanted[p.id];
        if (a == null ||
            p.title != a.title ||
            p.body != a.body ||
            p.payload != a.payload) {
          return false;
        }
      }
      return true;
    } on Object {
      return false;
    }
  }

  @override
  Future<void> cancelScheduled() async {
    await initialize();
    _lastScheduled = null;
    await _plugin.cancelAllPendingNotifications();
    await DeviceBridge.cancelOverlays();
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
        payload: alert.payload,
      );
    }
    if (notifications.isNotEmpty) {
      await DeviceBridge.showOverlayNow(
        'Akshaya Patra',
        notifications.map((AlertNotification a) => a.title).join('\n'),
      );
    }
  }

  @override
  Stream<AlertTarget> get taps => _taps.stream;

  @override
  Stream<AlertActionRequest> get actionRequests => _actions.stream;

  @override
  Future<AlertTarget?> takeLaunchTarget() async {
    await initialize();
    final NotificationAppLaunchDetails? details =
        await _plugin.getNotificationAppLaunchDetails();
    if (details == null || !details.didNotificationLaunchApp) {
      return null;
    }
    final NotificationResponse? response = details.notificationResponse;
    final AlertAction? action = AlertAction.fromId(response?.actionId);
    if (action != null && action.opensApp) {
      return _targetOf(action, AlertPayload.parse(response?.payload));
    }
    return AlertTarget.fromPayload(response?.payload);
  }
}
