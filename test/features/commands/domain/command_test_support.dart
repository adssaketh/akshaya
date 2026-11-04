import 'dart:io';

import 'package:akshaya/features/commands/domain/command_models.dart';
import 'package:akshaya/features/commands/domain/grocery_dictionary.dart';
import 'package:akshaya/features/commands/domain/grocery_lexicon.dart';
import 'package:akshaya/features/commands/domain/offline_command_parser.dart';
import 'package:akshaya/features/pantry/domain/entities.dart';

/// The real bundled dictionary, read from the asset file.
GroceryDictionary loadDictionary() {
  return GroceryDictionary.fromJson(
    File('assets/dictionary/grocery_dictionary.json').readAsStringSync(),
  );
}

OfflineCommandParser buildParser({List<Item> items = const <Item>[]}) {
  return OfflineCommandParser(
    GroceryLexicon.build(loadDictionary(), items: items),
  );
}

/// "add_stock:Rice 2 kg" style summary of an action, for compact assertions.
String summarize(CommandAction a) {
  final String q = a.quantity == null
      ? ''
      : ' ${a.quantity == a.quantity!.roundToDouble() ? a.quantity!.toInt() : a.quantity}';
  final String u = a.unit == null ? '' : ' ${a.unit!.symbol}';
  return '${a.intent.key}:${a.itemName}$q$u';
}

List<String> summaries(CommandInterpretation r) =>
    <String>[for (final CommandAction a in r.actions) summarize(a)];
