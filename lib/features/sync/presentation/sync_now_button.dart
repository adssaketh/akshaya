import 'dart:async';

import 'package:akshaya/core/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/feedback.dart';
import '../../ai/data/firebase_runtime.dart';
import '../domain/sync_models.dart';
import '../domain/sync_settings.dart';
import 'providers.dart';
import 'sync_ui.dart';

/// A round button that shows the sync state and runs "Sync now" when tapped.
///
/// When sync cannot run (no Firebase in this build, not signed in, no
/// household, or switched off) the tap explains why and calls
/// [onNeedsSetup], so the Settings screen can bring up the Household & sync
/// block where it is fixed.
class SyncNowButton extends ConsumerWidget {
  const SyncNowButton({super.key, this.onNeedsSetup});

  final VoidCallback? onNeedsSetup;

  void _explain(BuildContext context, String message) {
    showMessage(ScaffoldMessenger.of(context), message);
    onNeedsSetup?.call();
  }

  Future<void> _syncNow(BuildContext context, WidgetRef ref) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(syncControllerProvider).syncNow();
    } on Object catch (error) {
      showMessage(messenger, syncFailureMessage(error));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AkshayaColors colors = context.akColors;
    final SyncSettings settings = ref.watch(syncSettingsProvider);
    final SyncIdentity identity =
        ref.watch(syncIdentityProvider).value ?? SyncIdentity.none;
    final SyncStatusInfo status =
        ref.watch(syncStatusProvider).value ?? const SyncStatusInfo();
    final int pending = ref.watch(pendingCountProvider).value ?? 0;

    final String tooltip;
    final Widget icon;
    final VoidCallback onPressed;

    if (!FirebaseBuildConfig.isConfigured) {
      tooltip = 'Sync is not set up in this build';
      icon = const Icon(Icons.cloud_off_outlined);
      onPressed = () => _explain(
            context,
            'Sync is not set up in this build. Everything works on this phone.',
          );
    } else if (!identity.isActive) {
      tooltip = 'Sign in to sync';
      icon = const Icon(Icons.cloud_off_outlined);
      onPressed = () => _explain(
            context,
            'Sign in and join a household to sync. It is optional.',
          );
    } else if (!settings.enabled) {
      tooltip = 'Sync is switched off';
      icon = const Icon(Icons.sync_disabled_rounded);
      onPressed = () => _explain(
            context,
            'Sync is switched off. Turn it on under Household & sync.',
          );
    } else {
      final bool syncing = status.phase == SyncPhase.syncing;
      final bool problem = status.phase == SyncPhase.error ||
          status.phase == SyncPhase.quotaReached ||
          status.phase == SyncPhase.removed;
      tooltip = '${syncPhaseLabel(status, pending)}. Tap to sync now.';
      icon = syncing
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            )
          : Badge(
              isLabelVisible: pending > 0,
              label: Text('$pending'),
              child: Icon(
                syncPhaseIcon(status.phase),
                color: problem ? colors.expired.foreground : null,
              ),
            );
      onPressed = () {
        if (syncing) {
          return;
        }
        showMessage(ScaffoldMessenger.of(context), 'Syncing…');
        unawaited(_syncNow(context, ref));
      };
    }

    return Semantics(
      label: tooltip,
      button: true,
      excludeSemantics: true,
      child: IconButton.filledTonal(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: icon,
      ),
    );
  }
}
