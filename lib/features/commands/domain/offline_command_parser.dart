import '../../pantry/domain/unit.dart';
import 'command_models.dart';
import 'grocery_lexicon.dart';
import 'parser_words.dart';
import 'text_normalizer.dart';

/// Understands short grocery commands in English, Telugu and Hindi (native
/// script or romanised, and mixed) using only the bundled word lists. No
/// network, no AI.
///
/// The result is [CommandInterpretation.confident] only when every word was
/// understood; otherwise the caller may ask the AI or let the person fix the
/// card by hand.
final class OfflineCommandParser {
  const OfflineCommandParser(this.lexicon);

  final GroceryLexicon lexicon;

  CommandInterpretation parse(
    String text, {
    CommandContext context = CommandContext.general,
  }) {
    final String recognized = text.trim();
    final List<List<String>> clauses = _splitClauses(tokenize(text));
    final List<_ClauseInfo> infos = <_ClauseInfo>[
      for (final List<String> clause in clauses) _analyze(clause),
    ];
    final bool sentenceHasList = infos.any((_ClauseInfo i) => i.hasList);

    final List<CommandIntent?> decided = <CommandIntent?>[];
    bool conflict = false;
    for (final _ClauseInfo info in infos) {
      final _Decision decision = _decideIntent(
        info.intents,
        info.hasList || sentenceHasList,
        context,
      );
      conflict = conflict || decision.conflict;
      decided.add(decision.intent);
    }

    // A clause with no intent word ("... and 6 eggs") follows its neighbour.
    final List<CommandIntent?> finalIntents = List<CommandIntent?>.of(decided);
    for (int i = 0; i < finalIntents.length; i++) {
      if (finalIntents[i] != null || infos[i].intents.isNotEmpty) {
        continue;
      }
      CommandIntent? source;
      for (int j = i - 1; j >= 0 && source == null; j--) {
        source = decided[j];
      }
      for (int j = i + 1; j < finalIntents.length && source == null; j++) {
        source = decided[j];
      }
      finalIntents[i] = source;
    }

    final List<CommandAction> actions = <CommandAction>[];
    bool confident = infos.isNotEmpty && !conflict;
    final CommandIntent defaultIntent = context == CommandContext.shopping
        ? CommandIntent.addToShoppingList
        : CommandIntent.addStock;

    for (int i = 0; i < infos.length; i++) {
      final _ClauseInfo info = infos[i];
      CommandIntent? intent = finalIntents[i];
      if (_statesStock(info, intent)) {
        intent = CommandIntent.setStock;
      }
      if (info.unknown.isNotEmpty) {
        confident = false;
      }
      if (intent == null) {
        confident = false;
        if (conflict || info.items.isEmpty) {
          continue;
        }
        intent = defaultIntent;
      }
      if (intent.needsItem && info.items.isEmpty) {
        confident = false;
        if (info.unknown.isNotEmpty) {
          final String original = info.unknown.join(' ');
          actions.add(
            CommandAction(
              intent: intent,
              itemName: titleCase(original),
              originalText: original,
              isKnown: false,
            ),
          );
        }
        continue;
      }
      if (intent == CommandIntent.queryExpiring && info.items.isEmpty) {
        actions.add(
          const CommandAction(
            intent: CommandIntent.queryExpiring,
            itemName: '',
          ),
        );
        continue;
      }
      for (final _ItemRef ref in info.items) {
        final LexiconItem match = ref.match;
        if (intent == CommandIntent.setStock && ref.quantity == null) {
          // "set rice" with no amount: the card asks for one.
          confident = false;
        }
        actions.add(
          CommandAction(
            intent: intent,
            itemName: match.name,
            originalText: ref.original,
            quantity: ref.quantity,
            unit: ref.unit,
            itemId: match.itemId,
            categoryId: match.categoryId,
            typicalUnit: match.unit,
          ),
        );
      }
    }
    if (actions.isEmpty) {
      confident = false;
    }
    return CommandInterpretation(
      recognizedText: recognized,
      actions: actions,
      source: CommandSource.offline,
      confident: confident,
    );
  }

  // ---------------------------------------------------------------- clauses

  static List<List<String>> _splitClauses(List<String> tokens) {
    final List<List<String>> clauses = <List<String>>[];
    List<String> current = <String>[];
    for (final String token in tokens) {
      if (kSeparatorTokens.contains(token) ||
          kSeparatorWords.contains(token)) {
        if (current.isNotEmpty) {
          clauses.add(current);
        }
        current = <String>[];
      } else {
        current.add(token);
      }
    }
    if (current.isNotEmpty) {
      clauses.add(current);
    }
    return clauses;
  }

  static bool _isListWord(String token) {
    return kIntentWords[token] == IntentWord.list ||
        (isLatinWord(token) && token.length > 4 && token.startsWith('list')) ||
        token.startsWith('లిస్ట') ||
        token.startsWith('लिस्ट');
  }

  static bool _startsWithDigit(String token) {
    final int c = token.codeUnitAt(0);
    return c >= 0x30 && c <= 0x39;
  }

  static final RegExp _fraction = RegExp(r'^\d+/\d+$');
  static final RegExp _decimal = RegExp(r'^\d+([.,]\d+)?$');

  static double? _parseNumber(String token) {
    final double? word = kNumberWords[token];
    if (word != null) {
      return word;
    }
    switch (token) {
      case '½':
        return 0.5;
      case '¼':
        return 0.25;
      case '¾':
        return 0.75;
    }
    if (_fraction.hasMatch(token)) {
      final List<String> parts = token.split('/');
      final double a = double.parse(parts[0]);
      final double b = double.parse(parts[1]);
      return b == 0 ? null : a / b;
    }
    if (_decimal.hasMatch(token)) {
      return double.tryParse(token.replaceAll(',', '.'));
    }
    return null;
  }

  _ClauseInfo _analyze(List<String> tokens) {
    final List<_Piece> pieces = <_Piece>[];
    int i = 0;
    final int n = tokens.length;
    while (i < n) {
      final String t = tokens[i];
      if (_startsWithDigit(t) || t == '½' || t == '¼' || t == '¾') {
        final double? value = _parseNumber(t);
        if (value == null) {
          pieces.add(_Piece.ofUnknown(t, i));
        } else {
          pieces.add(_Piece.ofNumber(value, i, i + 1));
        }
        i++;
        continue;
      }
      // "do" / "दो" means 2 only when a unit or an item follows ("do kilo").
      if (t == 'do' || t == 'दो') {
        final String? next = i + 1 < n ? tokens[i + 1] : null;
        final bool isNumber = next != null &&
            (kUnitWords.containsKey(next) || lexicon.lookup(tokens, i + 1) != null);
        pieces.add(isNumber ? _Piece.ofNumber(2, i, i + 1) : _Piece.ofStop(i));
        i++;
        continue;
      }
      final bool functionWord = kNumberWords.containsKey(t) ||
          kUnitWords.containsKey(t) ||
          kIntentWords.containsKey(t) ||
          kStopWords.contains(t) ||
          _isListWord(t);
      final LexiconHit? hit = lexicon.lookup(tokens, i, allowLoose: !functionWord);
      if (hit != null &&
          !kNumberWords.containsKey(t) &&
          !(kUnitWords.containsKey(t) && t.length <= 2)) {
        pieces.add(
          _Piece.ofItem(
            hit.item,
            i,
            i + hit.tokenCount,
            tokens.sublist(i, i + hit.tokenCount).join(' '),
          ),
        );
        i += hit.tokenCount;
        continue;
      }
      if (kNumberWords.containsKey(t)) {
        pieces.add(_Piece.ofNumber(kNumberWords[t]!, i, i + 1));
      } else if (kUnitWords.containsKey(t)) {
        final bool previousIsNumber =
            pieces.isNotEmpty && pieces.last.kind == _Kind.number;
        if (t.length == 1 && !previousIsNumber) {
          pieces.add(_Piece.ofUnknown(t, i));
        } else {
          pieces.add(_Piece.ofUnit(kUnitWords[t]!, i, i + 1));
        }
      } else if (_isListWord(t)) {
        pieces.add(_Piece.ofList(i));
      } else if (kIntentWords.containsKey(t)) {
        pieces.add(_Piece.ofIntent(kIntentWords[t]!, i));
      } else if (kStopWords.contains(t)) {
        pieces.add(_Piece.ofStop(i));
      } else {
        pieces.add(_Piece.ofUnknown(t, i));
      }
      i++;
    }

    final List<_Group> groups = _groupQuantities(pieces);
    final List<_Piece> itemPieces = <_Piece>[
      for (final _Piece p in pieces)
        if (p.kind == _Kind.item) p,
    ];
    final Map<int, _Group> assigned = _assign(groups, itemPieces);

    final List<_ItemRef> items = <_ItemRef>[];
    for (int idx = 0; idx < itemPieces.length; idx++) {
      final _Group? group = assigned[idx];
      items.add(
        _ItemRef(
          match: itemPieces[idx].item!,
          original: itemPieces[idx].text,
          quantity: group?.quantity,
          unit: group?.unit,
        ),
      );
    }
    return _ClauseInfo(
      intents: <IntentWord>{
        for (final _Piece p in pieces)
          if (p.kind == _Kind.intent) p.intentWord!,
      },
      hasList: pieces.any((_Piece p) => p.kind == _Kind.list),
      items: items,
      unknown: <String>[
        for (final _Piece p in pieces)
          if (p.kind == _Kind.unknown) p.text,
      ],
      presence: tokens.any(kPresenceWords.contains),
    );
  }

  /// "2 kg", "half packet", "1 1/2 L" and a bare "kilo" (one kilo) become
  /// quantity groups.
  static List<_Group> _groupQuantities(List<_Piece> pieces) {
    final List<_Group> groups = <_Group>[];
    _Group? current;
    for (final _Piece p in pieces) {
      switch (p.kind) {
        case _Kind.number:
          if (current == null || current.unit != null) {
            if (current != null) {
              groups.add(current);
            }
            current = _Group(p.start, p.end, p.number!, null);
          } else if (p.number! < 1 && current.quantity != null) {
            current.quantity = current.quantity! + p.number!;
            current.end = p.end;
          } else {
            groups.add(current);
            current = _Group(p.start, p.end, p.number!, null);
          }
        case _Kind.unit:
          if (current == null) {
            groups.add(_Group(p.start, p.end, 1, p.unit));
          } else if (current.unit == null) {
            current.unit = p.unit;
            current.end = p.end;
            groups.add(current);
            current = null;
          } else {
            groups.add(current);
            groups.add(_Group(p.start, p.end, 1, p.unit));
            current = null;
          }
        case _Kind.item:
        case _Kind.intent:
        case _Kind.list:
        case _Kind.stop:
        case _Kind.unknown:
          if (current != null) {
            groups.add(current);
            current = null;
          }
      }
    }
    if (current != null) {
      groups.add(current);
    }
    return groups;
  }

  /// Pairs each quantity group with the nearest free item: the item after it
  /// when the sentence starts with a quantity ("2 kg rice"), the item before it
  /// otherwise ("rice 2 kg"), and the other side when that one is taken.
  static Map<int, _Group> _assign(List<_Group> groups, List<_Piece> items) {
    final Map<int, _Group> assigned = <int, _Group>{};
    if (groups.isEmpty || items.isEmpty) {
      return assigned;
    }
    final bool quantityFirst = groups.first.start < items.first.start;
    for (final _Group g in groups) {
      int? previous;
      int? next;
      for (int idx = 0; idx < items.length; idx++) {
        if (assigned.containsKey(idx)) {
          continue;
        }
        final _Piece it = items[idx];
        if (it.end <= g.start) {
          previous = idx;
        } else if (it.start >= g.end && next == null) {
          next = idx;
        }
      }
      final List<int?> order =
          quantityFirst ? <int?>[next, previous] : <int?>[previous, next];
      for (final int? candidate in order) {
        if (candidate != null) {
          assigned[candidate] = g;
          break;
        }
      }
    }
    return assigned;
  }

  // ----------------------------------------------------------------- intent

  /// "rice inka 3 kilo undi", "3 kg chawal bacha hai": an amount together with
  /// words that say it is there now (or left) sets the stock instead of adding
  /// to it. Questions never carry an amount, so a "how much" word with one
  /// also means the stock is that much.
  static bool _statesStock(_ClauseInfo info, CommandIntent? intent) {
    final bool hasAmount = info.items.any((_ItemRef r) => r.quantity != null);
    if (!hasAmount) {
      return false;
    }
    if (intent == CommandIntent.queryStock) {
      return true;
    }
    return info.presence && info.intents.isEmpty;
  }

  static _Decision _decideIntent(
    Set<IntentWord> intents,
    bool hasList,
    CommandContext context,
  ) {
    final Set<String> classes = <String>{
      for (final IntentWord w in intents)
        switch (w) {
          IntentWord.add || IntentWord.need || IntentWord.bought => 'add',
          _ => w.name,
        },
    };
    if (classes.length > 1) {
      // Two kinds of request in one clause: let the person sort it out.
      return const _Decision(null, conflict: true);
    }
    if (classes.isEmpty) {
      return const _Decision(null);
    }
    switch (classes.first) {
      case 'add':
        if (intents.contains(IntentWord.need) || hasList) {
          return const _Decision(CommandIntent.addToShoppingList);
        }
        if (intents.contains(IntentWord.bought)) {
          return const _Decision(CommandIntent.addStock);
        }
        return _Decision(
          context == CommandContext.shopping
              ? CommandIntent.addToShoppingList
              : CommandIntent.addStock,
        );
      case 'remove':
        return const _Decision(CommandIntent.removeFromShoppingList);
      case 'finished':
        return const _Decision(CommandIntent.markFinished);
      case 'use':
        return const _Decision(CommandIntent.useStock);
      case 'queryExpiring':
        return const _Decision(CommandIntent.queryExpiring);
      case 'queryStock':
        return const _Decision(CommandIntent.queryStock);
      case 'setStock':
        return const _Decision(CommandIntent.setStock);
    }
    return const _Decision(null);
  }
}

final class _Decision {
  const _Decision(this.intent, {this.conflict = false});

  final CommandIntent? intent;
  final bool conflict;
}

final class _ItemRef {
  const _ItemRef({
    required this.match,
    required this.original,
    required this.quantity,
    required this.unit,
  });

  final LexiconItem match;
  final String original;
  final double? quantity;
  final Unit? unit;
}

final class _ClauseInfo {
  const _ClauseInfo({
    required this.intents,
    required this.hasList,
    required this.items,
    required this.unknown,
    required this.presence,
  });

  final Set<IntentWord> intents;
  final bool hasList;

  /// The clause has a word that says something is there now ("undi", "hai").
  final bool presence;
  final List<_ItemRef> items;
  final List<String> unknown;
}

final class _Group {
  _Group(this.start, this.end, this.quantity, this.unit);

  final int start;
  int end;
  double? quantity;
  Unit? unit;
}

enum _Kind { number, unit, item, intent, list, stop, unknown }

final class _Piece {
  _Piece._(
    this.kind,
    this.start,
    this.end, {
    this.number,
    this.unit,
    this.item,
    this.intentWord,
    this.text = '',
  });

  factory _Piece.ofNumber(double value, int start, int end) =>
      _Piece._(_Kind.number, start, end, number: value);

  factory _Piece.ofUnit(Unit unit, int start, int end) =>
      _Piece._(_Kind.unit, start, end, unit: unit);

  factory _Piece.ofItem(LexiconItem item, int start, int end, String text) =>
      _Piece._(_Kind.item, start, end, item: item, text: text);

  factory _Piece.ofIntent(IntentWord word, int start) =>
      _Piece._(_Kind.intent, start, start + 1, intentWord: word);

  factory _Piece.ofList(int start) => _Piece._(_Kind.list, start, start + 1);

  factory _Piece.ofStop(int start) => _Piece._(_Kind.stop, start, start + 1);

  factory _Piece.ofUnknown(String text, int start) =>
      _Piece._(_Kind.unknown, start, start + 1, text: text);

  final _Kind kind;
  final int start;
  final int end;
  final double? number;
  final Unit? unit;
  final LexiconItem? item;
  final IntentWord? intentWord;
  final String text;
}
