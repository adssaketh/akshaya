import 'package:akshaya/core/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/feedback.dart';
import '../../shopping/domain/shopping_entities.dart';
import '../../shopping/presentation/providers.dart';
import '../domain/command_executor.dart';
import '../domain/command_models.dart';
import 'command_confirmation_sheet.dart';
import 'command_input_sheet.dart';
import 'providers.dart';

/// The whole voice/text command flow: ask, show the confirmation card, run the
/// confirmed actions, then show the result with Undo.
Future<void> runCommandFlow(
  BuildContext context,
  WidgetRef ref, {
  required CommandContext commandContext,
}) async {
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  String initialText = '';
  while (true) {
    if (!context.mounted) {
      return;
    }
    final CommandInterpretation? interpretation = await showCommandInputSheet(
      context,
      commandContext: commandContext,
      initialText: initialText,
    );
    if (interpretation == null || !context.mounted) {
      return;
    }
    final ConfirmationResult? decision =
        await showCommandConfirmationSheet(context, interpretation);
    if (decision == null || !context.mounted) {
      return;
    }
    final List<CommandAction>? actions = decision.actions;
    if (decision.editText || actions == null) {
      initialText = interpretation.recognizedText;
      continue;
    }
    final String listId =
        ref.read(selectedListProvider)?.id ?? kDefaultListId;
    final CommandRunResult run =
        await ref.read(commandExecutorProvider).execute(
              actions,
              listId: listId,
              learnAliases: interpretation.source == CommandSource.ai,
            );
    if (!context.mounted) {
      return;
    }
    await _present(context, messenger, run);
    return;
  }
}

Future<void> _present(
  BuildContext context,
  ScaffoldMessengerState messenger,
  CommandRunResult run,
) async {
  if (run.allSucceeded && !run.onlyQueries && run.hasUndo) {
    final int done = run.outcomes.length;
    showUndoSnackBar(
      messenger,
      message: done == 1
          ? run.outcomes.first.message
          : 'Done: $done changes made.',
      onUndo: run.undoAll,
    );
    return;
  }
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (BuildContext sheetContext) {
      return CommandResultSheet(
        run: run,
        onUndo: () async {
          Navigator.of(sheetContext).pop();
          try {
            await run.undoAll();
            showMessage(messenger, 'Undone.');
          } on Object catch (error) {
            showMessage(messenger, failureMessage(error));
          }
        },
        onDone: () => Navigator.of(sheetContext).pop(),
      );
    },
  );
}

/// Shows what each action did: answers to questions, and anything that could
/// not be done and why.
class CommandResultSheet extends StatelessWidget {
  const CommandResultSheet({
    super.key,
    required this.run,
    required this.onUndo,
    required this.onDone,
  });

  final CommandRunResult run;
  final VoidCallback onUndo;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final AkshayaColors colors = context.akColors;
    final bool anyFailure = !run.allSucceeded;
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
          Text(
            run.onlyQueries
                ? 'Here you go'
                : (anyFailure ? 'Some things need a look' : 'Done'),
            style: context.akText.titleLarge,
          ),
          const SizedBox(height: AppSpacing.md),
          for (final ActionOutcome outcome in run.outcomes)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(
                    outcome.succeeded
                        ? Icons.check_circle_outline_rounded
                        : Icons.error_outline_rounded,
                    color: outcome.succeeded
                        ? colors.primary
                        : Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      outcome.message,
                      style: context.akText.bodyLarge,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton(onPressed: onDone, child: const Text('OK')),
          if (run.hasUndo)
            TextButton(
              onPressed: onUndo,
              child: const Text('Undo the changes that worked'),
            ),
        ],
      ),
    );
  }
}
