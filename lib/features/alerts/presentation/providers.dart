import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/clock.dart';
import '../../count/domain/count_settings.dart';
import '../../count/presentation/providers.dart';
import '../../pantry/domain/entities.dart';
import '../../pantry/presentation/providers.dart';
import '../../settings/presentation/providers.dart';
import '../../shopping/domain/shopping_entities.dart';
import '../../shopping/presentation/providers.dart';
import '../data/local_notification_gateway.dart';
import '../data/workmanager_background_work.dart';
import '../domain/alert_plan.dart';
import '../domain/alert_scheduler.dart';
import '../domain/alert_settings.dart';
import '../domain/background_work.dart';
import '../domain/notification_gateway.dart';

/// The phone's notification system. Tests override it with a fake.
final Provider<NotificationGateway> notificationGatewayProvider =
    Provider<NotificationGateway>((Ref ref) => LocalNotificationGateway());

/// The periodic background check. Tests override it with a fake.
final Provider<BackgroundWork> backgroundWorkProvider =
    Provider<BackgroundWork>((Ref ref) => const WorkmanagerBackgroundWork());

final Provider<AlertScheduler> alertSchedulerProvider =
    Provider<AlertScheduler>((Ref ref) {
  return AlertScheduler(ref.watch(notificationGatewayProvider));
});

/// The saved alert settings (defaults until they have loaded).
final Provider<AlertSettings> alertSettingsProvider =
    Provider<AlertSettings>((Ref ref) {
  final Map<String, String> stored =
      ref.watch(settingsMapProvider).value ?? const <String, String>{};
  return AlertSettings.fromMap(stored);
});

/// The alert setting for "expiring soon", for the pantry providers.
final Provider<int> savedWarningDaysProvider = Provider<int>((Ref ref) {
  return ref.watch(alertSettingsProvider.select((AlertSettings s) => s.warningDays));
});

/// Whether the system lets the app show notifications. Invalidate it after
/// asking and when the app returns to the foreground.
final FutureProvider<bool> notificationsAllowedProvider =
    FutureProvider<bool>((Ref ref) {
  return ref.watch(notificationGatewayProvider).areNotificationsAllowed();
});

/// The place an alert the person tapped wants to open. The app shell opens it
/// and then clears it.
final NotifierProvider<AlertTargetNotifier, AlertTarget?> alertTargetProvider =
    NotifierProvider<AlertTargetNotifier, AlertTarget?>(
  AlertTargetNotifier.new,
);

class AlertTargetNotifier extends Notifier<AlertTarget?> {
  @override
  AlertTarget? build() => null;

  void open(AlertTarget target) => state = target;

  void clear() => state = null;
}

/// Keeps the scheduled alerts and the background check in step with the app.
///
/// Read once at start-up. It re-plans (after a short pause, so a burst of
/// edits counts once) whenever the settings, pantry, shopping lists or the
/// date change, and it hands taps on alerts to [alertTargetProvider].
final Provider<void> alertCoordinatorProvider = Provider<void>((Ref ref) {
  final NotificationGateway gateway = ref.watch(notificationGatewayProvider);
  Timer? pause;
  bool disposed = false;
  bool workRegistered = false;

  Future<void> replan() async {
    try {
      final Map<String, String> stored =
          await ref.read(settingsRepositoryProvider).readAll();
      final AlertSettings settings = AlertSettings.fromMap(stored);
      final CountSettings counts = CountSettings.fromMap(stored);
      final AlertScheduler scheduler = ref.read(alertSchedulerProvider);
      final BackgroundWork work = ref.read(backgroundWorkProvider);

      if (!settings.enabled) {
        await scheduler.refresh(
          settings: settings,
          items: const <ItemWithBatches>[],
          entries: const <ShoppingEntry>[],
        );
        await work.cancelAlertRefresh();
        workRegistered = false;
        return;
      }

      // Both are listened to below; when either has not loaded yet, the
      // listener queues another pass as soon as it does.
      final List<ItemWithBatches>? items = ref.read(itemsStreamProvider).value;
      final List<ShoppingEntry>? entries =
          ref.read(shoppingEntriesProvider).value;
      if (items == null || entries == null) {
        return;
      }
      await gateway.initialize();
      await scheduler.refresh(
        settings: settings,
        items: items,
        entries: entries,
        counts: counts,
      );
      if (!workRegistered) {
        await work.ensureAlertRefreshRegistered();
        workRegistered = true;
      }
    } on Object catch (error) {
      // Alerts are a convenience: never let a failure here disturb the app.
      debugPrint('Could not update alerts: $error');
    }
  }

  void queue() {
    pause?.cancel();
    pause = Timer(const Duration(seconds: 2), () {
      if (!disposed) {
        unawaited(replan());
      }
    });
  }

  // Only the alert settings matter here. Listening to the whole settings table
  // re-planned the alerts (and woke the database) on every usage counter that
  // sync or AI bumped.
  ref.listen<AlertSettings>(
    alertSettingsProvider,
    (previous, next) => queue(),
  );
  ref.listen<AsyncValue<List<ItemWithBatches>>>(
    itemsStreamProvider,
    (previous, next) => queue(),
  );
  ref.listen<AsyncValue<List<ShoppingEntry>>>(
    shoppingEntriesProvider,
    (previous, next) => queue(),
  );
  ref.listen<DateTime>(todayProvider, (previous, next) => queue());
  // The monthly count reminder: switching it on or off, picking another day,
  // or finishing a count changes what is scheduled.
  ref.listen<CountSettings>(
    countSettingsProvider,
    (previous, next) => queue(),
  );

  final StreamSubscription<AlertTarget> taps = gateway.taps.listen(
    (AlertTarget target) =>
        ref.read(alertTargetProvider.notifier).open(target),
  );

  ref.onDispose(() {
    disposed = true;
    pause?.cancel();
    unawaited(taps.cancel());
  });

  // An alert that started the app.
  unawaited(() async {
    try {
      await gateway.initialize();
      final AlertTarget? launched = await gateway.takeLaunchTarget();
      if (launched != null && !disposed) {
        ref.read(alertTargetProvider.notifier).open(launched);
      }
    } on Object catch (error) {
      debugPrint('Could not read the launching alert: $error');
    }
  }());

  queue();
});
