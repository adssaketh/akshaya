import 'package:akshaya/core/design/design.dart' show StatusKind;

import '../../../core/util/quantity.dart';
import '../../pantry/domain/default_categories.dart';
import '../../pantry/domain/entities.dart';
import '../../pantry/domain/failures.dart';
import '../../pantry/domain/pantry_repository.dart';
import '../../pantry/domain/stock_logic.dart';
import '../../pantry/domain/unit.dart';
import '../../shopping/domain/shopping_entities.dart';
import '../../shopping/domain/shopping_enums.dart';
import '../../shopping/domain/shopping_repository.dart';
import 'command_models.dart';
import 'text_normalizer.dart';

/// What happened to one action.
final class ActionOutcome {
  const ActionOutcome({
    required this.action,
    required this.succeeded,
    required this.message,
    this.undo,
  });

  final CommandAction action;
  final bool succeeded;

  /// English sentence for the person ("Added 2 kg Rice to your pantry").
  final String message;

  /// Reverses this action; null for questions and for nothing-to-do results.
  final Future<void> Function()? undo;
}

/// What happened to a whole confirmed command.
final class CommandRunResult {
  const CommandRunResult(this.outcomes);

  final List<ActionOutcome> outcomes;

  bool get allSucceeded => outcomes.every((ActionOutcome o) => o.succeeded);

  bool get hasUndo => outcomes.any((ActionOutcome o) => o.undo != null);

  /// True when the result is only answers to questions.
  bool get onlyQueries => outcomes.every(
        (ActionOutcome o) => o.action.intent.isQuery,
      );

  /// Reverses every action that can be reversed, newest first.
  Future<void> undoAll() async {
    for (final ActionOutcome outcome in outcomes.reversed) {
      final Future<void> Function()? undo = outcome.undo;
      if (undo != null) {
        await undo();
      }
    }
  }
}

/// Carries out confirmed actions. One failing action never stops the others,
/// and every change comes with an undo.
final class CommandExecutor {
  CommandExecutor({
    required this.pantry,
    required this.shopping,
    required this.now,
    required this.warningDays,
  });

  final PantryRepository pantry;
  final ShoppingRepository shopping;
  final DateTime Function() now;
  final int warningDays;

  /// Runs [actions]. Aliases are learned for new items and, when
  /// [learnAliases] is true (the AI read the command), for existing items too,
  /// so the same words need no AI call next time.
  Future<CommandRunResult> execute(
    List<CommandAction> actions, {
    required String listId,
    bool learnAliases = false,
  }) async {
    final _Pantry state = _Pantry(await pantry.watchItems().first);
    final List<ActionOutcome> outcomes = <ActionOutcome>[];
    for (final CommandAction action in actions) {
      try {
        outcomes.add(
          await _run(action, state, listId: listId, learn: learnAliases),
        );
      } on PantryFailure catch (failure) {
        outcomes.add(
          ActionOutcome(
            action: action,
            succeeded: false,
            message: failure.message,
          ),
        );
      } on Object {
        outcomes.add(
          ActionOutcome(
            action: action,
            succeeded: false,
            message: 'Could not do that for ${_label(action)}.',
          ),
        );
      }
    }
    return CommandRunResult(outcomes);
  }

  Future<ActionOutcome> _run(
    CommandAction action,
    _Pantry state, {
    required String listId,
    required bool learn,
  }) {
    switch (action.intent) {
      case CommandIntent.addStock:
        return _addStock(action, state, learn: learn);
      case CommandIntent.useStock:
        return _useStock(action, state, learn: learn);
      case CommandIntent.markFinished:
        return _markFinished(action, state);
      case CommandIntent.addToShoppingList:
        return _addToList(action, state, listId: listId);
      case CommandIntent.removeFromShoppingList:
        return _removeFromList(action, state, listId: listId);
      case CommandIntent.queryExpiring:
        return Future<ActionOutcome>.value(_queryExpiring(action, state));
      case CommandIntent.queryStock:
        return Future<ActionOutcome>.value(_queryStock(action, state));
    }
  }

  // ---------------------------------------------------------------- pantry

  Future<ActionOutcome> _addStock(
    CommandAction action,
    _Pantry state, {
    required bool learn,
  }) async {
    final double quantity = roundQty(action.quantity ?? 1);
    if (quantity <= 0) {
      throw const InvalidInputFailure('The amount must be more than zero.');
    }
    Item? item = state.find(action);
    bool created = false;
    final Unit unit;
    if (item == null) {
      final Unit? typical = action.typicalUnit;
      final Unit? asked = action.unit;
      unit = asked ?? typical ?? Unit.pcs;
      final Unit defaultUnit =
          typical != null && typical.isCompatibleWith(unit) ? typical : unit;
      item = await pantry.addItem(
        ItemDraft(
          name: action.itemName,
          categoryId: action.categoryId ?? kDefaultCategoryId,
          defaultUnit: defaultUnit,
          aliases: _aliasesFor(action, existing: const <String>[]),
        ),
      );
      state.add(item);
      created = true;
    } else {
      unit = action.unit ?? item.defaultUnit;
      if (!unit.isCompatibleWith(item.defaultUnit)) {
        throw InvalidInputFailure(
          '${item.name} is counted in ${item.defaultUnit.symbol}, '
          'not ${unit.symbol}.',
        );
      }
      if (learn) {
        item = await _learnAlias(item, action, state);
      }
    }
    final StockBatch batch = await pantry.addBatch(
      BatchDraft(
        itemId: item.id,
        quantityBought: quantity,
        unit: unit,
        purchaseDate: dateOnlyOf(now()),
        expiryDate: action.expiryDate,
        storageLocation:
            action.storageLocation ?? item.defaultStorageLocation,
      ),
    );
    final String itemId = item.id;
    return ActionOutcome(
      action: action,
      succeeded: true,
      message: 'Added ${unit.format(quantity)} ${item.name} to your pantry.',
      undo: () async {
        if (created) {
          await pantry.deleteItem(itemId);
        } else {
          await pantry.deleteBatch(batch.id);
        }
      },
    );
  }

  Future<ActionOutcome> _useStock(
    CommandAction action,
    _Pantry state, {
    required bool learn,
  }) async {
    Item? item = state.find(action);
    if (item == null) {
      return _notInPantry(action);
    }
    final double? quantity = action.quantity;
    if (quantity == null || quantity <= 0) {
      throw InvalidInputFailure(
        'Say how much ${item.name} you used, for example 1 ${item.defaultUnit.symbol}.',
      );
    }
    final Unit unit = action.unit ?? item.defaultUnit;
    if (learn) {
      item = await _learnAlias(item, action, state);
    }
    final UseResult result = await pantry.useStock(
      itemId: item.id,
      quantity: roundQty(quantity),
      unit: unit,
    );
    return ActionOutcome(
      action: action,
      succeeded: true,
      message: 'Used ${unit.format(roundQty(quantity))} of ${item.name}.',
      undo: () => pantry.undoUse(result),
    );
  }

  Future<ActionOutcome> _markFinished(
    CommandAction action,
    _Pantry state,
  ) async {
    final Item? item = state.find(action);
    if (item == null) {
      return _notInPantry(action);
    }
    final ItemStock stock = StockLogic.summarize(
      state.record(item.id),
      today: dateOnlyOf(now()),
      warningDays: warningDays,
    );
    if (isZeroQty(stock.totalRemaining)) {
      return ActionOutcome(
        action: action,
        succeeded: true,
        message: '${item.name} was already finished.',
      );
    }
    UseResult result;
    try {
      result = await pantry.useStock(
        itemId: item.id,
        quantity: stock.totalRemaining,
        unit: item.defaultUnit,
      );
    } on InsufficientStockFailure catch (failure) {
      // Rounding: take exactly what the batches hold.
      result = await pantry.useStock(
        itemId: item.id,
        quantity: failure.available,
        unit: item.defaultUnit,
      );
    }
    return ActionOutcome(
      action: action,
      succeeded: true,
      message: '${item.name} marked as finished.',
      undo: () => pantry.undoUse(result),
    );
  }

  ActionOutcome _notInPantry(CommandAction action) {
    return ActionOutcome(
      action: action,
      succeeded: false,
      message: '${_label(action)} is not in your pantry.',
    );
  }

  // -------------------------------------------------------------- shopping

  Future<ActionOutcome> _addToList(
    CommandAction action,
    _Pantry state, {
    required String listId,
  }) async {
    final Item? item = state.find(action);
    final double quantity = roundQty(action.quantity ?? 1);
    if (quantity <= 0) {
      throw const InvalidInputFailure('The amount must be more than zero.');
    }
    final Unit unit =
        action.unit ?? item?.defaultUnit ?? action.typicalUnit ?? Unit.pcs;
    if (item != null && !unit.isCompatibleWith(item.defaultUnit)) {
      throw InvalidInputFailure(
        '${item.name} is counted in ${item.defaultUnit.symbol}, '
        'not ${unit.symbol}.',
      );
    }
    final List<ShoppingEntry> before = await shopping.watchEntries().first;
    final ShoppingEntry entry = await shopping.addEntry(
      ShoppingEntryDraft(
        listId: listId,
        itemId: item?.id,
        name: item?.name ?? action.itemName,
        quantity: quantity,
        unit: unit,
        addedReason: AddedReason.voice,
      ),
    );
    ShoppingEntry? previous;
    for (final ShoppingEntry e in before) {
      if (e.id == entry.id) {
        previous = e;
      }
    }
    final ShoppingEntry? merged = previous;
    return ActionOutcome(
      action: action,
      succeeded: true,
      message: 'Added ${unit.format(quantity)} ${entry.name} to your '
          'shopping list.',
      undo: () async {
        if (merged == null) {
          await shopping.deleteEntry(entry.id);
        } else {
          await shopping.updateEntry(merged);
        }
      },
    );
  }

  Future<ActionOutcome> _removeFromList(
    CommandAction action,
    _Pantry state, {
    required String listId,
  }) async {
    final Item? item = state.find(action);
    final String wanted = _key(item?.name ?? action.itemName);
    final List<ShoppingEntry> all = await shopping.watchEntries().first;
    bool matches(ShoppingEntry e) =>
        (item != null && e.itemId == item.id) || _key(e.name) == wanted;
    List<ShoppingEntry> found = <ShoppingEntry>[
      for (final ShoppingEntry e in all)
        if (e.listId == listId && matches(e)) e,
    ];
    if (found.isEmpty) {
      found = <ShoppingEntry>[
        for (final ShoppingEntry e in all)
          if (matches(e)) e,
      ];
    }
    if (found.isEmpty) {
      return ActionOutcome(
        action: action,
        succeeded: false,
        message: '${_label(action)} is not on your shopping list.',
      );
    }
    for (final ShoppingEntry e in found) {
      await shopping.deleteEntry(e.id);
    }
    final List<String> ids = <String>[for (final ShoppingEntry e in found) e.id];
    return ActionOutcome(
      action: action,
      succeeded: true,
      message: 'Removed ${item?.name ?? _label(action)} from your shopping '
          'list.',
      undo: () async {
        for (final String id in ids) {
          await shopping.undoDeleteEntry(id);
        }
      },
    );
  }

  // --------------------------------------------------------------- queries

  ActionOutcome _queryExpiring(CommandAction action, _Pantry state) {
    final DateTime today = dateOnlyOf(now());
    final List<String> lines = <String>[];
    for (final ItemWithBatches record in state.records) {
      final ItemStock stock = StockLogic.summarize(
        record,
        today: today,
        warningDays: warningDays,
      );
      if (stock.status != StatusKind.expiring &&
          stock.status != StatusKind.expired) {
        continue;
      }
      lines.add(
        '${record.item.name} (${stock.statusLabel ?? stock.status.label})',
      );
    }
    final String message = lines.isEmpty
        ? 'Nothing is expiring in the next $warningDays days.'
        : 'Use these first: ${lines.take(8).join(', ')}'
            '${lines.length > 8 ? ' and ${lines.length - 8} more' : ''}.';
    return ActionOutcome(action: action, succeeded: true, message: message);
  }

  ActionOutcome _queryStock(CommandAction action, _Pantry state) {
    final Item? item = state.find(action);
    if (item == null) {
      return _notInPantry(action);
    }
    final ItemStock stock = StockLogic.summarize(
      state.record(item.id),
      today: dateOnlyOf(now()),
      warningDays: warningDays,
    );
    final String left = isZeroQty(stock.totalRemaining)
        ? '${item.name}: none left.'
        : '${item.name}: ${stock.remainingLabel} left'
            '${stock.statusLabel == null ? '' : ' (${stock.statusLabel})'}.';
    return ActionOutcome(action: action, succeeded: true, message: left);
  }

  // --------------------------------------------------------------- helpers

  /// Adds the words the person used as an alias when they are new.
  Future<Item> _learnAlias(
    Item item,
    CommandAction action,
    _Pantry state,
  ) async {
    final List<String> aliases = _aliasesFor(action, existing: item.aliases);
    if (aliases.length == item.aliases.length) {
      return item;
    }
    final Item updated = await pantry.updateItem(
      Item(
        id: item.id,
        name: item.name,
        brand: item.brand,
        barcode: item.barcode,
        categoryId: item.categoryId,
        defaultUnit: item.defaultUnit,
        imagePath: item.imagePath,
        notes: item.notes,
        aliases: aliases,
        lowStockThreshold: item.lowStockThreshold,
        isEssential: item.isEssential,
        defaultStorageLocation: item.defaultStorageLocation,
        createdAt: item.createdAt,
        updatedAt: item.updatedAt,
        kind: item.kind,
        shelfLifeDays: item.shelfLifeDays,
      ),
    );
    state.replace(updated);
    return updated;
  }

  /// [existing] plus the person's own words, when those add something.
  static List<String> _aliasesFor(
    CommandAction action, {
    required List<String> existing,
  }) {
    final String word = action.originalText.trim();
    if (word.isEmpty) {
      return List<String>.of(existing);
    }
    final String wordKey = _key(word);
    if (wordKey == _key(action.itemName)) {
      return List<String>.of(existing);
    }
    for (final String alias in existing) {
      if (_key(alias) == wordKey) {
        return List<String>.of(existing);
      }
    }
    return <String>[...existing, word];
  }

  static String _key(String text) => phraseTokens(text).join(' ');

  static String _label(CommandAction action) {
    return action.itemName.isEmpty ? 'That item' : action.itemName;
  }

  static DateTime dateOnlyOf(DateTime d) => DateTime(d.year, d.month, d.day);
}

/// The pantry as it is while a command runs, kept up to date as items are
/// added so a later action in the same sentence finds them.
final class _Pantry {
  _Pantry(List<ItemWithBatches> records)
      : _records = <String, ItemWithBatches>{
          for (final ItemWithBatches r in records) r.item.id: r,
        };

  final Map<String, ItemWithBatches> _records;

  Iterable<ItemWithBatches> get records => _records.values;

  ItemWithBatches record(String itemId) => _records[itemId]!;

  void add(Item item) {
    _records[item.id] = ItemWithBatches(item: item, batches: const <StockBatch>[]);
  }

  void replace(Item item) {
    final ItemWithBatches? old = _records[item.id];
    _records[item.id] =
        ItemWithBatches(item: item, batches: old?.batches ?? const <StockBatch>[]);
  }

  /// The pantry item an action is about: by id, then by name or alias.
  Item? find(CommandAction action) {
    final String? id = action.itemId;
    if (id != null) {
      final ItemWithBatches? byId = _records[id];
      if (byId != null) {
        return byId.item;
      }
    }
    final String wanted = _key(action.itemName);
    final String heard = _key(action.originalText);
    for (final ItemWithBatches r in _records.values) {
      if (_key(r.item.name) == wanted) {
        return r.item;
      }
    }
    for (final ItemWithBatches r in _records.values) {
      for (final String alias in r.item.aliases) {
        final String a = _key(alias);
        if (a == wanted || (heard.isNotEmpty && a == heard)) {
          return r.item;
        }
      }
    }
    return null;
  }

  static String _key(String text) => phraseTokens(text).join(' ');
}
