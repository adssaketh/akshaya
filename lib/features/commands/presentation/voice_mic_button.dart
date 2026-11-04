import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/command_models.dart';
import 'command_flow.dart';

/// The microphone button in the header of every main screen. Opens the voice
/// and text command flow.
class VoiceMicButton extends ConsumerWidget {
  const VoiceMicButton({
    super.key,
    this.commandContext = CommandContext.general,
  });

  /// Which screen the button is on ("add" means the shopping list on the
  /// Shopping tab and the pantry elsewhere).
  final CommandContext commandContext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      tooltip: 'Voice or text command',
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      icon: const Icon(Icons.mic_rounded),
      onPressed: () => runCommandFlow(
        context,
        ref,
        commandContext: commandContext,
      ),
    );
  }
}
