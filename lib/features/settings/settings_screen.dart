import 'package:akshaya/core/design/design.dart';
import 'package:akshaya/core/design/gallery/design_gallery_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ui/feedback.dart';
import '../ai/presentation/ai_voice_section.dart';
import '../alerts/presentation/alerts_section.dart';
import '../commands/presentation/voice_mic_button.dart';
import '../pantry/presentation/providers.dart';
import '../sync/presentation/sync_section.dart';

/// Temporary Settings tab: the daily alert settings (Phase 4), sample data and
/// the design gallery. The full settings (theme, AI, usage and so on) arrive
/// in Phase 8.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: ListView(
        children: <Widget>[
          const AkshayaHeader(actions: <Widget>[VoiceMicButton()]),
          const AlertsSection(),
          const Divider(),
          const AiVoiceSection(),
          const Divider(),
          const SyncSection(),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.science_outlined),
            title: const Text('Load sample data'),
            subtitle: const Text('Adds 10 common Indian grocery items'),
            onTap: () async {
              final ScaffoldMessengerState messenger =
                  ScaffoldMessenger.of(context);
              try {
                final int added =
                    await ref.read(pantryRepositoryProvider).insertSampleData();
                showMessage(
                  messenger,
                  added == 0
                      ? 'Sample items are already in your pantry'
                      : 'Added $added sample items',
                );
              } on Object catch (error) {
                showMessage(messenger, failureMessage(error));
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('Design gallery'),
            subtitle: const Text('Tokens and shared widgets'),
            onTap: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (BuildContext _) => const DesignGalleryPage(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(
              'More settings arrive in Phase 8.',
              style: context.akText.bodySmall!.copyWith(
                color: context.akColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
