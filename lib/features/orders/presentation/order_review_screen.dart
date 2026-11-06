import 'package:akshaya/core/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/clock.dart';
import '../../../core/ui/feedback.dart';
import '../../../core/util/date_only.dart';
import '../../../core/util/money.dart';
import '../../pantry/domain/entities.dart';
import '../../pantry/presentation/pantry_icons.dart';
import '../../pantry/presentation/providers.dart';
import '../domain/order_commit.dart';
import '../domain/order_import_service.dart';
import '../domain/order_models.dart';
import 'order_draft_sheet.dart';
import 'providers.dart';

/// Shows what was read from an order and adds the ticked lines to the pantry.
///
/// Nothing is saved until the person taps the button. Lines that are not food
/// start unticked; every line can be edited.
class OrderReviewScreen extends ConsumerStatefulWidget {
  const OrderReviewScreen({super.key, required this.scan, this.aiNote});

  final OrderScan scan;

  /// Why AI was not used when it was wanted ("AI limit reached for today...").
  final String? aiNote;

  @override
  ConsumerState<OrderReviewScreen> createState() => _OrderReviewScreenState();
}

class _OrderReviewScreenState extends ConsumerState<OrderReviewScreen> {
  late List<OrderDraft> _drafts = List<OrderDraft>.of(widget.scan.drafts);
  late final TextEditingController _store =
      TextEditingController(text: widget.scan.store?.label ?? '');
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _store.dispose();
    super.dispose();
  }

  int get _ticked => _drafts.where((OrderDraft d) => d.include).length;

  void _toggle(int index, bool value) {
    setState(() {
      _drafts = <OrderDraft>[
        for (int i = 0; i < _drafts.length; i++)
          if (i == index) _drafts[i].copyWith(include: value) else _drafts[i],
      ];
    });
  }

  Future<void> _edit(int index) async {
    final OrderDraft? changed = await showOrderDraftSheet(
      context,
      _drafts[index],
    );
    if (changed == null || !mounted) {
      return;
    }
    setState(() {
      _drafts = <OrderDraft>[
        for (int i = 0; i < _drafts.length; i++)
          if (i == index) changed else _drafts[i],
      ];
    });
  }

  Future<void> _submit() async {
    if (_saving || _ticked == 0) {
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final OrderCommitter committer = ref.read(orderCommitterProvider);
    final NavigatorState navigator = Navigator.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      final OrderCommitResult result = await committer.commit(
        _drafts,
        boughtOn: ref.read(todayProvider),
        store: _store.text,
      );
      if (!mounted) {
        return;
      }
      if (result.added == 0) {
        setState(() {
          _saving = false;
          _error = result.failures.isEmpty
              ? 'Nothing could be added.'
              : result.failures.join('\n');
        });
        return;
      }
      navigator.pop();
      final String base = result.added == 1
          ? 'Added 1 item to your pantry'
          : 'Added ${result.added} items to your pantry';
      showUndoSnackBar(
        messenger,
        message: result.failures.isEmpty
            ? base
            : '$base. ${result.failures.length} could not be added.',
        onUndo: () => committer.undo(result),
      );
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _error = failureMessage(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final AkshayaColors colors = context.akColors;
    final DateTime today = ref.watch(todayProvider);
    final Map<String, Category> categories =
        ref.watch(categoriesByIdProvider);
    final int count = _ticked;

    return Scaffold(
      appBar: AppBar(title: const Text('Review your order')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: FilledButton(
            onPressed: (_saving || count == 0) ? null : _submit,
            child: Text(
              _saving
                  ? 'Adding...'
                  : (count == 1
                      ? 'Add 1 item to pantry'
                      : 'Add $count items to pantry'),
            ),
          ),
        ),
      ),
      body: _drafts.isEmpty
          ? EmptyState(
              icon: Icons.receipt_long_rounded,
              title: 'No items found',
              body: 'This picture does not look like an order list. '
                  'Try a screenshot of the items in the order.',
              actionLabel: 'Back',
              onAction: () => Navigator.of(context).pop(),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.xl,
              ),
              children: <Widget>[
                Text(
                  widget.scan.usedAi
                      ? 'AI read this order. Check every line before adding.'
                      : 'Check the lines, change anything that is off, then '
                          'add them. Tap a line to edit it.',
                  style: context.akText.bodyMedium!.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                if (widget.aiNote != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    widget.aiNote!,
                    style: context.akText.bodySmall!.copyWith(
                      color: colors.expiring.foreground,
                    ),
                  ),
                ] else if (widget.scan.isHard && !widget.scan.usedAi) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Many names were not recognised. Please check them.',
                    style: context.akText.bodySmall!.copyWith(
                      color: colors.expiring.foreground,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _store,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Store (optional)',
                    hintText: 'Applies to everything below',
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                for (int i = 0; i < _drafts.length; i++) ...<Widget>[
                  _DraftTile(
                    draft: _drafts[i],
                    today: today,
                    icon: categoryIcon(categories[_drafts[i].categoryId]?.iconKey),
                    categoryName: categories[_drafts[i].categoryId]?.name,
                    onToggle: (bool value) => _toggle(i, value),
                    onEdit: () => _edit(i),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: Text(
                      _error!,
                      style: context.akText.bodyMedium!.copyWith(
                        color: colors.expired.foreground,
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _DraftTile extends StatelessWidget {
  const _DraftTile({
    required this.draft,
    required this.today,
    required this.icon,
    required this.categoryName,
    required this.onToggle,
    required this.onEdit,
  });

  final OrderDraft draft;
  final DateTime today;
  final IconData icon;
  final String? categoryName;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final AkshayaColors colors = context.akColors;
    final DateTime? expiry = draft.effectiveExpiry(today);
    final List<String> facts = <String>[
      draft.unit.format(draft.quantity),
      if (draft.price != null) formatMoney(draft.price!),
      draft.location.label,
      if (categoryName != null) categoryName!,
    ];
    final SkipReason? skip = draft.skip;
    final Color textColor =
        draft.include ? colors.textPrimary : colors.textSecondary;

    return Material(
      color: colors.surface,
      borderRadius: AppRadius.cardBorder,
      child: InkWell(
        borderRadius: AppRadius.cardBorder,
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Checkbox(
                value: draft.include,
                onChanged: (bool? value) => onToggle(value ?? false),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(
                    top: AppSpacing.sm,
                    right: AppSpacing.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Icon(
                            icon,
                            size: AppSizes.iconSm,
                            color: colors.textSecondary,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              draft.brand == null
                                  ? draft.name
                                  : '${draft.name} · ${draft.brand}',
                              style: context.akText.titleSmall!.copyWith(
                                color: textColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        facts.join(' · '),
                        style: context.akText.bodySmall!.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      if (draft.include && expiry != null)
                        Text(
                          draft.expiryIsGuess
                              ? 'Expires about ${formatDateShort(expiry)} (guess)'
                              : 'Expires ${formatDateShort(expiry)}',
                          style: context.akText.bodySmall!.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      if (skip != null)
                        Text(
                          '${skip.label}, not added unless you tick it',
                          style: context.akText.bodySmall!.copyWith(
                            color: colors.expiring.foreground,
                          ),
                        ),
                      for (final DraftNote note in draft.notes)
                        if (draft.include)
                          Text(
                            note.message,
                            style: context.akText.bodySmall!.copyWith(
                              color: colors.expiring.foreground,
                            ),
                          ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
