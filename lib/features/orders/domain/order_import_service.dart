import '../../commands/domain/grocery_lexicon.dart';
import '../../ai/domain/ai_failures.dart';
import '../../ai/domain/ai_gate.dart';
import '../../pantry/domain/storage_location.dart';
import 'ocr_models.dart';
import 'order_ai.dart';
import 'order_classifier.dart';
import 'order_models.dart';
import 'order_row_parser.dart';

/// Why the offline reader's answer is not good enough.
enum OrderDifficulty {
  /// Text was found but no product could be picked out of it (an app layout
  /// the reader does not know).
  noProducts,

  /// Most products could not be named from the offline dictionary.
  mostlyUnknown,
}

/// The result of reading one or more screenshots.
final class OrderScan {
  const OrderScan({
    required this.drafts,
    required this.lines,
    required this.pages,
    this.store,
    this.difficulty,
    this.usedAi = false,
  });

  /// What would be added, top to bottom.
  final List<OrderDraft> drafts;

  /// Every text line read, in screenshot order (for the AI fallback).
  final List<String> lines;
  final int pages;

  /// The shop's app, when its headings were recognised.
  final OrderStore? store;

  /// Set when the offline reading is weak enough to deserve a second opinion
  /// from AI.
  final OrderDifficulty? difficulty;

  /// True when [drafts] came from AI.
  final bool usedAi;

  bool get isHard => difficulty != null;
}

/// Reads order screenshots into a list of pantry additions.
///
/// The phone reads the text first ([ScreenshotReader]) and the products are
/// worked out offline. Only a page the offline reader cannot make sense of
/// goes to AI, and only when AI is on, within the daily cap, and the person
/// has seen the privacy notice (the caller asks for that before calling
/// [improveWithAi]).
final class OrderImportService {
  OrderImportService({
    required this.reader,
    required GroceryLexicon lexicon,
    this.ai,
    this.parser = const OrderRowParser(),
  }) : classifier = OrderClassifier(lexicon);

  final ScreenshotReader reader;
  final OrderRowParser parser;
  final OrderClassifier classifier;
  final OrderAiService? ai;

  /// Minimum products before "mostly unknown" is judged.
  static const int _minRowsToJudge = 3;

  /// Share of unknown products that makes a page "hard".
  static const double _unknownShare = 0.6;

  /// Why AI can or cannot be used right now.
  Future<AiAvailability?> aiAvailability() async => ai?.availability();

  /// Reads [paths] offline. Throws when a file cannot be read.
  Future<OrderScan> scan(List<String> paths) async {
    final List<OrderRow> rows = <OrderRow>[];
    final List<String> lines = <String>[];
    final Set<String> seen = <String>{};
    int textLines = 0;
    for (final String path in paths) {
      final OcrPage page = await reader.read(path);
      final OrderRowsResult result = parser.parse(page);
      textLines += result.textLines;
      final List<OcrLine> ordered = List<OcrLine>.of(page.lines)
        ..sort((OcrLine a, OcrLine b) => a.top.compareTo(b.top));
      lines.addAll(ordered.map((OcrLine l) => l.text.trim()));
      for (final OrderRow row in result.rows) {
        // Screenshots of a long order overlap; one product is listed once.
        if (seen.add(_key(row))) {
          rows.add(row);
        }
      }
    }
    final List<_Built> built = <_Built>[
      for (int i = 0; i < rows.length; i++) _build(rows[i], i),
    ];
    return OrderScan(
      drafts: <OrderDraft>[for (final _Built b in built) b.draft],
      lines: lines,
      pages: paths.length,
      store: OrderStore.guess(lines),
      difficulty: _difficulty(built, textLines),
    );
  }

  /// Asks AI to read the text of [scan] again. Returns a scan with the AI's
  /// products when they are at least as many as the offline ones, otherwise
  /// [scan] unchanged. Throws an [AiFailure].
  Future<OrderScan> improveWithAi(OrderScan scan) async {
    final OrderAiService? service = ai;
    if (service == null) {
      throw const AiServiceFailure();
    }
    final List<OrderAiItem> items = await service.read(scan.lines);
    if (items.isEmpty || items.length < scan.drafts.length) {
      return scan;
    }
    final List<OrderDraft> drafts = <OrderDraft>[
      for (int i = 0; i < items.length; i++)
        _build(
          items[i].row,
          i,
          aiCategory: items[i].categoryId,
          aiFood: items[i].isFood,
        ).draft,
    ];
    return OrderScan(
      drafts: drafts,
      lines: scan.lines,
      pages: scan.pages,
      store: scan.store,
      usedAi: true,
    );
  }

  OrderDifficulty? _difficulty(List<_Built> built, int textLines) {
    if (built.isEmpty) {
      return textLines >= 5 ? OrderDifficulty.noProducts : null;
    }
    if (built.length >= _minRowsToJudge) {
      final int unknown = built
          .where((_Built b) =>
              b.draft.skip == null &&
              !b.recognised &&
              !b.draft.notes.contains(DraftNote.nameCutOff))
          .length;
      if (unknown / built.length >= _unknownShare) {
        return OrderDifficulty.mostlyUnknown;
      }
    }
    return null;
  }

  _Built _build(
    OrderRow row,
    int index, {
    String? aiCategory,
    bool aiFood = true,
  }) {
    final OrderClassification c = classifier.classify(
      row.rawName,
      hints: row.hints,
      truncated: row.truncated,
    );
    SkipReason? skip = c.skip;
    String category = c.categoryId;
    if (!c.matched && aiCategory != null && skip == null) {
      category = aiCategory;
    }
    if (!aiFood && skip == null) {
      skip = SkipReason.notFood;
    }
    final String id = 'd$index';
    final List<DraftNote> notes = <DraftNote>[
      if (row.truncated && !c.matched) DraftNote.nameCutOff,
      if (!row.sizeKnown && skip == null) DraftNote.amountNotShown,
      if (row.price == null && skip == null) DraftNote.priceNotFound,
    ];
    final StorageLocation location = c.location;
    final OrderDraft draft = OrderDraft(
      id: id,
      sourceName: row.rawName,
      name: c.name,
      brand: c.brand,
      quantity: row.quantity,
      unit: row.unit,
      price: row.price,
      categoryId: category,
      location: location,
      estimateDays: c.estimateDays,
      include: skip == null,
      skip: skip,
      matchedItemId: c.matchedItemId,
      notes: notes,
    );
    return _Built(draft, c.matched);
  }

  static String _key(OrderRow row) {
    return '${row.rawName.toLowerCase()}|${row.quantity}|${row.unit.name}|'
        '${row.price}';
  }
}

/// A draft and whether the dictionary or pantry recognised the product.
final class _Built {
  const _Built(this.draft, this.recognised);

  final OrderDraft draft;
  final bool recognised;
}
