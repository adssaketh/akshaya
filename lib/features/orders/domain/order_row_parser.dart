import '../../../core/util/quantity.dart';
import '../../pantry/domain/unit.dart';
import 'ocr_models.dart';
import 'order_models.dart';

/// What one screenshot gave.
final class OrderRowsResult {
  const OrderRowsResult({
    required this.rows,
    required this.priceLines,
    required this.textLines,
  });

  /// The products found, top to bottom.
  final List<OrderRow> rows;

  /// How many lines looked like prices (a hint that products are there even
  /// when none could be paired up).
  final int priceLines;
  final int textLines;
}

/// Turns the text lines of an order screenshot into products, using where each
/// line sits on the screen.
///
/// Two layouts are understood, which together cover Blinkit, Zepto,
/// Amazon Now, Swiggy Instamart and Flipkart Minutes:
///
/// * a name (one to three lines), then a pack line such as `1 kg x 1`,
///   `1 pc (500 ml) . 2 units`, `100 g . 2 units` or `1 x 500 ml`, with the
///   price on the right (a struck-through price may sit beside or under it);
/// * one line per product, `1 x Garlic`, with the price on the right.
///
/// Pure Dart, no Flutter.
final class OrderRowParser {
  const OrderRowParser();

  /// Prices sit in the right part of the screen, names in the left part.
  static const double _rightColumn = 0.42;

  static const String _num = r'(\d+(?:\.\d+)?)';
  static const String _size = r'(?:kgs?|gms?|grams?|g|ml|ltrs?|litres?|liters?|l)\b';
  static const String _pcs = r'(?:pcs?|pieces?|packs?|packets?|units?)';
  // Between "(500 ml)" and "2 units": a bullet, or whatever the text reader
  // made of it (a dot, a lone "e" or "o"), or just spaces.
  static const String _sep = r'(?:\s|[^\w\s]|(?<=\s)[eo](?=\s))*';

  // 1 pc (500 ml) . 2 units      1 pack (10 pcs) . 1 unit
  static final RegExp _packInBrackets = RegExp(
    '^$_num\\s*$_pcs\\s*\\(\\s*$_num\\s*($_size|pcs?)\\s*\\)$_sep(\\d+)\\s*units?\\b',
    caseSensitive: false,
  );
  // 100 g . 2 units
  static final RegExp _sizeUnits = RegExp(
    '^$_num\\s*($_size)$_sep(\\d+)\\s*units?\\b',
    caseSensitive: false,
  );
  // 1 kg x 1
  static final RegExp _sizeTimes = RegExp(
    '^$_num\\s*($_size)\\s*[x×]\\s*(\\d+)\\b',
    caseSensitive: false,
  );
  // 1 x 500 ml      1 x 400-450g
  static final RegExp _timesSize = RegExp(
    '^(\\d+)\\s*[x×]\\s*$_num(?:\\s*-\\s*\\d+(?:\\.\\d+)?)?\\s*($_size)',
    caseSensitive: false,
  );
  // 1 pack . 1 unit      (no size shown)
  static final RegExp _packOnly = RegExp(
    '^$_num\\s*($_pcs)\\b$_sep(\\d+)\\s*units?\\b',
    caseSensitive: false,
  );

  // 1 x Garlic       (a leading tick mark may be read as a letter or symbol)
  static final RegExp _inlineItem = RegExp(
    r'^\W*(?:[a-z]\s+)?(\d+)\s*[x×]\s*(.+)$',
    caseSensitive: false,
  );

  static final RegExp _priceLine = RegExp(
    r'^[₹?\sRs.]*\d[\d,]*(?:\.\d{1,2})?'
    r'(?:\s*[₹?]?\s*\d[\d,]*(?:\.\d{1,2})?)*\s*(?:\+.*)?$',
  );
  static final RegExp _numbers = RegExp(r'\d[\d,]*(?:\.\d+)?');
  static final RegExp _letter = RegExp('[A-Za-z]');
  static final RegExp _trailingDots = RegExp(r'[….]+$');

  static final List<RegExp> _noise = <RegExp>[
    RegExp(r'^\d{1,2}:\d{2}$'),
    RegExp(r'kb/s', caseSensitive: false),
    RegExp(r'^\d+\s*items?\b', caseSensitive: false),
    RegExp(r'items?\s+in\s+(this\s+)?order', caseSensitive: false),
    RegExp(r'^order\b', caseSensitive: false),
    RegExp(r'^arrived\s+at', caseSensitive: false),
    RegExp(r'^delivered', caseSensitive: false),
    RegExp(r'download\s+invoice', caseSensitive: false),
    RegExp(r'^get\s+help$', caseSensitive: false),
    RegExp(r'^help$', caseSensitive: false),
    RegExp(r'rate\s+order', caseSensitive: false),
    RegExp(r'bill\s+(summary|details)', caseSensitive: false),
    RegExp(r'^total\b', caseSensitive: false),
    RegExp(r'item\s+bill', caseSensitive: false),
    RegExp(r'delivery\s+fee', caseSensitive: false),
    RegExp(r'handling\s+fee', caseSensitive: false),
    RegExp(r'grand\s+total', caseSensitive: false),
    RegExp(r'free\s+cash', caseSensitive: false),
    RegExp(r'discount', caseSensitive: false),
    RegExp(r'^delivery$', caseSensitive: false),
    RegExp(r'^completed\b', caseSensitive: false),
  ];

  /// True for headings, status-bar text and bill lines that are never part of
  /// a product.
  static bool isNoise(String text) {
    final String t = text.trim();
    return _noise.any((RegExp pattern) => pattern.hasMatch(t));
  }

  OrderRowsResult parse(OcrPage page) {
    final double width = page.width;
    final List<OcrLine> lines = <OcrLine>[
      for (final OcrLine line in page.lines)
        if (line.text.trim().isNotEmpty) line,
    ];
    final Set<OcrLine> prices = <OcrLine>{
      for (final OcrLine line in lines)
        if (line.left >= _rightColumn * width &&
            _priceLine.hasMatch(line.text.trim()) &&
            !isNoise(line.text))
          line,
    };
    final Map<OcrLine, _Spec> specs = <OcrLine, _Spec>{};
    for (final OcrLine line in lines) {
      if (line.left < _rightColumn * width && !isNoise(line.text)) {
        final _Spec? spec = _spec(line.text);
        if (spec != null) {
          specs[line] = spec;
        }
      }
    }
    final List<OrderRow> rows = specs.isNotEmpty
        ? _packLineRows(width, lines, prices, specs)
        : _inlineRows(width, lines, prices);
    return OrderRowsResult(
      rows: rows,
      priceLines: prices.length,
      textLines: lines.length,
    );
  }

  // ------------------------------------------------------------ pack lines

  List<OrderRow> _packLineRows(
    double width,
    List<OcrLine> lines,
    Set<OcrLine> prices,
    Map<OcrLine, _Spec> specs,
  ) {
    final List<OcrLine> specLines = specs.keys.toList()
      ..sort((OcrLine a, OcrLine b) => a.top.compareTo(b.top));
    final double lineH = _median(<double>[
      for (final OcrLine s in specLines) s.height,
    ]);
    final double nameLeft = _median(<double>[
      for (final OcrLine s in specLines) s.left,
    ]);
    final double tolerance = 0.03 * width;

    bool nameOk(OcrLine x) {
      return !specs.containsKey(x) &&
          !prices.contains(x) &&
          !isNoise(x.text) &&
          x.left >= nameLeft - tolerance &&
          x.left < 0.8 * width &&
          _letter.allMatches(x.text).length >= 2;
    }

    final List<OrderRow> rows = <OrderRow>[];
    double previousBottom = double.negativeInfinity;
    for (final OcrLine spec in specLines) {
      // The name is the lines just above the pack line, but not further up
      // than the previous product's pack line, and each line no more than
      // about one line-height away from the next.
      final List<OcrLine> candidates = <OcrLine>[
        for (final OcrLine x in lines)
          if (nameOk(x) &&
              x.bottom <= spec.top + 0.5 * lineH &&
              x.top >= previousBottom)
            x,
      ]..sort((OcrLine a, OcrLine b) => b.bottom.compareTo(a.bottom));
      final List<OcrLine> chosen = <OcrLine>[];
      double edge = spec.top;
      for (final OcrLine c in candidates) {
        if (edge - c.bottom <= 1.5 * lineH && chosen.length < 3) {
          chosen.add(c);
          edge = c.top;
        } else {
          break;
        }
      }
      final List<OcrLine> ordered = chosen.reversed.toList();
      final String joined =
          ordered.map((OcrLine c) => c.text.trim()).join(' ').trim();
      final double top = ordered.isEmpty ? spec.top : ordered.first.top;
      final double bandStart = top - 0.5 * lineH;
      final double bandEnd = spec.bottom + 0.5 * lineH;

      final List<OcrLine> inBand = <OcrLine>[
        for (final OcrLine p in prices)
          if (p.centerY >= bandStart && p.centerY <= bandEnd) p,
      ];
      final List<double> amounts = <double>[];
      for (final OcrLine p in inBand) {
        // "86 + (coin) 5": the coin count after the plus is not a price.
        final bool coin = inBand.any(
          (OcrLine q) =>
              !identical(q, p) &&
              (q.centerY - p.centerY).abs() < 0.6 * lineH &&
              q.right <= p.left &&
              q.text.trim().endsWith('+'),
        );
        if (!coin) {
          amounts.addAll(_amounts(p.text));
        }
      }
      final _Spec s = specs[spec]!;
      // A price on the same text line as the pack line.
      if (s.tail.trim().isNotEmpty) {
        amounts.addAll(_amounts(s.tail));
      }
      final List<String> hints = <String>[
        for (final OcrLine x in lines)
          if (x.right <= nameLeft &&
              x.centerY >= bandStart &&
              x.centerY <= bandEnd &&
              !isNoise(x.text))
            x.text.trim(),
      ];
      final bool truncated = joined.endsWith('…') || joined.endsWith('..');
      final String name =
          truncated ? joined.replaceAll(_trailingDots, '').trim() : joined;
      rows.add(
        OrderRow(
          rawName: name,
          quantity: roundQty(s.quantity),
          unit: s.unit,
          sizeKnown: s.sized,
          price: amounts.isEmpty ? null : _lowest(amounts),
          truncated: truncated,
          hints: hints,
        ),
      );
      previousBottom = spec.bottom;
    }
    return rows;
  }

  // ---------------------------------------------------------- inline lines

  List<OrderRow> _inlineRows(
    double width,
    List<OcrLine> lines,
    Set<OcrLine> prices,
  ) {
    final List<OcrLine> sorted = List<OcrLine>.of(lines)
      ..sort((OcrLine a, OcrLine b) => a.top.compareTo(b.top));
    final List<OrderRow> rows = <OrderRow>[];
    for (final OcrLine line in sorted) {
      if (line.left >= _rightColumn * width || isNoise(line.text)) {
        continue;
      }
      final RegExpMatch? m = _inlineItem.firstMatch(line.text.trim());
      if (m == null) {
        continue;
      }
      String name = m.group(2)!.trim();
      if (_letter.allMatches(name).length < 2) {
        continue;
      }
      final List<double> amounts = <double>[];
      for (final OcrLine p in prices) {
        if ((p.centerY - line.centerY).abs() <= 0.8 * line.height) {
          amounts.addAll(_amounts(p.text));
        }
      }
      final bool truncated = name.endsWith('…') || name.endsWith('..');
      if (truncated) {
        name = name.replaceAll(_trailingDots, '').trim();
      }
      rows.add(
        OrderRow(
          rawName: name,
          quantity: double.parse(m.group(1)!),
          unit: Unit.packet,
          sizeKnown: false,
          price: amounts.isEmpty ? null : _lowest(amounts),
          truncated: truncated,
        ),
      );
    }
    return rows;
  }

  // --------------------------------------------------------------- helpers

  /// The numbers before a "+" (what follows is the coin count).
  static List<double> _amounts(String text) {
    final int plus = text.indexOf('+');
    final String head = plus < 0 ? text : text.substring(0, plus);
    final List<double> out = <double>[];
    for (final RegExpMatch m in _numbers.allMatches(head)) {
      final double? value = double.tryParse(m.group(0)!.replaceAll(',', ''));
      if (value != null && value > 0) {
        out.add(value);
      }
    }
    return out;
  }

  /// The paid price is the lower one when an old price is shown too.
  static double _lowest(List<double> values) {
    double best = values.first;
    for (final double v in values) {
      if (v < best) {
        best = v;
      }
    }
    return best;
  }

  static double _median(List<double> values) {
    final List<double> sorted = List<double>.of(values)..sort();
    final int mid = sorted.length ~/ 2;
    return sorted.length.isOdd
        ? sorted[mid]
        : (sorted[mid - 1] + sorted[mid]) / 2;
  }

  static Unit _unitOf(String raw) {
    final String s = raw.toLowerCase();
    if (s.startsWith('kg')) {
      return Unit.kg;
    }
    if (s.startsWith('gm') || s.startsWith('gram') || s == 'g') {
      return Unit.g;
    }
    if (s == 'ml') {
      return Unit.ml;
    }
    if (s == 'l' || s.startsWith('lit') || s.startsWith('ltr')) {
      return Unit.l;
    }
    return Unit.pcs;
  }

  /// 1000 g is shown as 1 kg and 1500 ml as 1.5 L.
  static _Spec _spec2(double quantity, Unit unit, bool sized, String tail) {
    if (unit == Unit.g && quantity >= 1000) {
      return _Spec(quantity / 1000, Unit.kg, sized, tail);
    }
    if (unit == Unit.ml && quantity >= 1000) {
      return _Spec(quantity / 1000, Unit.l, sized, tail);
    }
    return _Spec(quantity, unit, sized, tail);
  }

  static _Spec? _spec(String raw) {
    final String t = raw.trim().replaceAll('×', 'x');
    RegExpMatch? m = _packInBrackets.firstMatch(t);
    if (m != null) {
      final double packs = double.parse(m.group(1)!);
      final double size = double.parse(m.group(2)!);
      final double units = double.parse(m.group(4)!);
      return _spec2(
        packs * size * units,
        _unitOf(m.group(3)!),
        true,
        t.substring(m.end),
      );
    }
    m = _sizeUnits.firstMatch(t);
    if (m != null) {
      return _spec2(
        double.parse(m.group(1)!) * double.parse(m.group(3)!),
        _unitOf(m.group(2)!),
        true,
        t.substring(m.end),
      );
    }
    m = _sizeTimes.firstMatch(t);
    if (m != null) {
      return _spec2(
        double.parse(m.group(1)!) * double.parse(m.group(3)!),
        _unitOf(m.group(2)!),
        true,
        t.substring(m.end),
      );
    }
    m = _timesSize.firstMatch(t);
    if (m != null) {
      return _spec2(
        double.parse(m.group(1)!) * double.parse(m.group(2)!),
        _unitOf(m.group(3)!),
        true,
        t.substring(m.end),
      );
    }
    m = _packOnly.firstMatch(t);
    if (m != null) {
      final String word = m.group(2)!.toLowerCase();
      return _Spec(
        double.parse(m.group(1)!) * double.parse(m.group(3)!),
        word.startsWith('pack') ? Unit.packet : Unit.pcs,
        false,
        t.substring(m.end),
      );
    }
    return null;
  }
}

/// What a pack line says.
final class _Spec {
  const _Spec(this.quantity, this.unit, this.sized, this.tail);

  final double quantity;
  final Unit unit;
  final bool sized;

  /// Text after the pack line on the same text line (sometimes a price).
  final String tail;
}
