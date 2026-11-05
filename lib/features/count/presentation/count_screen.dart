import 'dart:async';

import 'package:akshaya/core/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/feedback.dart';
import '../../pantry/domain/entities.dart';
import '../../pantry/domain/pantry_repository.dart';
import '../../pantry/domain/stock_count.dart';
import '../../pantry/domain/unit.dart';
import '../../pantry/presentation/providers.dart';
import '../domain/count_session.dart';
import 'count_adjust_sheet.dart';
import 'count_flow.dart';
import 'count_summary_screen.dart';
import 'providers.dart';

/// Walks through the items of a count one by one: tap Matches, change the
/// quantity, or mark the item finished. Swipe right to confirm, left to put
/// an item off until later. Every answer is saved at once and can be undone.
class CountScreen extends ConsumerWidget {
  const CountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CountSession? session = ref.watch(countSessionProvider);
    final AsyncValue<List<CountLine>> queue = ref.watch(countQueueProvider);
    final Map<String, Category> categories =
        ref.watch(categoriesByIdProvider);

    if (session == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Count mode')),
        body: const SafeArea(
          child: EmptyState(
            icon: Icons.fact_check_outlined,
            title: 'No count open',
            body: 'Start a count from the Pantry tab.',
          ),
        ),
      );
    }

    final int answered = session.outcomes.length;
    final int skipped = session.skipped.length;
    final int todo = queue.value?.length ?? 0;
    final int total = answered + skipped + todo;
    final double progress = total == 0 ? 0 : (answered + skipped) / total;

    return Scaffold(
      appBar: AppBar(
        title: Text(countScopeLabel(session.scope, categories)),
        actions: <Widget>[
          TextButton(
            onPressed: () => _finish(context, ref, todo: todo),
            child: const Text('Finish'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  LinearProgressIndicator(
                    value: progress,
                    minHeight: AppSpacing.sm,
                    borderRadius: AppRadius.controlBorder,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '${answered + skipped} of $total checked'
                    '${skipped > 0 ? ' · $skipped put off' : ''}',
                    style: context.akText.bodyMedium!.copyWith(
                      color: context.akColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: queue.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (Object error, StackTrace stack) => EmptyState(
                  icon: Icons.error_outline_rounded,
                  title: 'Could not load the pantry',
                  body: failureMessage(error),
                ),
                data: (List<CountLine> lines) {
                  if (lines.isEmpty) {
                    return _AllDone(
                      isEmptyScope: total == 0,
                      skipped: skipped,
                      onSummary: () => _finish(context, ref, todo: 0),
                      onReview: () =>
                          ref.read(countSessionProvider.notifier).reviewSkipped(),
                      onBack: () => Navigator.of(context).pop(),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      0,
                      AppSpacing.lg,
                      AppSpacing.xl,
                    ),
                    itemCount: lines.length,
                    separatorBuilder: (BuildContext context, int index) =>
                        const SizedBox(height: AppSpacing.md),
                    itemBuilder: (BuildContext context, int index) {
                      final CountLine line = lines[index];
                      return _CountCard(
                        key: ValueKey<String>(line.item.id),
                        line: line,
                        onMatch: () => unawaited(_match(context, ref, line)),
                        onChange: () => unawaited(_change(context, ref, line)),
                        onFinished: () =>
                            unawaited(_markFinished(context, ref, line)),
                        onSkip: () => _skip(context, ref, line),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _match(BuildContext context, WidgetRef ref, CountLine line) {
    return _apply(context, ref, line, line.expected, line.unit);
  }

  Future<void> _markFinished(
    BuildContext context,
    WidgetRef ref,
    CountLine line,
  ) {
    return _apply(context, ref, line, 0, line.unit);
  }

  Future<void> _change(
    BuildContext context,
    WidgetRef ref,
    CountLine line,
  ) async {
    final CountAnswer? answer = await showCountAdjustSheet(context, line);
    if (answer == null || !context.mounted) {
      return;
    }
    await _apply(
      context,
      ref,
      line,
      answer.quantity,
      answer.unit,
      asWaste: answer.asWaste,
    );
  }

  /// Saves one answer, remembers it for this count and offers Undo.
  Future<void> _apply(
    BuildContext context,
    WidgetRef ref,
    CountLine line,
    double quantity,
    Unit unit, {
    bool asWaste = false,
  }) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final PantryRepository repo = ref.read(pantryRepositoryProvider);
    final CountSessionNotifier session =
        ref.read(countSessionProvider.notifier);
    try {
      final CountResult result = await repo.setStock(
        itemId: line.item.id,
        quantity: quantity,
        unit: unit,
        location: line.location,
        asWaste: asWaste,
      );
      final CountOutcome outcome = CountOutcome(
        itemId: line.item.id,
        name: line.item.name,
        kind: CountOutcomeKind.of(result, asWaste: asWaste),
        expected: result.before,
        counted: result.after,
        unit: result.unit,
      );
      session.record(outcome);
      showUndoSnackBar(
        messenger,
        message: _message(outcome),
        onUndo: () async {
          await repo.undoCount(result);
          session.undo(line.item.id);
        },
      );
    } on Object catch (error) {
      showMessage(messenger, failureMessage(error));
    }
  }

  void _skip(BuildContext context, WidgetRef ref, CountLine line) {
    final CountSessionNotifier session =
        ref.read(countSessionProvider.notifier);
    session.skip(line.item.id);
    showUndoSnackBar(
      ScaffoldMessenger.of(context),
      message: 'Put off ${line.item.name}',
      onUndo: () async => session.undo(line.item.id),
    );
  }

  static String _message(CountOutcome o) {
    switch (o.kind) {
      case CountOutcomeKind.matched:
        return '${o.name}: matches';
      case CountOutcomeKind.raised:
        return '${o.name}: ${o.differenceLabel} found';
      case CountOutcomeKind.lowered:
        return '${o.name}: ${o.differenceLabel}';
      case CountOutcomeKind.finished:
        return '${o.name}: marked finished';
      case CountOutcomeKind.wasted:
        return '${o.name}: ${o.differenceLabel} wasted';
    }
  }

  Future<void> _finish(
    BuildContext context,
    WidgetRef ref, {
    required int todo,
  }) async {
    final NavigatorState navigator = Navigator.of(context);
    final CountSessionNotifier session =
        ref.read(countSessionProvider.notifier);
    final CountSession? current = ref.read(countSessionProvider);
    if (current == null) {
      return;
    }
    if (todo > 0) {
      final bool? finish = await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) => AlertDialog(
          title: const Text('Finish this count?'),
          content: Text(
            '$todo ${todo == 1 ? 'item has' : 'items have'} not been '
            'checked yet. Everything you answered is already saved.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Keep counting'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Finish'),
            ),
          ],
        ),
      );
      if (finish != true) {
        return;
      }
    }
    if (current.outcomes.isEmpty) {
      await session.discard();
      navigator.pop();
      return;
    }
    await session.finish();
    unawaited(
      navigator.pushReplacement(
        MaterialPageRoute<void>(
          builder: (BuildContext routeContext) => const CountSummaryScreen(),
        ),
      ),
    );
  }
}

class _CountCard extends StatelessWidget {
  const _CountCard({
    super.key,
    required this.line,
    required this.onMatch,
    required this.onChange,
    required this.onFinished,
    required this.onSkip,
  });

  final CountLine line;
  final VoidCallback onMatch;
  final VoidCallback onChange;
  final VoidCallback onFinished;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final AkshayaColors colors = context.akColors;
    final String where = line.location == null
        ? ''
        : ' · ${line.location!.label}';

    return Dismissible(
      key: ValueKey<String>('dismiss-${line.item.id}'),
      // The row never leaves by the swipe itself: the list is rebuilt from the
      // saved count, so a failed save leaves the card where it was.
      confirmDismiss: (DismissDirection direction) async {
        if (direction == DismissDirection.startToEnd) {
          onMatch();
        } else {
          onSkip();
        }
        return false;
      },
      background: _SwipeBackground(
        color: colors.primary,
        foreground: colors.onPrimary,
        icon: Icons.check_rounded,
        label: 'Matches',
        alignment: Alignment.centerLeft,
      ),
      secondaryBackground: _SwipeBackground(
        color: colors.surfaceAlt,
        foreground: colors.textPrimary,
        icon: Icons.schedule_rounded,
        label: 'Later',
        alignment: Alignment.centerRight,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: AppRadius.cardBorder,
          border: Border.all(
            color: colors.outline,
            width: AppSizes.borderWidth,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(line.item.name, style: context.akText.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Expected ${line.expectedLabel}$where',
              style: context.akText.bodyMedium!.copyWith(
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: <Widget>[
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onMatch,
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Matches'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(AppSizes.touchTarget),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton(
                    onPressed: onChange,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(AppSizes.touchTarget),
                    ),
                    child: const Text('Change'),
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onFinished,
                child: const Text('Finished — none left'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground({
    required this.color,
    required this.foreground,
    required this.icon,
    required this.label,
    required this.alignment,
  });

  final Color color;
  final Color foreground;
  final IconData icon;
  final String label;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      decoration: BoxDecoration(
        color: color,
        borderRadius: AppRadius.cardBorder,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, color: foreground),
          const SizedBox(width: AppSpacing.sm),
          Text(
            label,
            style: context.akText.titleSmall!.copyWith(color: foreground),
          ),
        ],
      ),
    );
  }
}

class _AllDone extends StatelessWidget {
  const _AllDone({
    required this.isEmptyScope,
    required this.skipped,
    required this.onSummary,
    required this.onReview,
    required this.onBack,
  });

  final bool isEmptyScope;
  final int skipped;
  final VoidCallback onSummary;
  final VoidCallback onReview;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    if (isEmptyScope) {
      return EmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'Nothing to count here',
        body: 'No item with stock is kept in this place.',
        actionLabel: 'Back',
        onAction: onBack,
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.task_alt_rounded,
              size: AppSizes.iconXl,
              color: context.akColors.primary,
            ),
            const SizedBox(height: AppSpacing.md),
            Text('All checked', style: context.akText.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(
              skipped > 0
                  ? '$skipped ${skipped == 1 ? 'item was' : 'items were'} put '
                      'off for later.'
                  : 'Every item in this count has an answer.',
              textAlign: TextAlign.center,
              style: context.akText.bodyMedium!.copyWith(
                color: context.akColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: onSummary,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(AppSizes.touchTarget),
              ),
              child: const Text('See summary'),
            ),
            if (skipped > 0) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton(
                onPressed: onReview,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(AppSizes.touchTarget),
                ),
                child: Text('Go through the $skipped put off'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
