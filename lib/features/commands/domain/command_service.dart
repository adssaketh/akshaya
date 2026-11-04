import '../../ai/domain/ai_command_service.dart';
import '../../ai/domain/ai_failures.dart';
import '../../ai/domain/ai_gate.dart';
import 'command_models.dart';
import 'grocery_lexicon.dart';
import 'offline_command_parser.dart';
import 'voice_language.dart';

/// Turns words into a proposed list of actions: the offline parser first, the
/// AI only when the parser is not sure and AI is allowed. The result is never
/// executed here; the person confirms it on a card first.
final class CommandService {
  const CommandService({
    required this.parser,
    required this.lexicon,
    this.ai,
  });

  final OfflineCommandParser parser;
  final GroceryLexicon lexicon;

  /// Null when the build has no AI at all.
  final AiCommandService? ai;

  Future<CommandInterpretation> interpret(
    String text, {
    CommandContext context = CommandContext.general,
    VoiceLanguage language = VoiceLanguage.auto,
    List<String> knownItemNames = const <String>[],
  }) async {
    final CommandInterpretation offline =
        parser.parse(text, context: context);
    if (offline.confident) {
      return offline;
    }
    final AiCommandService? service = ai;
    if (service == null) {
      return offline;
    }
    final AiAvailability availability = await service.availability();
    if (!availability.isReady) {
      return offline.copyWith(note: availability.message);
    }
    try {
      final List<CommandAction> raw = await service.interpret(
        text: text,
        knownItemNames: knownItemNames,
        language: language,
        context: context,
      );
      if (raw.isEmpty) {
        return offline.copyWith(
          note: 'AI could not find a grocery action, using offline mode.',
        );
      }
      return CommandInterpretation(
        recognizedText: text.trim(),
        actions: <CommandAction>[for (final CommandAction a in raw) _resolve(a)],
        source: CommandSource.ai,
        confident: true,
      );
    } on AiFailure catch (failure) {
      return offline.copyWith(note: failure.message);
    }
  }

  /// Links an AI action to a pantry item or dictionary product by name, so the
  /// English name is the one the app already uses.
  CommandAction _resolve(CommandAction action) {
    if (!action.intent.needsItem) {
      return action;
    }
    final LexiconItem? hit = lexicon.lookupPhrase(action.itemName) ??
        (action.originalText.isEmpty
            ? null
            : lexicon.lookupPhrase(action.originalText));
    if (hit == null) {
      return action;
    }
    return action.copyWith(
      itemName: hit.name,
      itemId: hit.itemId,
      categoryId: hit.categoryId,
      typicalUnit: hit.unit,
    );
  }
}
