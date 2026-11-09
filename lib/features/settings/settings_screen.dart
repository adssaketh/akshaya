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
import 'presentation/device_options_section.dart';
import 'presentation/general_section.dart';
import 'presentation/settings_index.dart';
import '../sync/presentation/sync_now_button.dart';
import '../sync/presentation/sync_section.dart';

/// What the Sync button puts in the Settings search when sync cannot run:
/// it brings up only the Household & sync block, which is where signing in
/// and switching sync on live.
const String kHouseholdSearch = 'household sync';

/// Every block of the Settings tab, in order, with the words that find it.
List<SettingsEntry> buildSettingsEntries() {
  return <SettingsEntry>[
    SettingsEntry(
      id: 'guide',
      title: 'User guide',
      keywords: 'help how to manual faq features search learn',
      builder: (BuildContext context) => ListTile(
        leading: const Icon(Icons.menu_book_rounded),
        title: const Text('User guide'),
        subtitle: const Text('How every feature works, with search'),
        onTap: () => openGuide(context),
      ),
    ),
    SettingsEntry(
      id: 'general',
      title: 'General',
      keywords: 'currency rupee symbol default unit diet recipe preferences '
          'veg cuisine allergies categories icons storage locations fridge '
          'freezer animations motion wallpaper colours colors theme dark '
          'light system app lock fingerprint face biometric screen lock '
          'insights spending waste navigation bar style glass solid blur '
          'scroll edge fade',
      builder: (BuildContext _) => const GeneralSection(),
    ),
    SettingsEntry(
      id: 'alerts',
      title: 'Alerts',
      keywords: 'notifications daily alert time expiring soon expired low '
          'stock meal prep reminders household changes quiet hours preview '
          'sound permission',
      builder: (BuildContext _) => const AlertsSection(),
    ),
    SettingsEntry(
      id: 'device',
      title: 'Overlay and mic sounds',
      keywords: 'display over other apps overlay floating card popup '
          'alert permission microphone mic beep sound mute start end '
          'listening silence',
      builder: (BuildContext _) => const DeviceOptionsSection(),
    ),
    SettingsEntry(
      id: 'count',
      title: 'Count mode',
      keywords: 'count the shelf stocktake inventory monthly reminder '
          'reconcile check stock',
      builder: (BuildContext _) => const CountSection(),
    ),
    SettingsEntry(
      id: 'freezing',
      title: 'Freezing rules',
      keywords: 'freeze freezer frozen how long keeps category days',
      builder: (BuildContext context) => ListTile(
        leading: const Icon(Icons.ac_unit_rounded),
        title: const Text('Freezing rules'),
        subtitle: const Text('How long frozen food keeps, by category'),
        onTap: () => Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (BuildContext _) => const FreezeRulesScreen(),
          ),
        ),
      ),
    ),
    SettingsEntry(
      id: 'travel',
      title: 'Travel mode',
      keywords: 'trips trip holiday vacation away paused alerts back home '
          'list',
      builder: (BuildContext context) => ListTile(
        leading: const Icon(Icons.luggage_rounded),
        title: const Text('Travel mode'),
        subtitle: const Text('Trips, paused alerts and the back-home list'),
        onTap: () => openTravelMode(context),
      ),
    ),
    SettingsEntry(
      id: 'ai',
      title: 'AI and voice',
      keywords: 'gemini artificial intelligence voice language speech '
          'telugu hindi english daily limit calls usage offline mode '
          'privacy microphone',
      builder: (BuildContext _) => const AiVoiceSection(),
    ),
    SettingsEntry(
      id: 'sync',
      title: 'Household & sync',
      keywords: '$kHouseholdSearch sync sign in sign out account google '
          'email share family invite code qr members cloud firestore '
          'offline',
      builder: (BuildContext _) => const SyncSection(),
    ),
    SettingsEntry(
      id: 'backup',
      title: 'Backup and export',
      keywords: 'backup restore export import csv json file save data '
          'spreadsheet history',
      builder: (BuildContext _) => const BackupSection(),
    ),
    SettingsEntry(
      id: 'diagnostics',
      title: 'Diagnostics',
      keywords: 'error log report debug problem bug share logs',
      builder: (BuildContext context) => ListTile(
        leading: const Icon(Icons.bug_report_outlined),
        title: const Text('Diagnostics'),
        subtitle: const Text('Error log and a report you can share'),
        onTap: () => Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (BuildContext _) => const DiagnosticsScreen(),
          ),
        ),
      ),
    ),
  ];
}

/// The Settings tab: a pinned bar with search and the Sync button, then
/// general options, alerts, AI and voice, sync, backup and export.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _search = TextEditingController();
  final List<SettingsEntry> _entries = buildSettingsEntries();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _setQuery(String value) {
    setState(() => _query = value);
  }

  /// Shows only the Household & sync block (where sign-in and the sync switch
  /// are).
  void _showHousehold() {
    _search.text = kHouseholdSearch;
    _setQuery(kHouseholdSearch);
  }

  void _clearSearch() {
    _search.clear();
    _setQuery('');
  }

  @override
  Widget build(BuildContext context) {
    // Blocks are built lazily (only the ones near the screen) and each one
    // paints into its own layer, so scrolling does not repaint the whole page.
    final List<SettingsEntry> shown = filterSettingsEntries(_entries, _query);

    return SafeArea(
      bottom: false,
      child: Column(
        children: <Widget>[
          const AkshayaHeader(actions: <Widget>[VoiceMicButton()]),
          ToolbarRow(
            child: Row(
              children: <Widget>[
                Expanded(
                  child: AkshayaSearchField(
                    controller: _search,
                    hint: 'Search settings',
                    onChanged: _setQuery,
                    logName: 'settings-search',
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                SyncNowButton(onNeedsSetup: _showHousehold),
              ],
            ),
          ),
          Expanded(
            child: shown.isEmpty
                ? EmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'No settings match',
                    body: 'Try another word, like "alert", "backup" or '
                        '"currency".',
                    actionLabel: 'Clear search',
                    onAction: _clearSearch,
                  )
                : ListView.builder(
                    padding:
                        EdgeInsets.only(bottom: context.navClearance),
                    physics: const ClampingScrollPhysics(),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    addAutomaticKeepAlives: false,
                    itemCount: shown.length,
                    itemBuilder: (BuildContext context, int index) {
                      return RepaintBoundary(
                        key: ValueKey<String>('settings-${shown[index].id}'),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            if (index > 0) const Divider(),
                            shown[index].builder(context),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
