import 'package:akshaya/core/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/feedback.dart';
import '../domain/invite_code.dart';
import '../domain/sync_models.dart';
import 'providers.dart';
import 'qr_join_screen.dart';
import 'sync_flow.dart';
import 'sync_ui.dart';

/// Create a household, or join one with an invite code or QR code.
class HouseholdSetupScreen extends ConsumerStatefulWidget {
  const HouseholdSetupScreen({required this.user, super.key});

  final AuthUser user;

  @override
  ConsumerState<HouseholdSetupScreen> createState() =>
      _HouseholdSetupScreenState();
}

class _HouseholdSetupScreenState extends ConsumerState<HouseholdSetupScreen> {
  final TextEditingController _name = TextEditingController(text: 'Our home');
  final TextEditingController _code = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final NavigatorState navigator = Navigator.of(context);
    final String name = _name.text.trim();
    if (name.isEmpty) {
      showMessage(messenger, 'Give the household a name.');
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(syncControllerProvider).createHousehold(widget.user, name);
      if (mounted) {
        navigator.pop();
        showMessage(messenger, 'Household created. Share the invite code.');
      }
    } on Object catch (error) {
      showMessage(messenger, syncFailureMessage(error));
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _join([String? scanned]) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final NavigatorState navigator = Navigator.of(context);
    final SyncController controller = ref.read(syncControllerProvider);
    final String raw = scanned ?? _code.text;
    if (InviteCode.normalize(raw) == null) {
      showMessage(messenger, 'Enter the 8-character invite code.');
      return;
    }
    setState(() => _busy = true);
    try {
      bool keep = true;
      if (await controller.hasLocalData()) {
        if (!mounted) {
          return;
        }
        final LocalDataChoice? choice =
            await askAboutLocalData(context, 'the household');
        if (choice == null) {
          if (mounted) {
            setState(() => _busy = false);
          }
          return;
        }
        keep = choice == LocalDataChoice.upload;
      }
      final HouseholdInfo info = await controller.joinHousehold(
        widget.user,
        raw,
        keepLocalData: keep,
      );
      if (mounted) {
        navigator.pop();
        showMessage(messenger, 'Joined "${info.name}".');
      }
    } on Object catch (error) {
      showMessage(messenger, syncFailureMessage(error));
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _scan() async {
    final String? code = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (BuildContext _) => const QrJoinScreen(),
      ),
    );
    if (code != null && mounted) {
      _code.text = InviteCode.format(code);
      await _join(code);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AkshayaColors colors = context.akColors;
    return Scaffold(
      appBar: AppBar(title: const Text('Household')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: <Widget>[
            Text(
              'A household shares one pantry and shopping lists. Everyone '
              'in it sees the same items.',
              style: context.akText.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.xl),
            const SectionHeader(title: 'Start a household'),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Household name'),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: _busy ? null : _create,
              child: const Text('Create household'),
            ),
            const SizedBox(height: AppSpacing.xl),
            const SectionHeader(title: 'Join one'),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _code,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Invite code',
                hintText: 'ABCD-2345',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: <Widget>[
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: _busy ? null : _join,
                    child: const Text('Join'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _scan,
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                    label: const Text('Scan QR'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'You can skip this and use the app on your own.',
              style: context.akText.bodySmall!.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
