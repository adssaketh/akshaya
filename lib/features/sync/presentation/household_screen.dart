import 'package:akshaya/core/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/ui/feedback.dart';
import '../domain/invite_code.dart';
import '../domain/sync_models.dart';
import '../domain/sync_settings.dart';
import 'providers.dart';
import 'sync_ui.dart';

/// The household: invite code and QR, members, and leaving. The owner can also
/// remove members and replace the invite code.
class HouseholdScreen extends ConsumerWidget {
  const HouseholdScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SyncSettings settings = ref.watch(syncSettingsProvider);
    final SyncIdentity identity =
        ref.watch(syncIdentityProvider).value ?? SyncIdentity.none;
    final List<Member> members =
        ref.watch(householdMembersProvider).value ?? const <Member>[];
    final String? me = identity.userId;
    final bool iAmOwner = members.any(
      (Member m) => m.userId == me && m.role == MemberRole.owner,
    );
    final String? code = settings.inviteCode;
    final AkshayaColors colors = context.akColors;

    return Scaffold(
      appBar: AppBar(title: Text(settings.householdName ?? 'Household')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: <Widget>[
            if (code != null) ...<Widget>[
              const SectionHeader(title: 'Invite someone'),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Share this code, or let them scan the QR code, in '
                'Settings > Join a household.',
                style: context.akText.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: const BoxDecoration(
                    color: AkshayaColors.qrBackground,
                    borderRadius: AppRadius.controlBorder,
                  ),
                  child: QrImageView(
                    data: InviteCode.qrPayload(code),
                    size: AppSizes.qrCode,
                    backgroundColor: AkshayaColors.qrBackground,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: AkshayaColors.qrForeground,
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: AkshayaColors.qrForeground,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Center(
                child: SelectableText(
                  InviteCode.format(code),
                  style: context.akText.headlineSmall,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  TextButton.icon(
                    onPressed: () async {
                      final ScaffoldMessengerState messenger =
                          ScaffoldMessenger.of(context);
                      await Clipboard.setData(
                        ClipboardData(text: InviteCode.format(code)),
                      );
                      showMessage(messenger, 'Invite code copied');
                    },
                    icon: const Icon(Icons.copy_rounded),
                    label: const Text('Copy'),
                  ),
                  if (iAmOwner)
                    TextButton.icon(
                      onPressed: () => _newCode(context, ref),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('New code'),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            const SectionHeader(title: 'Members'),
            if (members.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Text(
                  'Members appear once you are online.',
                  style: context.akText.bodyMedium!.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ),
            for (final Member member in members)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.person_outline_rounded),
                title: Text(
                  member.userId == me
                      ? '${member.displayName} (you)'
                      : member.displayName,
                ),
                subtitle: Text(
                  member.role == MemberRole.owner ? 'Owner' : 'Member',
                ),
                trailing: iAmOwner && member.userId != me
                    ? IconButton(
                        tooltip: 'Remove ${member.displayName}',
                        icon: const Icon(Icons.person_remove_outlined),
                        onPressed: () => _remove(context, ref, member),
                      )
                    : null,
              ),
            const SizedBox(height: AppSpacing.xl),
            if (!iAmOwner)
              OutlinedButton.icon(
                onPressed: () => _leave(context, ref),
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Leave household'),
              )
            else
              Text(
                'The owner cannot leave. Remove the other members or keep '
                'the household.',
                style: context.akText.bodySmall!.copyWith(
                  color: colors.textSecondary,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<bool> _confirm(
    BuildContext context,
    String title,
    String body,
    String action,
  ) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialog) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            child: Text(action),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _newCode(BuildContext context, WidgetRef ref) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    if (!await _confirm(
      context,
      'Replace the invite code?',
      'The old code and QR code stop working. People already in the '
          'household stay.',
      'Replace',
    )) {
      return;
    }
    try {
      await ref.read(syncControllerProvider).newInviteCode();
      showMessage(messenger, 'New invite code ready');
    } on Object catch (error) {
      showMessage(messenger, syncFailureMessage(error));
    }
  }

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    Member member,
  ) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    if (!await _confirm(
      context,
      'Remove ${member.displayName}?',
      'They lose access to the shared pantry. Their own copy stays on '
          'their phone.',
      'Remove',
    )) {
      return;
    }
    try {
      await ref.read(syncControllerProvider).removeMember(member.userId);
      showMessage(messenger, '${member.displayName} was removed');
    } on Object catch (error) {
      showMessage(messenger, syncFailureMessage(error));
    }
  }

  Future<void> _leave(BuildContext context, WidgetRef ref) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final NavigatorState navigator = Navigator.of(context);
    if (!await _confirm(
      context,
      'Leave this household?',
      'Syncing stops. The pantry stays on this phone.',
      'Leave',
    )) {
      return;
    }
    try {
      await ref.read(syncControllerProvider).leaveHousehold();
      navigator.pop();
      showMessage(messenger, 'You left the household');
    } on Object catch (error) {
      showMessage(messenger, syncFailureMessage(error));
    }
  }
}
