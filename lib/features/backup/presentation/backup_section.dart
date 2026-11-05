import 'dart:convert';
import 'dart:typed_data';

import 'package:akshaya/core/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/clock.dart';
import '../../../core/ui/feedback.dart';
import '../../pantry/data/database/app_database.dart';
import '../../pantry/domain/entities.dart';
import '../../pantry/presentation/providers.dart';
import '../data/backup_service.dart';
import '../domain/backup_csv.dart';
import 'backup_files.dart';

final Provider<BackupService> backupServiceProvider =
    Provider<BackupService>((Ref ref) {
  final AppDatabase db = ref.watch(appDatabaseProvider);
  return BackupService(db);
});

String _stamp(DateTime d) {
  final String m = d.month.toString().padLeft(2, '0');
  final String day = d.day.toString().padLeft(2, '0');
  return '${d.year}$m$day';
}

/// Settings section: JSON backup and restore, CSV export.
class BackupSection extends ConsumerWidget {
  const BackupSection({super.key});

  Future<void> _saveFile(
    BuildContext context,
    WidgetRef ref, {
    required String fileName,
    required Uint8List bytes,
    required String title,
    required String done,
  }) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      final bool saved = await ref.read(backupFilesProvider).save(
            fileName: fileName,
            bytes: bytes,
            dialogTitle: title,
          );
      if (saved) {
        showMessage(messenger, done);
      }
    } on Object catch (error) {
      showMessage(messenger, failureMessage(error));
    }
  }

  Future<void> _exportJson(BuildContext context, WidgetRef ref) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      final List<int> bytes = await ref.read(backupServiceProvider).exportBytes();
      if (!context.mounted) {
        return;
      }
      await _saveFile(
        context,
        ref,
        fileName: 'akshaya-backup-${_stamp(ref.read(todayProvider))}.json',
        bytes: Uint8List.fromList(bytes),
        title: 'Save backup',
        done: 'Backup saved',
      );
    } on Object catch (error) {
      showMessage(messenger, failureMessage(error));
    }
  }

  Future<void> _exportCsv(
    BuildContext context,
    WidgetRef ref, {
    required bool history,
  }) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      final PantryRepositoryReader reader = PantryRepositoryReader(ref);
      final List<ItemWithBatches> records = await reader.items();
      final List<Category> categories = await reader.categories();
      final String text = history
          ? BackupCsv.history(await reader.history(), records)
          : BackupCsv.pantry(records, categories);
      if (!context.mounted) {
        return;
      }
      await _saveFile(
        context,
        ref,
        fileName:
            'akshaya-${history ? 'history' : 'pantry'}-${_stamp(ref.read(todayProvider))}.csv',
        bytes: Uint8List.fromList(utf8.encode(text)),
        title: 'Save CSV',
        done: 'CSV saved',
      );
    } on Object catch (error) {
      showMessage(messenger, failureMessage(error));
    }
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final bool? go = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Restore from backup?'),
        content: const Text(
          'Items in the file are added to your pantry. If an item exists in '
          'both, the newer version is kept. Nothing is deleted.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Choose file'),
          ),
        ],
      ),
    );
    if (go != true || !context.mounted) {
      return;
    }
    try {
      final Uint8List? bytes = await ref.read(backupFilesProvider).pickBackup();
      if (bytes == null) {
        return;
      }
      final ImportSummary summary =
          await ref.read(backupServiceProvider).importBytes(bytes);
      showMessage(
        messenger,
        'Restored: ${summary.added} added, ${summary.updated} updated, '
        '${summary.skipped} already up to date',
      );
    } on Object catch (error) {
      showMessage(messenger, failureMessage(error));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.xs,
          ),
          child: SectionHeader(title: 'Backup and export'),
        ),
        ListTile(
          leading: const Icon(Icons.download_rounded),
          title: const Text('Save a backup'),
          subtitle: const Text('Everything in one JSON file'),
          onTap: () => _exportJson(context, ref),
        ),
        ListTile(
          leading: const Icon(Icons.upload_file_rounded),
          title: const Text('Restore from a backup'),
          subtitle: const Text('Merges with what is on this phone'),
          onTap: () => _import(context, ref),
        ),
        ListTile(
          leading: const Icon(Icons.table_chart_outlined),
          title: const Text('Export pantry as CSV'),
          onTap: () => _exportCsv(context, ref, history: false),
        ),
        ListTile(
          leading: const Icon(Icons.history_rounded),
          title: const Text('Export usage history as CSV'),
          onTap: () => _exportCsv(context, ref, history: true),
        ),
      ],
    );
  }
}

/// One-shot reads from the pantry repository for exports.
class PantryRepositoryReader {
  PantryRepositoryReader(this._ref);

  final WidgetRef _ref;

  Future<List<ItemWithBatches>> items() =>
      _ref.read(pantryRepositoryProvider).watchItems().first;

  Future<List<Category>> categories() =>
      _ref.read(pantryRepositoryProvider).watchCategories().first;

  Future<List<ConsumptionEntry>> history() =>
      _ref.read(pantryRepositoryProvider).watchAllHistory().first;
}
