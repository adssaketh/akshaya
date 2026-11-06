import 'package:flutter/widgets.dart';
import 'package:home_widget/home_widget.dart';

import '../../../core/diagnostics/diag.dart';
import '../../alerts/domain/alert_settings.dart';
import '../../pantry/data/database/app_database.dart';
import '../../pantry/data/database/open_database.dart';
import '../../pantry/data/drift_pantry_repository.dart';
import '../../pantry/domain/entities.dart';
import '../../pantry/domain/stock_logic.dart';
import '../../rescue/domain/food_rescue.dart';
import '../../rescue/domain/freeze_rules.dart';
import '../../settings/data/drift_settings_repository.dart';
import '../../shopping/data/drift_shopping_repository.dart';
import '../../shopping/domain/shopping_entities.dart';
import '../../travel/data/drift_trip_repository.dart';
import '../../travel/domain/trip_models.dart';
import '../domain/widget_snapshot.dart';
import 'home_widget_gateway.dart';

/// Works out the widget contents from [db] (used when the app is not open).
Future<WidgetSnapshot> snapshotFromDatabase(
  AppDatabase db, {
  DateTime? now,
}) async {
  final DateTime today = now ?? DateTime.now();
  final Map<String, String> stored = await DriftSettingsRepository(db).readAll();
  final AlertSettings alerts = AlertSettings.fromMap(stored);
  final DriftPantryRepository pantry = DriftPantryRepository(db);
  final DriftShoppingRepository shopping = DriftShoppingRepository(db, pantry);
  final List<ItemWithBatches> items = await pantry.watchItems().first;
  final List<ItemStock> stocks = <ItemStock>[
    for (final ItemWithBatches record in items)
      StockLogic.summarize(
        record,
        today: today,
        warningDays: alerts.warningDays,
      ),
  ];
  final List<ShoppingEntry> entries = await shopping.watchEntries().first;
  final List<Trip> trips = await DriftTripRepository(db).readAll();
  return WidgetSnapshots.build(
    rescue: FoodRescue.build(
      stocks: stocks,
      today: today,
      warningDays: alerts.warningDays,
      freeze: FreezeSettings.fromMap(stored),
    ),
    entries: entries,
    today: today,
    pausedUntil: TripSchedule.recurringResumeOn(today, trips),
  );
}

/// Refreshes the widgets from the database (used by the background check).
Future<void> refreshWidgetsFromDatabase(AppDatabase db) async {
  await const HomeWidgetGateway().publish(await snapshotFromDatabase(db));
}

/// Runs when a row of the shopping widget is tapped, with no app open:
/// toggles that entry, then redraws the widgets.
@pragma('vm:entry-point')
Future<void> widgetBackgroundCallback(Uri? uri) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (uri == null || uri.scheme != 'akshaya' || uri.host != 'check') {
    return;
  }
  final String? id = uri.queryParameters['id'];
  if (id == null || id.isEmpty) {
    return;
  }
  await Diag.init();
  Diag.info('widgets', 'Shopping widget row tapped');
  final AppDatabase db = openAppDatabase();
  try {
    final DriftPantryRepository pantry = DriftPantryRepository(db);
    final DriftShoppingRepository shopping =
        DriftShoppingRepository(db, pantry);
    final List<ShoppingEntry> entries = await shopping.watchEntries().first;
    for (final ShoppingEntry entry in entries) {
      if (entry.id == id) {
        await shopping.setChecked(id, checked: !entry.isChecked);
        break;
      }
    }
    await refreshWidgetsFromDatabase(db);
  } on Object catch (error, stack) {
    Diag.error('widgets', 'Widget tap failed', error: error, stack: stack);
  } finally {
    await db.close();
  }
}

/// Registers [widgetBackgroundCallback] with the plugin. Safe to call often.
Future<void> registerWidgetBackgroundCallback() async {
  try {
    await HomeWidget.registerInteractivityCallback(widgetBackgroundCallback);
  } on Object catch (error, stack) {
    Diag.error('widgets', 'Could not register the widget callback', error: error, stack: stack);
  }
}
