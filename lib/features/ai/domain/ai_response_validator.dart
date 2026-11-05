import 'dart:convert';

import '../../../core/util/date_only.dart';
import '../../pantry/domain/storage_location.dart';
import '../../pantry/domain/unit.dart';
import '../../commands/domain/command_models.dart';
import 'ai_failures.dart';

/// Checks the JSON the AI returns against the agreed schema:
///
/// `{"actions":[{"intent","item_name_en","original_text","quantity","unit",
/// "expiry_date","storage_location"}]}`
///
/// Anything that does not fit is rejected as a whole, because a half-trusted
/// answer is worse than the offline parser. The result is only ever shown on a
/// confirmation card; nothing is executed from it unconfirmed.
abstract final class AiResponseValidator {
  static const int maxActions = 20;
  static const int maxNameLength = 80;
  static const double maxQuantity = 100000;

  static const Map<String, Unit> _unitNames = <String, Unit>{
    'pcs': Unit.pcs,
    'pc': Unit.pcs,
    'piece': Unit.pcs,
    'pieces': Unit.pcs,
    'g': Unit.g,
    'gm': Unit.g,
    'gram': Unit.g,
    'grams': Unit.g,
    'kg': Unit.kg,
    'kgs': Unit.kg,
    'kilo': Unit.kg,
    'kilogram': Unit.kg,
    'kilograms': Unit.kg,
    'ml': Unit.ml,
    'l': Unit.l,
    'lt': Unit.l,
    'ltr': Unit.l,
    'liter': Unit.l,
    'litre': Unit.l,
    'liters': Unit.l,
    'litres': Unit.l,
    'packet': Unit.packet,
    'packets': Unit.packet,
    'pack': Unit.packet,
    'dozen': Unit.dozen,
    'bunch': Unit.bunch,
    'bunches': Unit.bunch,
  };

  static final RegExp _datePattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');
  static final RegExp _controlChars = RegExp(r'[\u0000-\u001F\u007F]');

  /// The unit the AI (or a saved recipe) means by [text] ("kg", "litre",
  /// "pcs"...), or null when it is not one of the app's units. Other AI
  /// features share this spelling table.
  static Unit? parseUnit(String text) => _unitNames[text.trim().toLowerCase()];

  /// Turns the AI's JSON text into actions, or throws
  /// [AiInvalidResponseFailure].
  static List<CommandAction> parse(String text) {
    final Object? decoded;
    try {
      decoded = jsonDecode(_stripFences(text));
    } on FormatException {
      throw const AiInvalidResponseFailure('not JSON');
    }
    if (decoded is! Map<String, Object?>) {
      throw const AiInvalidResponseFailure('not an object');
    }
    final Object? rawActions = decoded['actions'];
    if (rawActions is! List<Object?>) {
      throw const AiInvalidResponseFailure('no actions list');
    }
    if (rawActions.length > maxActions) {
      throw const AiInvalidResponseFailure('too many actions');
    }
    return <CommandAction>[
      for (final Object? raw in rawActions) _parseAction(raw),
    ];
  }

  static CommandAction _parseAction(Object? raw) {
    if (raw is! Map<String, Object?>) {
      throw const AiInvalidResponseFailure('action is not an object');
    }
    final Object? intentText = raw['intent'];
    final CommandIntent? intent =
        intentText is String ? CommandIntent.fromKey(intentText) : null;
    if (intent == null) {
      throw AiInvalidResponseFailure('unknown intent: $intentText');
    }

    final Object? nameRaw = raw['item_name_en'];
    String name = '';
    if (nameRaw is String) {
      name = nameRaw.replaceAll(_controlChars, ' ').trim();
    } else if (nameRaw != null) {
      throw const AiInvalidResponseFailure('item name is not text');
    }
    if (name.length > maxNameLength) {
      throw const AiInvalidResponseFailure('item name too long');
    }
    if (intent.needsItem && name.isEmpty) {
      throw const AiInvalidResponseFailure('item name missing');
    }

    final Object? originalRaw = raw['original_text'];
    final String original = originalRaw is String
        ? originalRaw.replaceAll(_controlChars, ' ').trim()
        : '';

    double? quantity;
    final Object? quantityRaw = raw['quantity'];
    if (quantityRaw != null) {
      if (quantityRaw is! num ||
          !quantityRaw.isFinite ||
          quantityRaw <= 0 ||
          quantityRaw > maxQuantity) {
        throw const AiInvalidResponseFailure('bad quantity');
      }
      quantity = quantityRaw.toDouble();
    }

    Unit? unit;
    final Object? unitRaw = raw['unit'];
    if (unitRaw != null) {
      if (unitRaw is! String) {
        throw const AiInvalidResponseFailure('bad unit');
      }
      if (unitRaw.trim().isNotEmpty) {
        unit = _unitNames[unitRaw.trim().toLowerCase()];
        if (unit == null) {
          throw AiInvalidResponseFailure('unknown unit: $unitRaw');
        }
      }
    }

    DateTime? expiry;
    final Object? expiryRaw = raw['expiry_date'];
    if (expiryRaw != null) {
      if (expiryRaw is! String) {
        throw const AiInvalidResponseFailure('bad date');
      }
      if (expiryRaw.trim().isNotEmpty) {
        expiry = _parseDate(expiryRaw.trim());
      }
    }

    StorageLocation? location;
    final Object? locationRaw = raw['storage_location'];
    if (locationRaw != null) {
      if (locationRaw is! String) {
        throw const AiInvalidResponseFailure('bad location');
      }
      if (locationRaw.trim().isNotEmpty) {
        final String wanted = locationRaw.trim().toLowerCase();
        for (final StorageLocation candidate in StorageLocation.values) {
          if (candidate.name == wanted) {
            location = candidate;
          }
        }
        if (location == null) {
          throw AiInvalidResponseFailure('unknown location: $locationRaw');
        }
      }
    }

    return CommandAction(
      intent: intent,
      itemName: name,
      originalText: original,
      quantity: quantity,
      unit: unit,
      expiryDate: expiry,
      storageLocation: location,
    );
  }

  static DateTime _parseDate(String text) {
    final Match? m = _datePattern.firstMatch(text);
    if (m == null) {
      throw AiInvalidResponseFailure('bad date: $text');
    }
    final int year = int.parse(m.group(1)!);
    final int month = int.parse(m.group(2)!);
    final int day = int.parse(m.group(3)!);
    final DateTime date = DateTime(year, month, day);
    // DateTime rolls 31 Feb over to March; reject such dates.
    if (date.year != year || date.month != month || date.day != day) {
      throw AiInvalidResponseFailure('impossible date: $text');
    }
    return dateOnly(date);
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
