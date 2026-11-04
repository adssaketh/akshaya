import '../../pantry/domain/storage_location.dart';
import '../../pantry/domain/unit.dart';

/// What a spoken or typed command asks for. [key] is the value used in the
/// JSON the AI returns, so never rename it.
enum CommandIntent {
  addStock(
    'add_stock',
    'Add to pantry',
    needsItem: true,
    usesQuantity: true,
  ),
  useStock(
    'use_stock',
    'Use from pantry',
    needsItem: true,
    usesQuantity: true,
  ),
  markFinished(
    'mark_finished',
    'Mark as finished',
    needsItem: true,
    usesQuantity: false,
  ),
  addToShoppingList(
    'add_to_shopping_list',
    'Add to shopping list',
    needsItem: true,
    usesQuantity: true,
  ),
  removeFromShoppingList(
    'remove_from_shopping_list',
    'Remove from shopping list',
    needsItem: true,
    usesQuantity: false,
  ),
  queryExpiring(
    'query_expiring',
    'Show what is expiring',
    needsItem: false,
    usesQuantity: false,
  ),
  queryStock(
    'query_stock',
    'Check how much is left',
    needsItem: true,
    usesQuantity: false,
  );

  const CommandIntent(
    this.key,
    this.label, {
    required this.needsItem,
    required this.usesQuantity,
  });

  final String key;

  /// English phrase shown on the confirmation card.
  final String label;

  /// The command is about one item (so the card shows an item name).
  final bool needsItem;

  /// The command has an amount (so the card shows quantity and unit).
  final bool usesQuantity;

  /// Questions change nothing.
  bool get isQuery =>
      this == CommandIntent.queryExpiring || this == CommandIntent.queryStock;

  /// The intent whose [key] is [text], or null.
  static CommandIntent? fromKey(String text) {
    final String wanted = text.trim().toLowerCase();
    for (final CommandIntent intent in CommandIntent.values) {
      if (intent.key == wanted) {
        return intent;
      }
    }
    return null;
  }
}

/// Where a command is given. A bare "add" means the shopping list on the
/// Shopping tab and the pantry everywhere else.
enum CommandContext { pantry, shopping, general }

/// How the interpretation was made.
enum CommandSource {
  /// The offline dictionary and rules.
  offline,

  /// Google Gemini, through Firebase AI Logic.
  ai,
}

/// One thing the person asked for, in English, ready to show on the
/// confirmation card. Nothing is changed until the person confirms.
final class CommandAction {
  const CommandAction({
    required this.intent,
    required this.itemName,
    this.originalText = '',
    this.quantity,
    this.unit,
    this.expiryDate,
    this.storageLocation,
    this.itemId,
    this.categoryId,
    this.typicalUnit,
    this.isKnown = true,
  });

  final CommandIntent intent;

  /// English item name. For an item already in the pantry it is that item's
  /// own name.
  final String itemName;

  /// The words the person used for the item ("biyyam"), kept as an alias when
  /// the item is new.
  final String originalText;
  final double? quantity;
  final Unit? unit;
  final DateTime? expiryDate;
  final StorageLocation? storageLocation;

  /// The pantry item this refers to, when it is already in the pantry.
  final String? itemId;

  /// Category suggested by the dictionary for a new item.
  final String? categoryId;

  /// The unit this item is usually counted in, from the pantry item or the
  /// dictionary.
  final Unit? typicalUnit;

  /// False when the offline parser did not recognise the item words.
  final bool isKnown;

  bool get isInPantry => itemId != null;

  CommandAction copyWith({
    CommandIntent? intent,
    String? itemName,
    String? originalText,
    double? quantity,
    bool clearQuantity = false,
    Unit? unit,
    bool clearUnit = false,
    DateTime? expiryDate,
    StorageLocation? storageLocation,
    String? itemId,
    bool clearItemId = false,
    String? categoryId,
    Unit? typicalUnit,
    bool? isKnown,
  }) {
    return CommandAction(
      intent: intent ?? this.intent,
      itemName: itemName ?? this.itemName,
      originalText: originalText ?? this.originalText,
      quantity: clearQuantity ? null : (quantity ?? this.quantity),
      unit: clearUnit ? null : (unit ?? this.unit),
      expiryDate: expiryDate ?? this.expiryDate,
      storageLocation: storageLocation ?? this.storageLocation,
      itemId: clearItemId ? null : (itemId ?? this.itemId),
      categoryId: categoryId ?? this.categoryId,
      typicalUnit: typicalUnit ?? this.typicalUnit,
      isKnown: isKnown ?? this.isKnown,
    );
  }
}

/// What was understood from one command.
final class CommandInterpretation {
  const CommandInterpretation({
    required this.recognizedText,
    required this.actions,
    required this.source,
    required this.confident,
    this.note,
  });

  /// The text as heard or typed, shown on the card.
  final String recognizedText;
  final List<CommandAction> actions;
  final CommandSource source;

  /// True when the offline parser understood every word. When it is false and
  /// the AI is available, the AI is asked.
  final bool confident;

  /// A short explanation for the person ("AI limit reached for today, using
  /// offline mode"), or null.
  final String? note;

  CommandInterpretation copyWith({
    String? recognizedText,
    List<CommandAction>? actions,
    CommandSource? source,
    bool? confident,
    String? note,
    bool clearNote = false,
  }) {
    return CommandInterpretation(
      recognizedText: recognizedText ?? this.recognizedText,
      actions: actions ?? this.actions,
      source: source ?? this.source,
      confident: confident ?? this.confident,
      note: clearNote ? null : (note ?? this.note),
    );
  }
}
