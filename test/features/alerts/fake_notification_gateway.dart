import 'dart:async';

import 'package:akshaya/features/alerts/domain/alert_action.dart';
import 'package:akshaya/features/alerts/domain/alert_plan.dart';
import 'package:akshaya/features/alerts/domain/background_work.dart';
import 'package:akshaya/features/alerts/domain/notification_gateway.dart';

/// Records what the alert logic asks of the phone, so tests can check it
/// without a real notification system.
class FakeNotificationGateway implements NotificationGateway {
  FakeNotificationGateway({DateTime? now, this.allowed = true})
      : now = now ?? DateTime(2026, 11, 4, 18, 30);

  /// Wall-clock "now" in the alert time zone.
  DateTime now;
  bool allowed;

  /// What [requestPermission] answers (and sets [allowed] to).
  bool grantsPermission = true;

  AlertTarget? launchTarget;

  int initializeCalls = 0;
  int permissionRequests = 0;
  int settingsOpened = 0;
  int replaceCalls = 0;
  int cancelCalls = 0;

  /// What is scheduled now.
  List<ScheduledAlert> scheduled = <ScheduledAlert>[];

  /// Every batch passed to [showNow].
  final List<List<AlertNotification>> shown = <List<AlertNotification>>[];

  final StreamController<AlertTarget> _taps =
      StreamController<AlertTarget>.broadcast();
  final StreamController<AlertActionRequest> _actions =
      StreamController<AlertActionRequest>.broadcast();

  void tap(AlertTarget target) => _taps.add(target);

  /// Pretends the person tapped a background button on a notification.
  void pressAction(AlertAction action, AlertPayload payload) =>
      _actions.add(AlertActionRequest(action, payload));

  @override
  Future<void> initialize() async => initializeCalls++;

  @override
  DateTime nowInAlertZone() => now;

  @override
  Future<bool> areNotificationsAllowed() async => allowed;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    if (grantsPermission) {
      allowed = true;
    }
    return allowed;
  }

  @override
  Future<void> openSystemSettings() async => settingsOpened++;

  @override
  Future<void> replaceScheduled(List<ScheduledAlert> alerts) async {
    replaceCalls++;
    scheduled = List<ScheduledAlert>.of(alerts);
  }

  @override
  Future<void> cancelScheduled() async {
    cancelCalls++;
    scheduled = <ScheduledAlert>[];
  }

  @override
  Future<void> showNow(List<AlertNotification> notifications) async {
    shown.add(List<AlertNotification>.of(notifications));
  }

  @override
  Stream<AlertTarget> get taps => _taps.stream;

  @override
  Stream<AlertActionRequest> get actionRequests => _actions.stream;

  @override
  Future<AlertTarget?> takeLaunchTarget() async {
    final AlertTarget? target = launchTarget;
    launchTarget = null;
    return target;
  }
}

/// Records background-work requests.
class FakeBackgroundWork implements BackgroundWork {
  int registered = 0;
  int cancelled = 0;

  @override
  Future<void> ensureAlertRefreshRegistered() async => registered++;

  @override
  Future<void> cancelAlertRefresh() async => cancelled++;
}
