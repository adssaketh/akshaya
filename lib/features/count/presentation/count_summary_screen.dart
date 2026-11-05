import 'package:akshaya/core/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/util/quantity.dart';
import '../domain/count_session.dart';
import 'providers.dart';

/// What a finished count found: how many items matched, which were changed
/// and by how much.
class CountSummaryScreen extends ConsumerWidget {
  const CountSummaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CountSession? session = ref.watch(countSessionProvider);
    if (session == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Count summary')),
        body: SafeArea(
          child: EmptyState(
            icon: Icons.fact_check_outlined,
            title: 'No count to show',
            body: 'Start a count from the Pantry tab.',
            actionLabel: 'Done',
            onAction: () => Navigator.of(context).popUntil(
              (Route<dynamic> route) => route.isFirst,
            ),
          ),
        ),
      );
    }

    final CountSummary summary = CountSummary.of(session);
    final AkshayaColors colors = context.akColors;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Count summary'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: <Widget>[
            Text(
              summary.checked == 1
                  ? '1 item checked'
                  : '${summary.checked} items checked',
              style: context.akText.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              summary.changed == 0
                  ? 'Everything matched the shelf.'
                  : '${summary.changed} '
                      '${summary.changed == 1 ? 'item was' : 'items were'} '
                      'corrected.',
              style: context.akText.bodyMedium!.copyWith(
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                _Stat(label: 'Matched', value: summary.matched),
                if (summary.raised > 0)
                  _Stat(label: 'Found more', value: summary.raised),
                if (summary.lowered > 0)
                  _Stat(label: 'Found less', value: summary.lowered),
                if (summary.finished > 0)
                  _Stat(label: 'Finished', value: summary.finished),
                if (summary.wasted > 0)
                  _Stat(label: 'Wasted', value: summary.wasted),
                if (summary.skipped > 0)
                  _Stat(label: 'Put off', value: summary.skipped),
              ],
            ),
            if (summary.changes.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.lg),
              const SectionHeader(title: 'Differences'),
              for (final CountOutcome o in summary.changes)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(o.name),
                  subtitle: Text(
                    '${o.kind.label}: expected ${o.unit.format(o.expected)}, '
                    'found ${o.unit.format(o.counted)}',
                  ),
                  trailing: Text(
                    o.differenceLabel,
                    style: context.akText.titleSmall,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text(
                  'Differences are logged as adjustments and do not count as '
                  'waste unless you chose wasted. See each item’s history.',
                  style: context.akText.bodySmall!.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: () {
                ref.read(countSessionProvider.notifier).close();
                Navigator.of(context).popUntil(
                  (Route<dynamic> route) => route.isFirst,
                );
              },
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(AppSizes.touchTarget),
              ),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final AkshayaColors colors = context.akColors;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceAlt,
        borderRadius: AppRadius.controlBorder,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(formatNumber(value.toDouble()), style: context.akText.titleLarge),
          Text(
            label,
            style: context.akText.bodySmall!.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
