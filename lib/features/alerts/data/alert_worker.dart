import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';

import '../../count/domain/count_settings.dart';
import '../../pantry/data/database/app_database.dart';
import '../../pantry/data/database/open_database.dart';
import '../../pantry/data/drift_pantry_repository.dart';
import '../../pantry/domain/entities.dart';
import '../../planner/data/drift_meal_plan_repository.dart';
import '../../planner/domain/meal_plan_models.dart';
import '../../planner/domain/prep_schedule.dart';
import '../../settings/data/drift_settings_repository.dart';
import '../../sync/data/household_check.dart';
import '../../shopping/data/drift_shopping_repository.dart';
import '../../shopping/domain/shopping_entities.dart';
import '../domain/alert_scheduler.dart';
import '../domain/alert_settings.dart';
import '../domain/alert_snoozes.dart';
import '../domain/notification_gateway.dart';
import 'local_notification_gateway.dart';

/// Name of the periodic background check (what the task does).
const String kAlertRefreshTaskName = 'akshaya.alert_refresh';

/// Unique registration name, so the check is registered only once.
const String kAlertRefreshUniqueName = 'akshaya.alert_refresh.periodic';

/// Reads the settings, pantry and shopping lists from [db] and replaces the
/// scheduled alerts through [gateway]. Returns what was scheduled.
///
/// Shared by the background check and by tests.
Future<List<ScheduledAlert>> refreshAlertsFromDatabase(
  AppDatabase db,
  NotificationGateway gateway,
) async {
  final Map<String, String> stored = await DriftSettingsRepository(db).readAll();
  final AlertSettings settings = AlertSettings.fromMap(stored);
  final CountSettings counts = CountSettings.fromMap(stored);

  final DriftPantryRepository pantry = DriftPantryRepository(db);
  final DriftShoppingRepository shopping = DriftShoppingRepository(db, pantry);
  final List<ItemWithBatches> items = await pantry.watchItems().first;
  final List<ShoppingEntry> entries = await shopping.watchEntries().first;

  await gateway.initialize();
  // Prep reminders for planned meals are scheduled with the daily alert.
  final DateTime now = gateway.nowInAlertZone();
  final List<MealPlanEntry> meals = await DriftMealPlanRepository(db)
      .readFrom(DateTime(now.year, now.month, now.day));
  return AlertScheduler(gateway).refresh(
    settings: settings,
    items: items,
    entries: entries,
    counts: counts,
    prep: PrepReminderPlanner.plan(meals, now: now),
    snoozes: AlertSnoozes.fromMap(stored),
  );
}

/// Entry point WorkManager starts in a background isolate, with no UI.
@pragma('vm:entry-point')
void alertCallbackDispatcher() {
  Workmanager().executeTask(
    (String task, Map<String, dynamic>? inputData) async {
      if (task != kAlertRefreshTaskName) {
        return true;
      }
      final AppDatabase db = openAppDatabase();
      try {
        final LocalNotificationGateway gateway = LocalNotificationGateway();
        await refreshAlertsFromDatabase(db, gateway);
        // Household changes are a bonus: never fail the daily alerts for them.
        await checkHouseholdChanges(db, gateway);
        return true;
      } on Object catch (error) {
        debugPrint('Alert refresh failed: $error');
        // Ask WorkManager to try again later.
        return false;
      } finally {
        await db.close();
      }
    },
  );
}
