import 'dart:convert';

import '../../../core/util/quantity.dart';
import '../../ai/domain/ai_command_service.dart';
import '../../ai/domain/ai_failures.dart';
import '../../ai/domain/ai_gate.dart';
import '../../ai/domain/ai_response_validator.dart';
import '../../pantry/domain/default_categories.dart';
import '../../pantry/domain/unit.dart';
import 'order_models.dart';
import 'order_row_parser.dart';

/// The bit that asks Gemini (through Firebase AI Logic) to read the text of an
/// order screenshot. Tests replace it with a fake.
abstract interface class OrderBackend {
  /// Sends [prompt] and returns the JSON text of the answer.
  Future<String> parseOrderJson(String prompt);
}

/// One product Gemini found.
final class OrderAiItem {
  const OrderAiItem({
    required this.row,
    required this.isFood,
    this.categoryId,
  });

  final OrderRow row;
  final bool isFood;

  /// One of the app's category ids, when Gemini gave a valid one.
  final String? categoryId;
}

/// Checks the JSON Gemini returns for an order:
///
/// `{"items":[{"name","brand","quantity","unit","price","category","is_food"}]}`
///
/// An item that does not fit is left out; when none fits, the whole answer is
/// rejected.
abstract final class OrderAiValidator {
  static const int maxItems = 60;
  static const int maxNameLength = 80;
  static const double maxQuantity = 100000;
  static const double maxPrice = 1000000;

  static final RegExp _controlChars = RegExp(r'[\u0000-\u001F\u007F]');

  static List<OrderAiItem> parse(String text) {
    final Object? decoded;
    try {
      decoded = jsonDecode(_stripFences(text));
    } on FormatException {
      throw const AiInvalidResponseFailure('not JSON');
    }
    if (decoded is! Map<String, Object?>) {
      throw const AiInvalidResponseFailure('not an object');
    }
    final Object? raw = decoded['items'];
    if (raw is! List<Object?>) {
      throw const AiInvalidResponseFailure('no items list');
    }
    final List<OrderAiItem> out = <OrderAiItem>[];
    for (final Object? entry in raw) {
      final OrderAiItem? item = _item(entry);
      if (item != null) {
        out.add(item);
      }
      if (out.length >= maxItems) {
        break;
      }
    }
    if (raw.isNotEmpty && out.isEmpty) {
      throw const AiInvalidResponseFailure('no valid item');
    }
    return out;
  }

  static OrderAiItem? _item(Object? raw) {
    if (raw is! Map<String, Object?>) {
      return null;
    }
    final Object? nameRaw = raw['name'];
    if (nameRaw is! String) {
      return null;
    }
    final String name =
        nameRaw.replaceAll(_controlChars, ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    if (name.isEmpty || name.length > maxNameLength) {
      return null;
    }
    final Object? q = raw['quantity'];
    final bool quantityGiven =
        q is num && q.isFinite && q > 0 && q <= maxQuantity;
    double quantity = quantityGiven ? q.toDouble() : 1;
    Unit unit = Unit.pcs;
    bool sized = false;
    final Object? u = raw['unit'];
    if (u is String) {
      final Unit? parsed = AiResponseValidator.parseUnit(u);
      if (parsed != null) {
        unit = parsed;
        sized = quantityGiven;
      }
    }
    quantity = roundQty(quantity);
    final Object? p = raw['price'];
    final double? price =
        p is num && p.isFinite && p > 0 && p <= maxPrice ? p.toDouble() : null;
    final Object? brandRaw = raw['brand'];
    String? brand;
    if (brandRaw is String) {
      final String b = brandRaw.replaceAll(_controlChars, ' ').trim();
      if (b.isNotEmpty && b.length <= maxNameLength) {
        brand = b;
      }
    }
    final Object? c = raw['category'];
    String? category;
    if (c is String &&
        kDefaultCategories.any((DefaultCategory d) => d.id == c)) {
      category = c;
    }
    final Object? f = raw['is_food'];
    final bool isFood = f is! bool || f;
    return OrderAiItem(
      row: OrderRow(
        rawName: brand == null ? name : '$brand $name',
        quantity: quantity,
        unit: unit,
        sizeKnown: sized,
        price: price,
      ),
      isFood: isFood,
      categoryId: category,
    );
  }

  static String _stripFences(String text) {
    String t = text.trim();
    if (t.startsWith('```')) {
      final int firstNewline = t.indexOf('\n');
      if (firstNewline != -1) {
        t = t.substring(firstNewline + 1);
      }
      if (t.endsWith('```')) {
        t = t.substring(0, t.length - 3);
      }
    }
    return t.trim();
  }
}

/// Fills in the prompt template (`assets/prompts/parse_order.txt`).
///
/// Only the product lines of the screenshot are sent: lines that look like an
/// address, a phone number or a name are dropped first.
abstract final class OrderPromptBuilder {
  static const int maxLines = 120;
  static const int maxLineLength = 100;

  static final RegExp _sensitive = RegExp(
    r'\b(address|flat|floor|house|road|street|nagar|colony|apartment|'
    r'block|pin\s*code|phone|mobile|call|otp|email|@|deliver(?:ed)?\s+to|'
    r'hyderabad|bengaluru|bangalore|mumbai|delhi|chennai|pune)\b|@|\d{6,}',
    caseSensitive: false,
  );
  static final RegExp _controlChars = RegExp(r'[\u0000-\u001F\u007F]');

  /// The lines of [texts] that may leave the phone.
  static List<String> safeLines(Iterable<String> texts) {
    final List<String> out = <String>[];
    for (final String raw in texts) {
      final String line = raw.replaceAll(_controlChars, ' ').trim();
      if (line.isEmpty ||
          line.length > maxLineLength ||
          OrderRowParser.isNoise(line) ||
          _sensitive.hasMatch(line)) {
        continue;
      }
      out.add(line);
      if (out.length >= maxLines) {
        break;
      }
    }
    return out;
  }

  static String build(String template, {required List<String> lines}) {
    final String text = safeLines(lines).join('\n');
    return template.replaceAll('{{text}}', text);
  }
}

/// Asks Gemini to read an order that the offline reader could not make sense
/// of.
///
/// The call goes through the same gate as every other AI feature ([guard]):
/// the on/off switch, the privacy notice, the one daily cap, the quota
/// cooldown and the retries. The caller gets either validated products or an
/// [AiFailure], and carries on with what the offline reader found.
final class OrderAiService {
  OrderAiService({
    required this.guard,
    required this.backend,
    required this.promptTemplate,
    this.timeout = const Duration(seconds: 30),
  });

  final AiCommandService guard;
  final OrderBackend backend;
  final String promptTemplate;
  final Duration timeout;

  Future<AiAvailability> availability() => guard.availability();

  /// Products found in [lines] (the text lines of the screenshot, top to
  /// bottom). Throws an [AiFailure].
  Future<List<OrderAiItem>> read(List<String> lines) async {
    final List<String> safe = OrderPromptBuilder.safeLines(lines);
    if (safe.isEmpty) {
      throw const AiInvalidResponseFailure('no text to send');
    }
    final String prompt =
        OrderPromptBuilder.build(promptTemplate, lines: safe);
    final String answer = await guard.guardedCall(
      () => backend.parseOrderJson(prompt),
      timeout: timeout,
    );
    // An answer that cannot be used is not retried: that would only burn the
    // daily cap.
    return OrderAiValidator.parse(answer);
  }
}
