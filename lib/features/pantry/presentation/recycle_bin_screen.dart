import 'package:akshaya/core/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/clock.dart';
import '../../../core/ui/feedback.dart';
import '../domain/entities.dart';
import 'providers.dart';

/// How long a deleted item stays in the bin (matches the repository's limit).
const int kBinDays = 30;

/// Opens the recycle bin.
void openRecycleBin(BuildContext context) {
  Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (BuildContext _) => const RecycleBinScreen(),
    ),
  );
}

/// "just now", "5 min ago", "3 h ago", "yesterday", "6 days ago".
String deletedAgo(DateTime deletedAt, DateTime now) {
  final Duration age = now.difference(deletedAt);
  if (age.inMinutes < 1) {
    return 'just now';
  }
  if (age.inMinutes < 60) {
    return '${age.inMinutes} min ago';
  }
  if (age.inHours < 24) {
    return '${age.inHours} h ago';
  }
  if (age.inDays == 1) {
    return 'yesterday';
  }
  return '${age.inDays} days ago';
}

/// Days left before an item drops out of the bin (at least 1 while listed).
int binDaysLeft(DateTime deletedAt, DateTime now) {
  final int left = kBinDays - now.difference(deletedAt).inDays;
  return left < 1 ? 1 : left;
}

/// Groceries deleted in the last 30 days, each with a Restore button.
class RecycleBinScreen extends ConsumerWidget {
  const RecycleBinScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<DeletedItem>> items = ref.watch(deletedItemsProvider);
    final DateTime now = ref.watch(clockProvider)();
    final TextTheme text = context.akText;
    final AkshayaColors colors = context.akColors;
    return Scaffold(
      appBar: AppBar(title: const Text('Recently deleted')),
      body: items.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object _, StackTrace __) => const EmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Could not open the bin',
          body: 'Please try again in a moment.',
        ),
        data: (List<DeletedItem> list) {
          if (list.isEmpty) {
            return const EmptyState(
              icon: Icons.delete_outline_rounded,
              title: 'Nothing deleted lately',
              body:
                  'Groceries you delete stay here for 30 days, so you can '
                  'bring them back.',
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.xxl,
            ),
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Text(
                  'Deleted groceries stay here for $kBinDays days. Restoring '
                  'brings back the item and its stock.',
                  style: text.bodyMedium!.copyWith(color: colors.textSecondary),
                ),
              ),
              for (final DeletedItem d in list)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _BinCard(entry: d, now: now),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _BinCard extends ConsumerWidget {
  const _BinCard({required this.entry, required this.now});

  final DeletedItem entry;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AkshayaColors colors = context.akColors;
    final TextTheme text = context.akText;
    final String stock = entry.batchCount == 0
        ? 'no stock left'
        : '${entry.batchCount} ${entry.batchCount == 1 ? 'batch' : 'batches'}';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadius.cardBorder,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: <Widget>[
            Icon(Icons.inventory_2_outlined, color: colors.textSecondary),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    entry.item.name,
                    style: text.titleSmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Deleted ${deletedAgo(entry.deletedAt, now)} · $stock',
                    style: text.bodySmall!.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  Text(
                    'Stays here ${binDaysLeft(entry.deletedAt, now)} more '
                    '${binDaysLeft(entry.deletedAt, now) == 1 ? 'day' : 'days'}',
                    style: text.labelSmall!.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            FilledButton.tonal(
              onPressed: () => _restore(context, ref),
              child: const Text('Restore'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(pantryRepositoryProvider)
          .restoreDeletedItem(entry.item.id);
      showMessage(messenger, 'Restored ${entry.item.name}');
    } on Object catch (error) {
      showMessage(messenger, failureMessage(error));
    }
  }
}
