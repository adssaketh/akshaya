import 'package:akshaya/core/design/design.dart';
import 'package:akshaya/core/design/gallery/design_gallery_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ui/feedback.dart';
import '../ai/presentation/ai_voice_section.dart';
import '../alerts/presentation/alerts_section.dart';
import '../commands/presentation/voice_mic_button.dart';
import '../backup/presentation/backup_section.dart';
import '../count/presentation/count_section.dart';
import '../pantry/presentation/providers.dart';
import '../rescue/presentation/freeze_rules_screen.dart';
import 'presentation/general_section.dart';
import '../sync/presentation/sync_section.dart';

/// The Settings tab: general options, alerts, AI and voice (with usage),
/// sync, backup and export, sample data and the design gallery.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: ListView(
        children: <Widget>[
          const AkshayaHeader(actions: <Widget>[VoiceMicButton()]),
          const GeneralSection(),
          const Divider(),
          const AlertsSection(),
          const Divider(),
          const CountSection(),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.ac_unit_rounded),
            title: const Text('Freezing rules'),
            subtitle: const Text('How long frozen food keeps, by category'),
            onTap: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (BuildContext _) => const FreezeRulesScreen(),
              ),
            ),
          ),
          const Divider(),
          const AiVoiceSection(),
          const Divider(),
          const SyncSection(),
          const Divider(),
          const BackupSection(),
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
        ],
      ),
    );
  }
}
