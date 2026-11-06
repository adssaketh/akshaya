import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../../core/diagnostics/diag.dart';
import '../../pantry/data/database/app_database.dart';
import '../../pantry/data/database/open_database.dart';
import '../../pantry/data/drift_pantry_repository.dart';
import '../../settings/data/drift_settings_repository.dart';
import '../../shopping/data/drift_shopping_repository.dart';
import '../domain/alert_action.dart';
import '../domain/alert_plan.dart';
import '../domain/notification_action_runner.dart';
import 'alert_worker.dart';
import 'local_notification_gateway.dart';

/// Runs in a background isolate when a notification button that does not open
/// the app ("Used it", "Add to list", "Snooze 1 day") is tapped while the app
/// is not running. It must be a top-level function.
///
/// It opens its own database connection, does what the button says, and then
/// re-plans the scheduled alerts so the change shows in the next ones. Any
/// failure is only logged: a button must never crash anything.
@pragma('vm:entry-point')
Future<void> akshayaNotificationBackgroundHandler(
  NotificationResponse response,
) async {
  DartPluginRegistrant.ensureInitialized();
  final AlertAction? action = AlertAction.fromId(response.actionId);
  final AlertPayload? payload = AlertPayload.parse(response.payload);
  if (action == null || action.opensApp || payload == null) {
    return;
  }
  await Diag.init();
  Diag.info('alerts', 'Notification button ${action.name} (app closed)');

  final AppDatabase db = openAppDatabase();
  try {
    final DriftPantryRepository pantry = DriftPantryRepository(db);
    final NotificationActionRunner runner = NotificationActionRunner(
      pantry: pantry,
      shopping: DriftShoppingRepository(db, pantry),
      settings: DriftSettingsRepository(db),
      clock: DateTime.now,
    );
    final ActionOutcome outcome = await runner.run(action, payload);
    if (outcome.changed) {
      await refreshAlertsFromDatabase(db, LocalNotificationGateway());
    }
  } on Object catch (error, stack) {
    Diag.error('alerts', 'Notification button failed', error: error, stack: stack);
  } finally {
    await db.close();
  }
}
