import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/clock.dart';
import '../../ai/presentation/providers.dart';
import '../../pantry/domain/entities.dart';
import '../../pantry/presentation/providers.dart';
import '../../shopping/presentation/providers.dart';
import '../data/record_audio_gateway.dart';
import '../data/speech_to_text_gateway.dart';
import '../domain/command_executor.dart';
import '../domain/command_service.dart';
import '../domain/grocery_dictionary.dart';
import '../domain/grocery_lexicon.dart';
import '../domain/offline_command_parser.dart';
import '../domain/speech_gateway.dart';

final Provider<SpeechGateway> speechGatewayProvider =
    Provider<SpeechGateway>((Ref ref) => SpeechToTextGateway());

final Provider<AudioRecorderGateway> audioRecorderProvider =
    Provider<AudioRecorderGateway>((Ref ref) => RecordAudioGateway());

/// The bundled dictionary of Indian grocery words.
final FutureProvider<GroceryDictionary> groceryDictionaryProvider =
    FutureProvider<GroceryDictionary>((Ref ref) async {
  final String json =
      await rootBundle.loadString('assets/dictionary/grocery_dictionary.json');
  return GroceryDictionary.fromJson(json);
});

/// The dictionary plus the person's own item names and aliases. Rebuilt when
/// the pantry changes, so new aliases work at once.
final Provider<GroceryLexicon?> groceryLexiconProvider =
    Provider<GroceryLexicon?>((Ref ref) {
  final GroceryDictionary? dictionary =
      ref.watch(groceryDictionaryProvider).value;
  if (dictionary == null) {
    return null;
  }
  final List<ItemWithBatches> records =
      ref.watch(itemsStreamProvider).value ?? const <ItemWithBatches>[];
  return GroceryLexicon.build(
    dictionary,
    items: <Item>[for (final ItemWithBatches r in records) r.item],
  );
});

/// Null until the dictionary has loaded.
final Provider<CommandService?> commandServiceProvider =
    Provider<CommandService?>((Ref ref) {
  final GroceryLexicon? lexicon = ref.watch(groceryLexiconProvider);
  if (lexicon == null) {
    return null;
  }
  return CommandService(
    parser: OfflineCommandParser(lexicon),
    lexicon: lexicon,
    ai: ref.watch(aiCommandServiceProvider),
  );
});

final Provider<CommandExecutor> commandExecutorProvider =
    Provider<CommandExecutor>((Ref ref) {
  return CommandExecutor(
    pantry: ref.watch(pantryRepositoryProvider),
    shopping: ref.watch(shoppingRepositoryProvider),
    now: ref.watch(clockProvider),
    warningDays: ref.watch(expiryWarningDaysProvider),
  );
});
