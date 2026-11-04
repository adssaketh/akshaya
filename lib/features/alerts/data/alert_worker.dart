import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';

import '../../pantry/data/database/app_database.dart';
import '../../pantry/data/database/open_database.dart';
import '../../pantry/data/drift_pantry_repository.dart';
import '../../pantry/domain/entities.dart';
import '../../settings/data/drift_settings_repository.dart';
import '../../shopping/data/drift_shopping_repository.dart';
import '../../shopping/domain/shopping_entities.dart';
import '../domain/alert_scheduler.dart';
import '../domain/alert_settings.dart';
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

  final DriftPantryRepository pantry = DriftPantryRepository(db);
  final DriftShoppingRepository shopping = DriftShoppingRepository(db, pantry);
  final List<ItemWithBatches> items = await pantry.watchItems().first;
  final List<ShoppingEntry> entries = await shopping.watchEntries().first;

  await gateway.initialize();
  return AlertScheduler(gateway).refresh(
    settings: settings,
    items: items,
    entries: entries,
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
        await refreshAlertsFromDatabase(db, LocalNotificationGateway());
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
