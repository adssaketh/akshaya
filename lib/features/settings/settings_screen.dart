import 'package:akshaya/core/design/design.dart';
import 'package:flutter/material.dart';

import '../ai/presentation/ai_voice_section.dart';
import '../alerts/presentation/alerts_section.dart';
import '../commands/presentation/voice_mic_button.dart';
import '../backup/presentation/backup_section.dart';
import '../count/presentation/count_section.dart';
import '../diagnostics/presentation/diagnostics_screen.dart';
import '../guide/presentation/guide_screen.dart';
import '../rescue/presentation/freeze_rules_screen.dart';
import '../travel/presentation/travel_screen.dart';
import 'presentation/general_section.dart';
import '../sync/presentation/sync_section.dart';

/// The Settings tab: general options, alerts, AI and voice (with usage),
/// sync, backup and export.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Sections are built lazily (only the ones near the screen) and each one
    // paints into its own layer, so scrolling does not repaint the whole page.
    final List<WidgetBuilder> sections = <WidgetBuilder>[
      (BuildContext context) => ListTile(
            leading: const Icon(Icons.menu_book_rounded),
            title: const Text('User guide'),
            subtitle: const Text('How every feature works, with search'),
            onTap: () => openGuide(context),
          ),
      (BuildContext _) => const GeneralSection(),
      (BuildContext _) => const AlertsSection(),
      (BuildContext _) => const CountSection(),
      (BuildContext context) => ListTile(
            leading: const Icon(Icons.ac_unit_rounded),
            title: const Text('Freezing rules'),
            subtitle: const Text('How long frozen food keeps, by category'),
            onTap: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (BuildContext _) => const FreezeRulesScreen(),
              ),
            ),
          ),
      (BuildContext context) => ListTile(
            leading: const Icon(Icons.luggage_rounded),
            title: const Text('Travel mode'),
            subtitle: const Text('Trips, paused alerts and the back-home list'),
            onTap: () => openTravelMode(context),
          ),
      (BuildContext _) => const AiVoiceSection(),
      (BuildContext _) => const SyncSection(),
      (BuildContext _) => const BackupSection(),
      (BuildContext context) => ListTile(
            leading: const Icon(Icons.bug_report_outlined),
            title: const Text('Diagnostics'),
            subtitle: const Text('Error log and a report you can share'),
            onTap: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (BuildContext _) => const DiagnosticsScreen(),
              ),
            ),
          ),
    ];

    return SafeArea(
      bottom: false,
      child: ListView.builder(
        padding: EdgeInsets.only(bottom: context.navClearance),
        physics: const ClampingScrollPhysics(),
        addAutomaticKeepAlives: false,
        itemCount: sections.length + 1,
        itemBuilder: (BuildContext context, int index) {
          if (index == 0) {
            return const AkshayaHeader(actions: <Widget>[VoiceMicButton()]);
          }
          return RepaintBoundary(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (index > 1) const Divider(),
                sections[index - 1](context),
              ],
            ),
          );
        },
      ),
    );
  }
}
