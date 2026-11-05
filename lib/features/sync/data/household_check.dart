import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../ai/data/firebase_runtime.dart';
import '../../alerts/domain/alert_plan.dart';
import '../../alerts/domain/alert_settings.dart';
import '../../alerts/domain/notification_gateway.dart';
import '../../pantry/data/database/app_database.dart';
import '../../settings/data/drift_settings_repository.dart';
import '../domain/change_digest.dart';
import '../domain/sync_models.dart';
import '../domain/sync_remote.dart';
import '../domain/sync_settings.dart';
import 'firestore_sync_remote.dart';
import 'sync_store.dart';

/// Notification ids; the foreground sync uses the same ones so a newer alert
/// replaces an older one.
const int kHouseholdShoppingAlertId = 4301;
const int kHouseholdPantryAlertId = 4302;

/// Background check for changes other members made (no listeners, one small
/// query per collection). It only looks and notifies: nothing is written to
/// the pantry, and only the "already alerted" cursor moves, so the app still
/// downloads everything normally the next time it opens and never alerts
/// twice for the same change.
///
/// Without local state it cannot tell a new document from an edited one, so a
/// document another member edited counts as an addition. Failures (offline,
/// quota, signed out) are ignored; the next check tries again.
///
/// Returns the number of notifications shown.
Future<int> checkHouseholdChanges(
  AppDatabase db,
  NotificationGateway gateway, {
  SyncRemote? remote,
  DateTime Function()? clock,
}) async {
  final SyncStore store = SyncStore(db, clock: clock);
  final SyncIdentity identity = await store.identity();
  final String? household = identity.householdId;
  final String? me = identity.userId;
  if (household == null || me == null) {
    return 0;
  }
  final Map<String, String> settings =
      await DriftSettingsRepository(db).readAll();
  if (!SyncSettings.fromMap(settings).enabled) {
    return 0;
  }
  final AlertSettings alertSettings = AlertSettings.fromMap(settings);
  if (!alertSettings.household) {
    return 0;
  }
  final int alerted = await store.cursor(SyncStore.alertKey);
  if (alerted <= 0) {
    // Never synced on this phone, so everything would look new.
    return 0;
  }

  try {
    final SyncRemote source = remote ?? await _firestore();
    final List<RemoteChange> changes = <RemoteChange>[];
    int newest = alerted;
    for (final String collection in const <String>['entries', 'batches']) {
      final List<RemoteDoc> docs =
          await source.fetchSince(household, collection, alerted, limit: 100);
      for (final RemoteDoc doc in docs) {
        newest = math.max(newest, doc.syncedAtMillis);
        final Object? author = doc.data['updatedBy'];
        if (author is! String || author == me) {
          continue;
        }
        final bool removed = doc.data['isDeleted'] == true;
        final Object? listId = doc.data['listId'];
        changes.add(
          RemoteChange(
            collection: collection,
            userId: author,
            removed: removed,
            listName: listId is String ? await store.listName(listId) : null,
          ),
        );
      }
    }
    if (changes.isEmpty) {
      if (newest > alerted) {
        await store.advanceCursor(SyncStore.alertKey, newest);
      }
      return 0;
    }

    final Map<String, String> names = await store.memberNames();
    final List<String> shopping = ChangeDigest.shoppingLines(changes, names);
    final List<String> pantry = ChangeDigest.pantryLines(changes, names);
    final List<AlertNotification> alerts = <AlertNotification>[
      if (shopping.isNotEmpty)
        AlertNotification(
          id: kHouseholdShoppingAlertId,
          target: AlertTarget.householdShopping,
          channel: AlertChannelKind.household,
          title:
              shopping.length == 1 ? shopping.first : 'Shopping list updated',
          body: shopping.join('\n'),
        ),
      if (pantry.isNotEmpty)
        AlertNotification(
          id: kHouseholdPantryAlertId,
          target: AlertTarget.householdPantry,
          channel: AlertChannelKind.household,
          title: pantry.length == 1 ? pantry.first : 'Pantry updated',
          body: pantry.join('\n'),
        ),
    ];
    if (alerts.isNotEmpty) {
      await gateway.initialize();
      final DateTime now = gateway.nowInAlertZone();
      final bool quiet = alertSettings.quietEnabled &&
          alertSettings.isQuiet(now.hour * 60 + now.minute);
      // In quiet hours the cursor still moves: those changes are not alerted
      // later, they are simply there when the app opens.
      if (!quiet) {
        await gateway.showNow(alerts);
      }
    }
    await store.advanceCursor(SyncStore.alertKey, newest);
    return alerts.length;
  } on Object catch (error) {
    debugPrint('Household change check skipped: $error');
    return 0;
  }
}

Future<SyncRemote> _firestore() async {
  final FirebaseRuntime runtime = FirebaseRuntime();
  await runtime.ensureReady();
  return FirestoreSyncRemote(runtime);
}
