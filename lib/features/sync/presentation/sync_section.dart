import 'package:akshaya/core/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/feedback.dart';
import '../../ai/data/firebase_runtime.dart';
import '../domain/sync_models.dart';
import '../domain/sync_settings.dart';
import 'household_screen.dart';
import 'household_setup_screen.dart';
import 'providers.dart';
import 'sync_flow.dart';
import 'sync_ui.dart';

/// The "Household & sync" block of the Settings tab.
class SyncSection extends ConsumerWidget {
  const SyncSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SyncSettings settings = ref.watch(syncSettingsProvider);
    final SyncIdentity identity =
        ref.watch(syncIdentityProvider).value ?? SyncIdentity.none;
    final AkshayaColors colors = context.akColors;

    final List<Widget> body;
    if (!FirebaseBuildConfig.isConfigured) {
      body = <Widget>[
        ListTile(
          leading: const Icon(Icons.cloud_off_outlined),
          title: const Text('Sync is not set up in this build'),
          subtitle: const Text(
            'Everything works on this phone. See the README to add Firebase.',
          ),
        ),
      ];
    } else if (identity.userId == null && settings.userName == null) {
      body = <Widget>[
        ListTile(
          leading: const Icon(Icons.account_circle_outlined),
          title: const Text('Sign in to share with your household'),
          subtitle: const Text('Optional. The app works fully without it.'),
          onTap: () => startSignInFlow(context, ref),
        ),
      ];
    } else if (!identity.isActive) {
      body = <Widget>[
        ListTile(
          leading: const Icon(Icons.account_circle_outlined),
          title: Text(settings.userName ?? settings.userEmail ?? 'Signed in'),
          subtitle: const Text('Not in a household yet'),
        ),
        ListTile(
          leading: const Icon(Icons.group_add_outlined),
          title: const Text('Create or join a household'),
          onTap: () => _openSetup(context, ref),
        ),
        _signOutTile(context, ref),
      ];
    } else {
      final SyncStatusInfo status =
          ref.watch(syncStatusProvider).value ?? const SyncStatusInfo();
      final int pending = ref.watch(pendingCountProvider).value ?? 0;
      final FirestoreUsage usage = ref.watch(firestoreUsageProvider);
      body = <Widget>[
        ListTile(
          leading: const Icon(Icons.home_outlined),
          title: Text(settings.householdName ?? 'Household'),
          subtitle: Text(
            settings.userName ?? settings.userEmail ?? 'Signed in',
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (BuildContext _) => const HouseholdScreen(),
            ),
          ),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.sync_rounded),
          title: const Text('Sync with household'),
          value: settings.enabled,
          onChanged: (bool v) =>
              ref.read(syncControllerProvider).setEnabled(v),
        ),
        ListTile(
          leading: Icon(syncPhaseIcon(status.phase)),
          title: Text(syncPhaseLabel(status, pending)),
          subtitle: Text(
            status.message ??
                'Today on this phone: about ${usage.reads} reads, '
                    '${usage.writes} writes',
          ),
          trailing: TextButton(
            onPressed: settings.enabled
                ? () => ref.read(syncControllerProvider).syncNow()
                : null,
            child: const Text('Sync now'),
          ),
        ),
        if (status.phase == SyncPhase.removed)
          ListTile(
            leading: Icon(Icons.info_outline_rounded, color: colors.accent),
            title: const Text('Your pantry stays on this phone'),
            subtitle: const Text('Create or join a household to share again.'),
            onTap: () => _openSetup(context, ref),
          ),
        _signOutTile(context, ref),
      ];
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            0,
          ),
          child: SectionHeader(title: 'Household & sync'),
        ),
        ...body,
      ],
    );
  }

  Future<void> _openSetup(BuildContext context, WidgetRef ref) async {
    final AuthUser? user = await ref.read(syncControllerProvider).currentUser();
    if (!context.mounted) {
      return;
    }
    if (user == null) {
      await startSignInFlow(context, ref);
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext _) => HouseholdSetupScreen(user: user),
      ),
    );
  }

  Widget _signOutTile(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: const Icon(Icons.logout_rounded),
      title: const Text('Sign out'),
      onTap: () => _signOut(context, ref),
    );
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final bool? clear = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialog) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'Syncing stops. Keep the pantry on this phone, or clear it?',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            child: const Text('Clear data'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: const Text('Keep data'),
          ),
        ],
      ),
    );
    if (clear == null) {
      return;
    }
    try {
      await ref.read(syncControllerProvider).signOut(clearData: clear);
      showMessage(messenger, 'Signed out');
    } on Object catch (error) {
      showMessage(messenger, syncFailureMessage(error));
    }
  }
}
