import 'package:workmanager/workmanager.dart';

import '../domain/background_work.dart';
import 'alert_worker.dart';

/// [BackgroundWork] on top of WorkManager (Android).
///
/// WorkManager is not a clock: it runs the check roughly every
/// [frequency], when the system finds a good moment. The alerts themselves
/// are scheduled with the alarm system, so a late check only means slightly
/// older alert text.
class WorkmanagerBackgroundWork implements BackgroundWork {
  const WorkmanagerBackgroundWork();

  static const Duration frequency = Duration(hours: 6);

  @override
  Future<void> ensureAlertRefreshRegistered() async {
    await Workmanager().initialize(alertCallbackDispatcher);
    await Workmanager().registerPeriodicTask(
      kAlertRefreshUniqueName,
      kAlertRefreshTaskName,
      frequency: frequency,
      // Keeps the existing schedule's timing; only changes (such as a new
      // frequency in a later version) are applied.
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
    );
  }

  @override
  Future<void> cancelAlertRefresh() async {
    await Workmanager().cancelByUniqueName(kAlertRefreshUniqueName);
  }
}
