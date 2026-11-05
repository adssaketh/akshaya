import 'dart:convert';

import '../../../core/util/date_only.dart';
import '../../../core/util/quantity.dart';
import '../../pantry/domain/entities.dart';
import '../../pantry/domain/stock_count.dart';
import '../../pantry/domain/storage_location.dart';
import '../../pantry/domain/unit.dart';

/// One item to check on the shelf: what the app expects to be there.
final class CountLine {
  const CountLine({
    required this.item,
    required this.expected,
    required this.batchCount,
    this.location,
  });

  final Item item;

  /// Expected quantity in the item's default unit, limited to [location] when
  /// the count covers one storage location.
  final double expected;

  /// How many batches make up [expected].
  final int batchCount;

  /// The storage location being counted, or null when counting everything.
  final StorageLocation? location;

  Unit get unit => item.defaultUnit;

  /// "2 kg".
  String get expectedLabel => unit.format(expected);
}

/// Works out which items a count walks through.
abstract final class CountPlanner {
  /// Items that hold stock inside [scope], by name. Items with nothing in
  /// stock there are left out: there is nothing on the shelf to check.
  static List<CountLine> lines(
    List<ItemWithBatches> records,
    CountScope scope,
  ) {
    final List<CountLine> out = <CountLine>[];
    for (final ItemWithBatches record in records) {
      final Item item = record.item;
      if (scope.kind == CountScopeKind.category &&
          item.categoryId != scope.categoryId) {
        continue;
      }
      double total = 0;
      int batches = 0;
      for (final StockBatch b in record.batches) {
        if (isZeroQty(b.quantityRemaining) ||
            !b.unit.isCompatibleWith(item.defaultUnit)) {
          continue;
        }
        if (scope.kind == CountScopeKind.location &&
            b.storageLocation != scope.location) {
          continue;
        }
        total += b.unit.convertTo(b.quantityRemaining, item.defaultUnit);
        batches++;
      }
      total = roundQty(total);
      if (batches == 0 || isZeroQty(total)) {
        continue;
      }
      out.add(
        CountLine(
          item: item,
          expected: total,
          batchCount: batches,
          location: scope.kind == CountScopeKind.location ? scope.location : null,
        ),
      );
    }
    out.sort(
      (CountLine a, CountLine b) =>
          a.item.name.toLowerCase().compareTo(b.item.name.toLowerCase()),
    );
    return out;
  }
}

/// What happened to one item during a count.
enum CountOutcomeKind {
  /// The shelf matched the app.
  matched('Matched'),

  /// More was found than expected.
  raised('Found more'),

  /// Less was found than expected (logged as an adjustment).
  lowered('Found less'),

  /// Nothing left (logged as an adjustment).
  finished('Finished'),

  /// Less was found and the missing amount was written off as waste.
  wasted('Wasted');

  const CountOutcomeKind(this.label);

  final String label;

  /// How a [CountResult] reads. [asWaste] is what the person chose for a
  /// shortfall.
  static CountOutcomeKind of(CountResult result, {required bool asWaste}) {
    if (!result.changed) {
      return CountOutcomeKind.matched;
    }
    if (result.difference > 0) {
      return CountOutcomeKind.raised;
    }
    if (asWaste) {
      return CountOutcomeKind.wasted;
    }
    return isZeroQty(result.after)
        ? CountOutcomeKind.finished
        : CountOutcomeKind.lowered;
  }
}

/// The result for one item, kept small so a whole count fits in one setting.
final class CountOutcome {
  const CountOutcome({
    required this.itemId,
    required this.name,
    required this.kind,
    required this.expected,
    required this.counted,
    required this.unit,
  });

  final String itemId;
  final String name;
  final CountOutcomeKind kind;

  /// What the app expected and what was found, both in [unit].
  final double expected;
  final double counted;
  final Unit unit;

  double get difference => roundQty(counted - expected);

  /// "+1 kg" or "-500 g"; empty when it matched.
  String get differenceLabel {
    final double d = difference;
    if (isZeroQty(d.abs())) {
      return '';
    }
    return d > 0 ? '+${unit.format(d)}' : '-${unit.format(-d)}';
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'i': itemId,
        'n': name,
        'k': kind.name,
        'e': expected,
        'c': counted,
        'u': unit.name,
      };

  /// Null when [json] is not a well-formed outcome.
  static CountOutcome? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      return null;
    }
    final Object? id = json['i'];
    final Object? name = json['n'];
    final Object? kind = json['k'];
    final Object? expected = json['e'];
    final Object? counted = json['c'];
    final Object? unit = json['u'];
    if (id is! String ||
        name is! String ||
        kind is! String ||
        expected is! num ||
        counted is! num ||
        unit is! String) {
      return null;
    }
    CountOutcomeKind? parsedKind;
    for (final CountOutcomeKind k in CountOutcomeKind.values) {
      if (k.name == kind) {
        parsedKind = k;
      }
    }
    Unit? parsedUnit;
    for (final Unit u in Unit.values) {
      if (u.name == unit) {
        parsedUnit = u;
      }
    }
    if (parsedKind == null || parsedUnit == null) {
      return null;
    }
    return CountOutcome(
      itemId: id,
      name: name,
      kind: parsedKind,
      expected: expected.toDouble(),
      counted: counted.toDouble(),
      unit: parsedUnit,
    );
  }
}

/// A count in progress. Every answer is already saved to the pantry; this
/// only remembers which items were dealt with so a count can be resumed.
final class CountSession {
  const CountSession({
    required this.scope,
    required this.startedOn,
    this.outcomes = const <String, CountOutcome>{},
    this.skipped = const <String>{},
  });

  final CountScope scope;
  final DateTime startedOn;

  /// Answers by item id.
  final Map<String, CountOutcome> outcomes;

  /// Items put off for later in this count.
  final Set<String> skipped;

  /// True when [itemId] has been answered or put off.
  bool isDone(String itemId) =>
      outcomes.containsKey(itemId) || skipped.contains(itemId);

  CountSession withOutcome(CountOutcome outcome) {
    return CountSession(
      scope: scope,
      startedOn: startedOn,
      outcomes: <String, CountOutcome>{...outcomes, outcome.itemId: outcome},
      skipped: <String>{...skipped}..remove(outcome.itemId),
    );
  }

  CountSession withSkipped(String itemId) {
    return CountSession(
      scope: scope,
      startedOn: startedOn,
      outcomes: <String, CountOutcome>{...outcomes}..remove(itemId),
      skipped: <String>{...skipped, itemId},
    );
  }

  /// Takes an item back into the queue (after Undo).
  CountSession without(String itemId) {
    return CountSession(
      scope: scope,
      startedOn: startedOn,
      outcomes: <String, CountOutcome>{...outcomes}..remove(itemId),
      skipped: <String>{...skipped}..remove(itemId),
    );
  }

  String encode() {
    return jsonEncode(<String, Object?>{
      'scope': scope.key,
      'started': formatIsoDate(startedOn),
      'outcomes': <Object?>[for (final CountOutcome o in outcomes.values) o.toJson()],
      'skipped': skipped.toList(),
    });
  }

  /// Reads [text] back; null when it is missing or damaged, so a bad saved
  /// value just means "no count to resume".
  static CountSession? decode(String? text) {
    if (text == null || text.isEmpty) {
      return null;
    }
    try {
      final Object? json = jsonDecode(text);
      if (json is! Map<String, dynamic>) {
        return null;
      }
      final CountScope? scope = CountScope.fromKey(json['scope'] as String?);
      final Object? started = json['started'];
      final DateTime? startedOn =
          started is String ? parseIsoDate(started) : null;
      if (scope == null || startedOn == null) {
        return null;
      }
      final Map<String, CountOutcome> outcomes = <String, CountOutcome>{};
      final Object? list = json['outcomes'];
      if (list is List<Object?>) {
        for (final Object? entry in list) {
          final CountOutcome? o = CountOutcome.fromJson(entry);
          if (o != null) {
            outcomes[o.itemId] = o;
          }
        }
      }
      final Set<String> skipped = <String>{};
      final Object? skippedList = json['skipped'];
      if (skippedList is List<Object?>) {
        for (final Object? id in skippedList) {
          if (id is String) {
            skipped.add(id);
          }
        }
      }
      return CountSession(
        scope: scope,
        startedOn: startedOn,
        outcomes: outcomes,
        skipped: skipped,
      );
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }
}

/// Totals for the end-of-count screen.
final class CountSummary {
  const CountSummary({
    required this.matched,
    required this.raised,
    required this.lowered,
    required this.finished,
    required this.wasted,
    required this.skipped,
    required this.changes,
  });

  factory CountSummary.of(CountSession session) {
    int matched = 0;
    int raised = 0;
    int lowered = 0;
    int finished = 0;
    int wasted = 0;
    for (final CountOutcome o in session.outcomes.values) {
      switch (o.kind) {
        case CountOutcomeKind.matched:
          matched++;
        case CountOutcomeKind.raised:
          raised++;
        case CountOutcomeKind.lowered:
          lowered++;
        case CountOutcomeKind.finished:
          finished++;
        case CountOutcomeKind.wasted:
          wasted++;
      }
    }
    final List<CountOutcome> changes = <CountOutcome>[
      for (final CountOutcome o in session.outcomes.values)
        if (o.kind != CountOutcomeKind.matched) o,
    ]..sort(
        (CountOutcome a, CountOutcome b) =>
            a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
    return CountSummary(
      matched: matched,
      raised: raised,
      lowered: lowered,
      finished: finished,
      wasted: wasted,
      skipped: session.skipped.length,
      changes: changes,
    );
  }

  final int matched;
  final int raised;
  final int lowered;
  final int finished;
  final int wasted;
  final int skipped;

  /// Every item whose stock was changed, by name.
  final List<CountOutcome> changes;

  int get checked => matched + raised + lowered + finished + wasted;
  int get changed => raised + lowered + finished + wasted;
}
