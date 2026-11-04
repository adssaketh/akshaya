import 'package:akshaya/features/alerts/data/alert_worker.dart';
import 'package:akshaya/features/alerts/domain/alert_settings.dart';
import 'package:akshaya/features/alerts/domain/notification_gateway.dart';
import 'package:akshaya/features/pantry/data/database/app_database.dart';
import 'package:akshaya/features/pantry/data/drift_pantry_repository.dart';
import 'package:akshaya/features/pantry/domain/entities.dart';
import 'package:akshaya/features/pantry/domain/storage_location.dart';
import 'package:akshaya/features/pantry/domain/unit.dart';
import 'package:akshaya/features/settings/data/drift_settings_repository.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fake_notification_gateway.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late FakeNotificationGateway gateway;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    gateway = FakeNotificationGateway(now: DateTime(2026, 11, 4, 18, 30));

    final DriftPantryRepository pantry = DriftPantryRepository(
      db,
      clock: () => DateTime(2026, 11, 4, 10),
    );
    final Item curd = await pantry.addItem(
      const ItemDraft(
        name: 'Curd',
        categoryId: 'cat_dairy',
        defaultUnit: Unit.kg,
      ),
    );
    await pantry.addBatch(
      BatchDraft(
        itemId: curd.id,
        quantityBought: 1,
        unit: Unit.kg,
        purchaseDate: DateTime(2026, 11, 1),
        expiryDate: DateTime(2026, 11, 5),
        storageLocation: StorageLocation.fridge,
      ),
    );
  });

  tearDown(() => db.close());

  test('plans alerts from the stored pantry and the default settings',
      () async {
    final List<ScheduledAlert> scheduled =
        await refreshAlertsFromDatabase(db, gateway);

    expect(gateway.initializeCalls, greaterThan(0));
    expect(scheduled, hasLength(3));
    // 5 Nov: the curd's date.
    expect(
      scheduled.first.notifications.single.title,
      '1 item expires today',
    );
  });

  test('follows the stored settings', () async {
    await DriftSettingsRepository(db).writeAll(
      const AlertSettings(minutesOfDay: 21 * 60, warningDays: 5).toMap(),
    );
    final List<ScheduledAlert> scheduled =
        await refreshAlertsFromDatabase(db, gateway);
    // 21:00 on 4 Nov is still ahead of 18:30.
    expect(scheduled.first.fireAt, DateTime.utc(2026, 11, 4, 21));
  });

  test('schedules nothing when the alert is switched off', () async {
    await DriftSettingsRepository(db).writeAll(
      const AlertSettings(enabled: false).toMap(),
    );
    final List<ScheduledAlert> scheduled =
        await refreshAlertsFromDatabase(db, gateway);
    expect(scheduled, isEmpty);
    expect(gateway.cancelCalls, 1);
    expect(gateway.replaceCalls, 0);
  });
}
