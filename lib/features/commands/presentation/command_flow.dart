import 'package:akshaya/core/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/diagnostics/diag.dart';
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
///
/// Everything the flow needs after its first wait is taken here, before any
/// wait, so it does not depend on the button it started from staying on
/// screen: the screen under the sheet can rebuild while the sheet is open, and
/// a flow tied to that button would then stop without a word. Every step is
/// written to the Diagnostics log (counts only, never what was said).
Future<void> runCommandFlow(
  BuildContext context,
  WidgetRef ref, {
  required CommandContext commandContext,
}) async {
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  final NavigatorState navigator = Navigator.of(context);
  final ProviderContainer container = ProviderScope.containerOf(context);
  Diag.info('cmd', 'start (${commandContext.name})');
  try {
    await _runFlow(navigator, messenger, container, commandContext);
  } on Object catch (error, stack) {
    Diag.error('cmd', 'flow failed', error: error, stack: stack);
    if (messenger.mounted) {
      showMessage(
        messenger,
        'Something went wrong with that command. Please try again.',
      );
    }
  }
}

Future<void> _runFlow(
  NavigatorState navigator,
  ScaffoldMessengerState messenger,
  ProviderContainer container,
  CommandContext commandContext,
) async {
  String initialText = '';
  while (true) {
    if (!navigator.mounted) {
      Diag.warn('cmd', 'stopped: the app screen is gone');
      return;
    }
    final CommandInterpretation? interpretation = await showCommandInputSheet(
      navigator.context,
      commandContext: commandContext,
      initialText: initialText,
    );
    if (interpretation == null) {
      Diag.info('cmd', 'input closed without a command');
      return;
    }
    Diag.info(
      'cmd',
      'understood: ${interpretation.actions.length} action(s), '
          'source ${interpretation.source.name}',
    );
    if (!navigator.mounted) {
      Diag.warn('cmd', 'stopped before the card: the app screen is gone');
      return;
    }
    final ConfirmationResult? decision =
        await showCommandConfirmationSheet(navigator.context, interpretation);
    if (decision == null) {
      Diag.info('cmd', 'card closed without confirming');
      return;
    }
    final List<CommandAction>? actions = decision.actions;
    if (decision.editText || actions == null) {
      Diag.info('cmd', 'card: change words');
      initialText = interpretation.recognizedText;
      continue;
    }
    if (!navigator.mounted) {
      Diag.warn('cmd', 'stopped before running: the app screen is gone');
      return;
    }
    final String listId =
        container.read(selectedListProvider)?.id ?? kDefaultListId;
    final CommandRunResult run =
        await container.read(commandExecutorProvider).execute(
              actions,
              listId: listId,
              learnAliases: interpretation.source == CommandSource.ai,
            );
    final int failed =
        run.outcomes.where((ActionOutcome o) => !o.succeeded).length;
    Diag.info(
      'cmd',
      'ran ${actions.length} action(s): ${run.outcomes.length} outcome(s), '
          '$failed failed',
    );
    if (!navigator.mounted) {
      return;
    }
    await _present(navigator, messenger, run);
    return;
  }
}

Future<void> _present(
  NavigatorState navigator,
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
    context: navigator.context,
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
