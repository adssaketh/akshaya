import 'package:akshaya/features/ai/domain/ai_settings.dart';
import 'package:akshaya/features/ai/presentation/providers.dart';
import 'package:akshaya/features/alerts/domain/alert_settings.dart';
import 'package:akshaya/features/alerts/presentation/providers.dart';
import 'package:akshaya/features/settings/domain/app_settings.dart';
import 'package:akshaya/features/settings/presentation/providers.dart';
import 'package:akshaya/features/sync/domain/sync_settings.dart';
import 'package:akshaya/features/sync/presentation/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_settings_repository.dart';

/// Sync and AI bump usage counters in the settings table all the time. These
/// tests keep that from rebuilding the whole app (and the Settings tab, which
/// made it scroll badly) by checking that each settings provider only
/// notifies when its own values change.
void main() {
  group('value equality', () {
    test('AppSettings', () {
      expect(
        AppSettings.fromMap(const <String, String>{}),
        AppSettings.fromMap(const <String, String>{'unrelated': '1'}),
      );
      expect(
        AppSettings.fromMap(const <String, String>{
          AppSettingKeys.theme: 'dark',
        }),
        isNot(AppSettings.fromMap(const <String, String>{})),
      );
    });

    test('AiSettings and AiUsage', () {
      expect(
        AiSettings.fromMap(const <String, String>{}),
        AiSettings.fromMap(const <String, String>{'unrelated': '1'}),
      );
      expect(
        AiSettings.fromMap(const <String, String>{AiSettingKeys.dailyCap: '80'}),
        isNot(AiSettings.fromMap(const <String, String>{})),
      );
      expect(
        AiUsage.fromMap(const <String, String>{
          AiSettingKeys.usageDate: '2026-11-05',
          AiSettingKeys.usageCount: '3',
        }),
        const AiUsage(date: '2026-11-05', count: 3),
      );
      expect(const AiUsage(count: 1), isNot(const AiUsage(count: 2)));
    });

    test('SyncSettings and FirestoreUsage', () {
      expect(
        SyncSettings.fromMap(const <String, String>{}),
        SyncSettings.fromMap(const <String, String>{'unrelated': '1'}),
      );
      expect(
        SyncSettings.fromMap(const <String, String>{
          SyncSettingKeys.householdName: 'Home',
        }),
        isNot(SyncSettings.fromMap(const <String, String>{})),
      );
      expect(
        const FirestoreUsage(date: '2026-11-05', reads: 4, writes: 2),
        const FirestoreUsage(date: '2026-11-05', reads: 4, writes: 2),
      );
      expect(
        const FirestoreUsage(reads: 4),
        isNot(const FirestoreUsage(reads: 5)),
      );
    });
  });

  group('settings providers', () {
    Future<void> settle() async {
      for (int i = 0; i < 5; i++) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    test('only the provider whose values changed notifies', () async {
      final FakeSettingsRepository repo = FakeSettingsRepository();
      final ProviderContainer container = ProviderContainer(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      int app = 0;
      int alerts = 0;
      int ai = 0;
      int aiUsage = 0;
      int sync = 0;
      int firestoreUsage = 0;
      container
        ..listen<AppSettings>(appSettingsProvider, (previous, next) => app++)
        ..listen<AlertSettings>(
          alertSettingsProvider,
          (previous, next) => alerts++,
        )
        ..listen<AiSettings>(aiSettingsProvider, (previous, next) => ai++)
        ..listen<AiUsage>(aiUsageProvider, (previous, next) => aiUsage++)
        ..listen<SyncSettings>(syncSettingsProvider, (previous, next) => sync++)
        ..listen<FirestoreUsage>(
          firestoreUsageProvider,
          (previous, next) => firestoreUsage++,
        );
      await settle();

      void resetCounts() {
        app = 0;
        alerts = 0;
        ai = 0;
        aiUsage = 0;
        sync = 0;
        firestoreUsage = 0;
      }

      // Sync records Firestore use: only that provider may notice.
      resetCounts();
      await repo.writeAll(<String, String>{
        SyncSettingKeys.usageDate: '2026-11-05',
        SyncSettingKeys.usageReads: '12',
        SyncSettingKeys.usageWrites: '3',
      });
      await settle();
      expect(firestoreUsage, 1);
      expect(<int>[app, alerts, ai, aiUsage, sync], everyElement(0));

      // An AI call is counted: only the AI usage provider may notice.
      resetCounts();
      await repo.writeAll(<String, String>{
        AiSettingKeys.usageDate: '2026-11-05',
        AiSettingKeys.usageCount: '1',
      });
      await settle();
      expect(aiUsage, 1);
      expect(<int>[app, alerts, ai, sync, firestoreUsage], everyElement(0));

      // A real app setting change reaches the app, and nothing else.
      resetCounts();
      await repo.writeAll(<String, String>{AppSettingKeys.theme: 'dark'});
      await settle();
      expect(app, 1);
      expect(
        <int>[alerts, ai, aiUsage, sync, firestoreUsage],
        everyElement(0),
      );

      // A real alert setting change reaches the alerts, and nothing else.
      resetCounts();
      await repo.writeAll(<String, String>{AlertSettingKeys.enabled: 'false'});
      await settle();
      expect(alerts, 1);
      expect(<int>[app, ai, aiUsage, sync, firestoreUsage], everyElement(0));
    });
  });
}
