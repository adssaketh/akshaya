import 'package:akshaya/features/ai/domain/ai_failures.dart';
import 'package:akshaya/features/ai/domain/ai_response_validator.dart';
import 'package:akshaya/features/commands/domain/command_models.dart';
import 'package:akshaya/features/pantry/domain/storage_location.dart';
import 'package:akshaya/features/pantry/domain/unit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  List<CommandAction> parse(String json) => AiResponseValidator.parse(json);

  void rejects(String json, {String? why}) {
    expect(
      () => parse(json),
      throwsA(isA<AiInvalidResponseFailure>()),
      reason: why ?? json,
    );
  }

  test('accepts a full, valid action', () {
    final List<CommandAction> actions = parse(
      '{"actions":[{"intent":"add_stock","item_name_en":"Rice",'
      '"original_text":"biyyam","quantity":2,"unit":"kg",'
      '"expiry_date":"2027-01-31","storage_location":"pantry"}]}',
    );
    final CommandAction a = actions.single;
    expect(a.intent, CommandIntent.addStock);
    expect(a.itemName, 'Rice');
    expect(a.originalText, 'biyyam');
    expect(a.quantity, 2);
    expect(a.unit, Unit.kg);
    expect(a.expiryDate, DateTime(2027, 1, 31));
    expect(a.storageLocation, StorageLocation.pantry);
  });

  test('optional fields may be missing or null', () {
    final CommandAction a = parse(
      '{"actions":[{"intent":"mark_finished","item_name_en":"Milk",'
      '"quantity":null,"unit":null,"expiry_date":null,'
      '"storage_location":null}]}',
    ).single;
    expect(a.quantity, isNull);
    expect(a.unit, isNull);
    expect(a.expiryDate, isNull);
  });

  test('query_expiring needs no item', () {
    expect(
      parse('{"actions":[{"intent":"query_expiring"}]}').single.intent,
      CommandIntent.queryExpiring,
    );
  });

  test('an empty list is valid (nothing about groceries)', () {
    expect(parse('{"actions":[]}'), isEmpty);
  });

  test('strips a markdown code fence', () {
    expect(
      parse('```json\n{"actions":[]}\n```'),
      isEmpty,
    );
  });

  test('unit names are normalised', () {
    expect(
      parse('{"actions":[{"intent":"add_stock","item_name_en":"Milk",'
              '"unit":"litre","quantity":1}]}')
          .single
          .unit,
      Unit.l,
    );
    expect(
      parse('{"actions":[{"intent":"add_stock","item_name_en":"Milk",'
              '"unit":"L","quantity":1}]}')
          .single
          .unit,
      Unit.l,
    );
  });

  group('rejects', () {
    test('text that is not JSON, or the wrong shape', () {
      rejects('sure! here you go');
      rejects('[]');
      rejects('{"actions": "none"}');
      rejects('{}');
    });

    test('an unknown intent', () {
      rejects('{"actions":[{"intent":"delete_everything","item_name_en":"X"}]}');
      rejects('{"actions":[{"item_name_en":"X"}]}');
    });

    test('a missing or oversized item name', () {
      rejects('{"actions":[{"intent":"add_stock"}]}');
      rejects('{"actions":[{"intent":"add_stock","item_name_en":"  "}]}');
      rejects(
        '{"actions":[{"intent":"add_stock","item_name_en":"${'x' * 81}"}]}',
      );
    });

    test('bad quantities', () {
      for (final String q in <String>['0', '-2', '"two"', '1e9']) {
        rejects(
          '{"actions":[{"intent":"add_stock","item_name_en":"Rice",'
          '"quantity":$q}]}',
          why: 'quantity $q',
        );
      }
    });

    test('unknown unit or storage location', () {
      rejects(
        '{"actions":[{"intent":"add_stock","item_name_en":"Rice",'
        '"unit":"bucket"}]}',
      );
      rejects(
        '{"actions":[{"intent":"add_stock","item_name_en":"Rice",'
        '"storage_location":"garage"}]}',
      );
    });

    test('impossible or badly written dates', () {
      rejects(
        '{"actions":[{"intent":"add_stock","item_name_en":"Rice",'
        '"expiry_date":"2027-02-31"}]}',
      );
      rejects(
        '{"actions":[{"intent":"add_stock","item_name_en":"Rice",'
        '"expiry_date":"next friday"}]}',
      );
    });

    test('too many actions', () {
      final String one =
          '{"intent":"add_stock","item_name_en":"Rice"}';
      rejects('{"actions":[${List<String>.filled(21, one).join(',')}]}');
    });
  });
}
