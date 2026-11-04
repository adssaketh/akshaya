import 'package:flutter/material.dart';

import '../domain/sync_models.dart';

/// Text safe to show for any error from the sync screens.
String syncFailureMessage(Object error) {
  if (error is AccountFailure) {
    return error.message;
  }
  return 'Something went wrong. Please try again.';
}

/// Short label for the sync indicator.
String syncPhaseLabel(SyncStatusInfo info, int pending) {
  switch (info.phase) {
    case SyncPhase.off:
      return 'Sync is off';
    case SyncPhase.idle:
      return pending > 0 ? '$pending waiting to sync' : 'Ready to sync';
    case SyncPhase.syncing:
      return 'Syncing…';
    case SyncPhase.synced:
      return 'Synced';
    case SyncPhase.offline:
      return pending > 0 ? 'Offline, $pending waiting' : 'Offline';
    case SyncPhase.error:
      return 'Sync problem, will retry';
    case SyncPhase.quotaReached:
      return 'Daily cloud limit reached, will retry later';
    case SyncPhase.removed:
      return 'No longer a member of this household';
  }
}

/// Icon for the sync indicator.
IconData syncPhaseIcon(SyncPhase phase) {
  switch (phase) {
    case SyncPhase.off:
      return Icons.cloud_off_outlined;
    case SyncPhase.idle:
      return Icons.cloud_queue_rounded;
    case SyncPhase.syncing:
      return Icons.sync_rounded;
    case SyncPhase.synced:
      return Icons.cloud_done_outlined;
    case SyncPhase.offline:
      return Icons.cloud_off_rounded;
    case SyncPhase.error:
      return Icons.error_outline_rounded;
    case SyncPhase.quotaReached:
      return Icons.hourglass_bottom_rounded;
    case SyncPhase.removed:
      return Icons.person_off_outlined;
  }
}
