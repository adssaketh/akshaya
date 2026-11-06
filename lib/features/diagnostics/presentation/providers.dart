import 'package:drift/drift.dart' show QueryRow;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/diagnostics/diag.dart';
import '../../../core/diagnostics/diag_log.dart';
import '../../ai/domain/ai_settings.dart';
import '../../ai/presentation/providers.dart';
import '../../alerts/domain/alert_settings.dart';
import '../../alerts/presentation/providers.dart';
import '../../pantry/data/database/app_database.dart';
import '../../pantry/presentation/providers.dart' show appDatabaseProvider;
import '../../sync/domain/sync_models.dart';
import '../../sync/presentation/providers.dart';

/// The app-wide diagnostics log. Tests override it with their own.
final Provider<DiagLog> diagLogProvider = Provider<DiagLog>((Ref ref) {
  return Diag.log;
});

class _Counted {
  const _Counted(this.label, this.table);

  final String label;
  final String table;
}

const List<_Counted> _countedTables = <_Counted>[
  _Counted('Items', 'items'),
  _Counted('Stock batches', 'stock_batches'),
  _Counted('Usage history', 'consumption_logs'),
  _Counted('Shopping entries', 'shopping_entries'),
  _Counted('Saved recipes', 'saved_recipes'),
  _Counted('Planned meals', 'meal_plan_entries'),
  _Counted('Trips', 'trips'),
];

/// What the app is holding and how its helpers are doing, as label and value
/// pairs. Counts and switches only: no names, no e-mail, no item text.
final FutureProvider<List<MapEntry<String, String>>> diagStateProvider =
    FutureProvider.autoDispose<List<MapEntry<String, String>>>((Ref ref) async {
  // Everything watched is read before the first await.
  final AppDatabase db = ref.watch(appDatabaseProvider);
  final bool? notifications = ref.watch(notificationsAllowedProvider).value;
  final AlertSettings alerts = ref.watch(alertSettingsProvider);
  final AiSettings ai = ref.watch(aiSettingsProvider);
  final AiUsage usage = ref.watch(aiUsageProvider);
  final SyncStatusInfo? sync = ref.watch(syncStatusProvider).value;

  final List<MapEntry<String, String>> rows = <MapEntry<String, String>>[
    MapEntry<String, String>('Database version', '${db.schemaVersion}'),
  ];
  for (final _Counted table in _countedTables) {
    String value;
    try {
      final int count = await db
          .customSelect(
            'SELECT COUNT(*) AS n FROM ${table.table} WHERE is_deleted = 0',
          )
          .map((QueryRow row) => row.read<int>('n'))
          .getSingle();
      value = '$count';
    } on Object catch (error) {
      Diag.warn('diagnostics', 'Could not count ${table.table}', error: error);
      value = 'unreadable';
    }
    rows.add(MapEntry<String, String>(table.label, value));
  }

  rows
    ..add(
      MapEntry<String, String>(
        'Notifications allowed',
        notifications == null ? 'unknown' : (notifications ? 'yes' : 'no'),
      ),
    )
    ..add(
      MapEntry<String, String>('Daily alert', alerts.enabled ? 'on' : 'off'),
    )
    ..add(
      MapEntry<String, String>(
        'AI',
        '${ai.enabled ? 'on' : 'off'}, notice '
            '${ai.noticeAccepted ? 'accepted' : 'not accepted'}, '
            '${usage.count} calls on ${usage.date ?? 'no day yet'} '
            '(limit ${ai.dailyCap})',
      ),
    )
    ..add(
      MapEntry<String, String>(
        'Sync',
        sync == null
            ? 'unknown'
            : '${sync.phase.name}, ${sync.pending} waiting to send',
      ),
    );
  return rows;
});
