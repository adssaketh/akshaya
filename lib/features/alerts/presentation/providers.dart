import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/diagnostics/diag.dart';
import '../../../core/time/clock.dart';
import '../../count/domain/count_settings.dart';
import '../../count/presentation/providers.dart';
import '../../pantry/domain/entities.dart';
import '../../pantry/presentation/providers.dart';
import '../../planner/domain/meal_plan_models.dart';
import '../../planner/domain/prep_schedule.dart';
import '../../planner/presentation/providers.dart';
import '../../settings/presentation/providers.dart';
import '../../shopping/domain/shopping_entities.dart';
import '../../shopping/presentation/providers.dart';
import '../../travel/domain/trip_models.dart';
import '../../travel/presentation/trip_providers.dart';
import '../data/local_notification_gateway.dart';
import '../data/notification_background_handler.dart';
import '../data/workmanager_background_work.dart';
import '../domain/alert_plan.dart';
import '../domain/alert_scheduler.dart';
import '../domain/alert_settings.dart';
import '../domain/alert_snoozes.dart';
import '../domain/background_work.dart';
import '../domain/notification_action_runner.dart';
import '../domain/notification_gateway.dart';

/// The phone's notification system. Tests override it with a fake.
final Provider<NotificationGateway> notificationGatewayProvider =
    Provider<NotificationGateway>(
  (Ref ref) => LocalNotificationGateway(
    backgroundHandler: akshayaNotificationBackgroundHandler,
  ),
);

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

/// Items whose alerts are snoozed (the "Snooze 1 day" button).
final Provider<AlertSnoozes> alertSnoozesProvider =
    Provider<AlertSnoozes>((Ref ref) {
  final Map<String, String> stored =
      ref.watch(settingsMapProvider).value ?? const <String, String>{};
  return AlertSnoozes.fromMap(stored);
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

      // Prep reminders for planned meals. They are scheduled even when the
      // daily alert is off, so the background check stays registered for them.
      final List<MealPlanEntry>? meals = ref.read(upcomingMealsProvider).value;
      List<ScheduledAlert> prep = const <ScheduledAlert>[];
      if (meals != null && meals.isNotEmpty) {
        await gateway.initialize();
        prep = PrepReminderPlanner.plan(meals, now: gateway.nowInAlertZone());
      }

      if (!settings.enabled) {
        await scheduler.refresh(
          settings: settings,
          items: const <ItemWithBatches>[],
          entries: const <ShoppingEntry>[],
          prep: prep,
          snoozes: AlertSnoozes.fromMap(stored),
          trips: ref.read(tripsProvider).value ?? const <Trip>[],
        );
        if (prep.isEmpty) {
          await work.cancelAlertRefresh();
          workRegistered = false;
        } else if (!workRegistered) {
          await work.ensureAlertRefreshRegistered();
          workRegistered = true;
        }
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
        prep: prep,
        snoozes: AlertSnoozes.fromMap(stored),
        trips: ref.read(tripsProvider).value ?? const <Trip>[],
      );
      if (!workRegistered) {
        await work.ensureAlertRefreshRegistered();
        workRegistered = true;
      }
    } on Object catch (error, stack) {
      // Alerts are a convenience: never let a failure here disturb the app.
      Diag.error('alerts', 'Could not update alerts', error: error, stack: stack);
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
  ref.listen<AlertSnoozes>(
    alertSnoozesProvider,
    (previous, next) => queue(),
  );
  // A trip that pauses alerts, or its return day, changes what is scheduled.
  ref.listen<AsyncValue<List<Trip>>>(
    tripsProvider,
    (previous, next) => queue(),
  );
  ref.listen<DateTime>(todayProvider, (previous, next) => queue());
  // Planning a meal, editing its prep reminders or cooking it changes which
  // reminders are due.
  ref.listen<AsyncValue<List<MealPlanEntry>>>(
    upcomingMealsProvider,
    (previous, next) => queue(),
  );
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

  // Buttons on an alert ("Used it", "Add to list", "Snooze 1 day") tapped
  // while the app is running: done here with the app's own repositories, so
  // its screens update at once.
  final StreamSubscription<AlertActionRequest> actions =
      gateway.actionRequests.listen((AlertActionRequest request) {
    unawaited(() async {
      try {
        final NotificationActionRunner runner = NotificationActionRunner(
          pantry: ref.read(pantryRepositoryProvider),
          shopping: ref.read(shoppingRepositoryProvider),
          settings: ref.read(settingsRepositoryProvider),
          clock: ref.read(clockProvider),
        );
        final ActionOutcome outcome = await runner.run(
          request.action,
          request.payload,
        );
        if (outcome.changed && !disposed) {
          queue();
        }
      } on Object catch (error, stack) {
        Diag.error('alerts', 'Could not run the alert button', error: error, stack: stack);
      }
    }());
  });

  ref.onDispose(() {
    disposed = true;
    pause?.cancel();
    unawaited(taps.cancel());
    unawaited(actions.cancel());
  });

  // An alert that started the app.
  unawaited(() async {
    try {
      await gateway.initialize();
      final AlertTarget? launched = await gateway.takeLaunchTarget();
      if (launched != null && !disposed) {
        ref.read(alertTargetProvider.notifier).open(launched);
      }
    } on Object catch (error, stack) {
      Diag.error('alerts', 'Could not read the launching alert', error: error, stack: stack);
    }
  }());

  queue();
});
