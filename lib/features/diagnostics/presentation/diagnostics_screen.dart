import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:akshaya/core/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/diagnostics/app_info.dart';
import '../../../core/diagnostics/diag_entry.dart';
import '../../../core/diagnostics/diag_log.dart';
import '../../../core/share/share_service.dart';
import '../../../core/ui/feedback.dart';
import '../../backup/presentation/backup_files.dart';
import '../domain/diag_report.dart';
import 'providers.dart';

/// How many log entries are drawn at once (the newest). The report has more.
const int kDiagShownEntries = 200;

/// Settings > Diagnostics: which build is running, counts of what is stored,
/// and the log of errors and key events. Everything stays on the phone until
/// the person shares or saves a report.
class DiagnosticsScreen extends ConsumerStatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  ConsumerState<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

enum _Filter { all, problems, errors }

class _DiagnosticsScreenState extends ConsumerState<DiagnosticsScreen> {
  late final DiagLog _log = ref.read(diagLogProvider);
  List<DiagEntry>? _entries;
  _Filter _filter = _Filter.all;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _log.addListener(_scheduleReload);
    unawaited(_reload());
  }

  @override
  void dispose() {
    _log.removeListener(_scheduleReload);
    _debounce?.cancel();
    super.dispose();
  }

  void _scheduleReload() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      unawaited(_reload());
    });
  }

  Future<void> _reload() async {
    final List<DiagEntry> all = await _log.entries();
    if (!mounted) {
      return;
    }
    setState(() => _entries = all);
  }

  Future<void> _refresh() async {
    ref.invalidate(diagStateProvider);
    await _reload();
  }

  Future<String> _report({required int maxLogChars}) async {
    final AppInfo info = await ref.read(appInfoProvider.future);
    final List<MapEntry<String, String>> state =
        await ref.read(diagStateProvider.future);
    final List<DiagEntry> entries = await _log.entries();
    return DiagReport.build(
      info: info,
      state: state,
      entries: entries,
      createdAt: DateTime.now(),
      maxLogChars: maxLogChars,
    );
  }

  Future<void> _share() async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      final String text = await _report(maxLogChars: 60000);
      await ref.read(shareServiceProvider).shareText(
            text,
            subject: 'Akshaya Patra diagnostics',
          );
    } on Object catch (error, stack) {
      _log.log(
        DiagLevel.error,
        'diagnostics',
        'Could not share the report',
        error: error,
        stack: stack,
      );
      showMessage(messenger, 'Could not share the report. Try Save as file.');
    }
  }

  Future<void> _copy() async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      final String text = await _report(maxLogChars: 60000);
      await Clipboard.setData(ClipboardData(text: text));
      showMessage(messenger, 'Report copied');
    } on Object catch (error, stack) {
      _log.log(
        DiagLevel.error,
        'diagnostics',
        'Could not copy the report',
        error: error,
        stack: stack,
      );
      showMessage(messenger, failureMessage(error));
    }
  }

  Future<void> _save() async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      final String text = await _report(maxLogChars: 2000000);
      final DateTime now = DateTime.now();
      final String stamp = '${now.year}'
          '${now.month.toString().padLeft(2, '0')}'
          '${now.day.toString().padLeft(2, '0')}';
      final bool saved = await ref.read(backupFilesProvider).save(
            fileName: 'akshaya-diagnostics-$stamp.txt',
            bytes: Uint8List.fromList(utf8.encode(text)),
            dialogTitle: 'Save diagnostics report',
          );
      if (saved) {
        showMessage(messenger, 'Report saved');
      }
    } on Object catch (error, stack) {
      _log.log(
        DiagLevel.error,
        'diagnostics',
        'Could not save the report',
        error: error,
        stack: stack,
      );
      showMessage(messenger, failureMessage(error));
    }
  }

  Future<void> _clear() async {
    final bool? yes = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Clear the log?'),
        content: const Text(
          'This only deletes the diagnostics log on this phone. Your pantry '
          'and settings are not touched.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Clear log'),
          ),
        ],
      ),
    );
    if (yes != true) {
      return;
    }
    await _log.clear();
    _log.log(DiagLevel.info, 'app', 'Diagnostics log cleared');
    await _reload();
  }

  List<DiagEntry> _shown(List<DiagEntry> all) {
    final Iterable<DiagEntry> newestFirst = all.reversed;
    final Iterable<DiagEntry> filtered = switch (_filter) {
      _Filter.all => newestFirst,
      _Filter.problems =>
        newestFirst.where((DiagEntry e) => e.level != DiagLevel.info),
      _Filter.errors =>
        newestFirst.where((DiagEntry e) => e.level == DiagLevel.error),
    };
    return filtered.take(kDiagShownEntries).toList();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<AppInfo> info = ref.watch(appInfoProvider);
    final AsyncValue<List<MapEntry<String, String>>> state =
        ref.watch(diagStateProvider);
    final List<DiagEntry>? entries = _entries;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnostics'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(
              'A private log of errors and key events, kept only on this '
              'phone. If something breaks, share the report so it can be '
              'fixed. It holds counts, not your food list, but give it a '
              'quick look before you send it.',
              style: context.akText.bodyMedium!.copyWith(
                color: context.akColors.textSecondary,
              ),
            ),
          ),
          const _Heading('This build'),
          if (info.value != null)
            for (final MapEntry<String, String> row in info.value!.rows())
              _InfoRow(label: row.key, value: row.value)
          else
            const _InfoRow(label: 'App', value: 'Loading...'),
          const _Heading('What is stored'),
          if (state.value != null)
            for (final MapEntry<String, String> row in state.value!)
              _InfoRow(label: row.key, value: row.value)
          else
            const _InfoRow(label: 'Counts', value: 'Loading...'),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                FilledButton.icon(
                  onPressed: _share,
                  icon: const Icon(Icons.ios_share_rounded),
                  label: const Text('Share report'),
                ),
                OutlinedButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save_alt_rounded),
                  label: const Text('Save as file'),
                ),
                OutlinedButton.icon(
                  onPressed: _copy,
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('Copy'),
                ),
                TextButton.icon(
                  onPressed: _clear,
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Clear log'),
                ),
              ],
            ),
          ),
          const _Heading('Log'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Wrap(
              spacing: AppSpacing.sm,
              children: <Widget>[
                for (final (_Filter, String) option in <(_Filter, String)>[
                  (_Filter.all, 'Everything'),
                  (_Filter.problems, 'Warnings and errors'),
                  (_Filter.errors, 'Errors'),
                ])
                  ChoiceChip(
                    label: Text(option.$2),
                    selected: _filter == option.$1,
                    onSelected: (bool _) =>
                        setState(() => _filter = option.$1),
                  ),
              ],
            ),
          ),
          if (entries == null)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            ..._entryTiles(context, entries),
        ],
      ),
    );
  }

  List<Widget> _entryTiles(BuildContext context, List<DiagEntry> all) {
    final List<DiagEntry> shown = _shown(all);
    if (shown.isEmpty) {
      return <Widget>[
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(
            all.isEmpty
                ? 'Nothing logged yet.'
                : 'Nothing matches this filter.',
            style: context.akText.bodyMedium!.copyWith(
              color: context.akColors.textSecondary,
            ),
          ),
        ),
      ];
    }
    return <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          0,
        ),
        child: Text(
          'Newest first. Showing ${shown.length} of ${all.length}.',
          style: context.akText.bodySmall!.copyWith(
            color: context.akColors.textSecondary,
          ),
        ),
      ),
      for (final DiagEntry entry in shown) _EntryTile(entry: entry),
    ];
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        0,
      ),
      child: SectionHeader(title: title),
    );
  }
}

/// A label with its value underneath, so long values wrap at any font size.
class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: context.akText.bodySmall!.copyWith(
              color: context.akColors.textSecondary,
            ),
          ),
          SelectableText(value, style: context.akText.bodyMedium),
        ],
      ),
    );
  }
}

String _two(int n) => n.toString().padLeft(2, '0');

/// "06/11 14:55:01" in the phone's time zone.
String diagTimeLabel(DateTime utc) {
  final DateTime t = utc.toLocal();
  return '${_two(t.day)}/${_two(t.month)} '
      '${_two(t.hour)}:${_two(t.minute)}:${_two(t.second)}';
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry});

  final DiagEntry entry;

  @override
  Widget build(BuildContext context) {
    final AkshayaColors colors = context.akColors;
    final (IconData icon, Color color) = switch (entry.level) {
      DiagLevel.error => (Icons.error_rounded, colors.expired.foreground),
      DiagLevel.warning =>
        (Icons.warning_amber_rounded, colors.expiring.foreground),
      DiagLevel.info => (Icons.info_outline_rounded, colors.textSecondary),
    };
    final String? stack = entry.stack;
    final Widget title = Text(
      entry.message,
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    );
    final Widget subtitle = Text('${diagTimeLabel(entry.time)}  ·  ${entry.tag}');
    if (stack == null) {
      return ListTile(
        leading: Icon(icon, color: color),
        title: title,
        subtitle: subtitle,
      );
    }
    return ExpansionTile(
      leading: Icon(icon, color: color),
      title: title,
      subtitle: subtitle,
      childrenPadding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SelectableText(stack, style: context.akText.bodySmall),
      ],
    );
  }
}
