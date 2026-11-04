import 'package:akshaya/core/design/design.dart';
import 'package:flutter/material.dart';

import '../../../core/util/quantity.dart';
import '../../pantry/domain/unit.dart';
import '../domain/command_models.dart';

/// What the person decided on the confirmation card.
final class ConfirmationResult {
  const ConfirmationResult.confirmed(List<CommandAction> this.actions)
      : editText = false;

  /// "Change words": go back and edit the recognised text.
  const ConfirmationResult.editText()
      : actions = null,
        editText = true;

  final List<CommandAction>? actions;
  final bool editText;
}

/// Shows the confirmation card. Returns null when cancelled.
Future<ConfirmationResult?> showCommandConfirmationSheet(
  BuildContext context,
  CommandInterpretation interpretation,
) {
  return showModalBottomSheet<ConfirmationResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (BuildContext sheetContext) {
      return CommandConfirmationCard(
        interpretation: interpretation,
        onResult: (ConfirmationResult result) =>
            Navigator.of(sheetContext).pop(result),
        onCancel: () => Navigator.of(sheetContext).pop(),
      );
    },
  );
}

/// The card shown before anything is changed: the words that were heard, the
/// English action for each item (all editable), and Confirm. Nothing happens
/// until Confirm is pressed.
class CommandConfirmationCard extends StatefulWidget {
  const CommandConfirmationCard({
    super.key,
    required this.interpretation,
    required this.onResult,
    required this.onCancel,
  });

  final CommandInterpretation interpretation;
  final ValueChanged<ConfirmationResult> onResult;
  final VoidCallback onCancel;

  @override
  State<CommandConfirmationCard> createState() =>
      _CommandConfirmationCardState();
}

class _Draft {
  _Draft(this.action)
      : intent = action.intent,
        unit = action.unit,
        name = TextEditingController(text: action.itemName),
        quantity = TextEditingController(
          text: action.quantity == null ? '' : formatNumber(action.quantity!),
        );

  final CommandAction action;
  CommandIntent intent;
  Unit? unit;
  final TextEditingController name;
  final TextEditingController quantity;

  void dispose() {
    name.dispose();
    quantity.dispose();
  }
}

class _CommandConfirmationCardState extends State<CommandConfirmationCard> {
  final List<_Draft> _drafts = <_Draft>[];
  String? _error;

  @override
  void initState() {
    super.initState();
    for (final CommandAction action in widget.interpretation.actions) {
      _drafts.add(_Draft(action));
    }
  }

  @override
  void dispose() {
    for (final _Draft draft in _drafts) {
      draft.dispose();
    }
    super.dispose();
  }

  void _addBlank() {
    setState(() {
      _drafts.add(
        _Draft(
          const CommandAction(
            intent: CommandIntent.addStock,
            itemName: '',
            isKnown: false,
          ),
        ),
      );
    });
  }

  void _remove(_Draft draft) {
    setState(() {
      _drafts.remove(draft);
      draft.dispose();
    });
  }

  void _confirm() {
    final List<CommandAction> actions = <CommandAction>[];
    for (final _Draft draft in _drafts) {
      final String name = draft.name.text.trim();
      if (draft.intent.needsItem && name.isEmpty) {
        setState(() => _error = 'Every action needs an item name.');
        return;
      }
      double? quantity;
      final String quantityText = draft.quantity.text.trim();
      if (draft.intent.usesQuantity && quantityText.isNotEmpty) {
        quantity = parseQuantity(quantityText);
        if (quantity == null || quantity <= 0) {
          setState(() => _error = 'Enter an amount greater than zero.');
          return;
        }
      }
      final bool renamed = name != draft.action.itemName;
      actions.add(
        draft.action.copyWith(
          intent: draft.intent,
          itemName: name,
          quantity: quantity,
          clearQuantity: quantity == null,
          unit: draft.intent.usesQuantity ? draft.unit : null,
          clearUnit: !draft.intent.usesQuantity || draft.unit == null,
          clearItemId: renamed,
          isKnown: true,
        ),
      );
    }
    if (actions.isEmpty) {
      setState(() => _error = 'Nothing to do.');
      return;
    }
    widget.onResult(ConfirmationResult.confirmed(actions));
  }

  @override
  Widget build(BuildContext context) {
    final AkshayaColors colors = context.akColors;
    final CommandInterpretation interpretation = widget.interpretation;
    final bool ai = interpretation.source == CommandSource.ai;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text('Check and confirm', style: context.akText.titleLarge),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: colors.surfaceAlt,
              borderRadius: AppRadius.controlBorder,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'I heard',
                  style: context.akText.labelMedium!.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  interpretation.recognizedText,
                  style: context.akText.bodyLarge,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  ai
                      ? 'Read by AI (Google Gemini). Please check it.'
                      : 'Understood on your phone.',
                  style: context.akText.labelMedium!.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (interpretation.note != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(
              interpretation.note!,
              style: context.akText.bodyMedium!.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ],
          if (!interpretation.confident && !ai) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'I am not sure I understood everything. Please check each line.',
              style: context.akText.bodyMedium,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          for (final _Draft draft in _drafts)
            _ActionEditor(
              key: ObjectKey(draft),
              draft: draft,
              onChanged: () => setState(() => _error = null),
              onRemove: () => _remove(draft),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _addBlank,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add another'),
            ),
          ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Text(
              _error!,
              style: context.akText.bodyMedium!.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: _drafts.isEmpty ? null : _confirm,
            child: const Text('Confirm'),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed: () =>
                      widget.onResult(const ConfirmationResult.editText()),
                  child: const Text('Change words'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: TextButton(
                  onPressed: widget.onCancel,
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionEditor extends StatefulWidget {
  const _ActionEditor({
    super.key,
    required this.draft,
    required this.onChanged,
    required this.onRemove,
  });

  final _Draft draft;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  State<_ActionEditor> createState() => _ActionEditorState();
}

class _ActionEditorState extends State<_ActionEditor> {
  @override
  Widget build(BuildContext context) {
    final _Draft draft = widget.draft;
    final AkshayaColors colors = context.akColors;
    final CommandAction base = draft.action;

    String? hint;
    if (draft.intent.needsItem && base.itemName.isNotEmpty) {
      if (base.isInPantry) {
        hint = 'In your pantry';
      } else if (draft.intent == CommandIntent.addStock) {
        hint = 'New item, it will be created';
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: DropdownButtonFormField<CommandIntent>(
                    initialValue: draft.intent,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Action'),
                    items: <DropdownMenuItem<CommandIntent>>[
                      for (final CommandIntent intent in CommandIntent.values)
                        DropdownMenuItem<CommandIntent>(
                          value: intent,
                          child: Text(
                            intent.label,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (CommandIntent? value) {
                      if (value == null) {
                        return;
                      }
                      setState(() => draft.intent = value);
                      widget.onChanged();
                    },
                  ),
                ),
                IconButton(
                  tooltip: 'Remove this action',
                  constraints: const BoxConstraints(
                    minWidth: AppSizes.touchTarget,
                    minHeight: AppSizes.touchTarget,
                  ),
                  icon: const Icon(Icons.close_rounded),
                  onPressed: widget.onRemove,
                ),
              ],
            ),
            if (draft.intent.needsItem) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: draft.name,
                textCapitalization: TextCapitalization.words,
                onChanged: (String _) => widget.onChanged(),
                decoration: InputDecoration(
                  labelText: 'Item (English)',
                  helperText: hint,
                ),
              ),
              if (base.originalText.isNotEmpty &&
                  base.originalText != base.itemName.toLowerCase())
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(
                    'You said: ${base.originalText}',
                    style: context.akText.labelMedium!.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ),
            ],
            if (draft.intent.usesQuantity) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: draft.quantity,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (String _) => widget.onChanged(),
                      decoration: const InputDecoration(labelText: 'Quantity'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    flex: 3,
                    child: DropdownButtonFormField<Unit?>(
                      initialValue: draft.unit,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Unit'),
                      items: <DropdownMenuItem<Unit?>>[
                        const DropdownMenuItem<Unit?>(
                          value: null,
                          child: Text('Item default'),
                        ),
                        for (final Unit unit in Unit.values)
                          DropdownMenuItem<Unit?>(
                            value: unit,
                            child: Text(unit.symbol),
                          ),
                      ],
                      onChanged: (Unit? value) {
                        setState(() => draft.unit = value);
                        widget.onChanged();
                      },
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
