import 'package:akshaya/features/ai/domain/ai_command_service.dart';
import 'package:akshaya/features/ai/domain/ai_failures.dart';
import 'package:akshaya/features/ai/domain/ai_settings.dart';
import 'package:akshaya/features/orders/domain/order_ai.dart';
import 'package:akshaya/features/pantry/domain/unit.dart';
import 'package:flutter_test/flutter_test.dart';

import '../ai/domain/ai_test_support.dart';

class _FakeOrderBackend implements OrderBackend {
  _FakeOrderBackend(this.answer);

  final String answer;
  int calls = 0;
  String? lastPrompt;

  @override
  Future<String> parseOrderJson(String prompt) async {
    calls++;
    lastPrompt = prompt;
    return answer;
  }
}

void main() {
  group('OrderAiValidator', () {
    test('reads items with units, prices and categories', () {
      final List<OrderAiItem> items = OrderAiValidator.parse('''
{"items":[
 {"name":"Toor Dal","brand":"Tata Sampann","quantity":1,"unit":"kg","price":164,"category":"cat_dals","is_food":true},
 {"name":"Harpic","quantity":1,"unit":"packet","price":86,"category":"cat_cleaning","is_food":false}
]}''');
      expect(items.length, 2);
      expect(items[0].row.rawName, 'Tata Sampann Toor Dal');
      expect(items[0].row.quantity, 1);
      expect(items[0].row.unit, Unit.kg);
      expect(items[0].row.sizeKnown, isTrue);
      expect(items[0].row.price, 164);
      expect(items[0].categoryId, 'cat_dals');
      expect(items[0].isFood, isTrue);
      expect(items[1].isFood, isFalse);
    });

    test('strips code fences', () {
      final List<OrderAiItem> items = OrderAiValidator.parse(
        '```json\n{"items":[{"name":"Onion"}]}\n```',
      );
      expect(items.single.row.rawName, 'Onion');
    });

    test('fills in safe defaults and drops bad values', () {
      final OrderAiItem item = OrderAiValidator.parse('''
{"items":[{"name":"Onion","quantity":-3,"unit":"bags","price":"cheap","category":"cat_unknown"}]}''')
          .single;
      expect(item.row.quantity, 1);
      expect(item.row.unit, Unit.pcs);
      expect(item.row.sizeKnown, isFalse);
      expect(item.row.price, isNull);
      expect(item.categoryId, isNull);
      expect(item.isFood, isTrue);
    });

    test('leaves out items that are not usable', () {
      final List<OrderAiItem> items = OrderAiValidator.parse(
        '{"items":[{"name":""},{"quantity":2},7,{"name":"Milk"}]}',
      );
      expect(items.single.row.rawName, 'Milk');
    });

    test('an empty list is fine, a list of junk is not', () {
      expect(OrderAiValidator.parse('{"items":[]}'), isEmpty);
      expect(
        () => OrderAiValidator.parse('{"items":[1,2]}'),
        throwsA(isA<AiInvalidResponseFailure>()),
      );
    });

    test('rejects text that is not the expected object', () {
      expect(() => OrderAiValidator.parse('nope'),
          throwsA(isA<AiInvalidResponseFailure>()));
      expect(() => OrderAiValidator.parse('[]'),
          throwsA(isA<AiInvalidResponseFailure>()));
      expect(() => OrderAiValidator.parse('{"actions":[]}'),
          throwsA(isA<AiInvalidResponseFailure>()));
    });
  });

  group('OrderPromptBuilder', () {
    test('drops headings, addresses and phone numbers before sending', () {
      final List<String> lines = OrderPromptBuilder.safeLines(<String>[
        '3:46',
        'Order summary',
        'Delivered to Flat 4B, Road No 12',
        'Call 9876543210',
        'Tata Sampann Toor Dal',
        '1 kg x 1',
        'rahul@example.com',
        '₹98',
      ]);
      expect(lines, <String>['Tata Sampann Toor Dal', '1 kg x 1', '₹98']);
    });

    test('puts only the safe lines into the prompt', () {
      final String prompt = OrderPromptBuilder.build(
        'text={{text}}',
        lines: <String>['Onion', 'Hyderabad 500001'],
      );
      expect(prompt, 'text=Onion');
    });
  });

  group('OrderAiService', () {
    late MemoryUsageStore usage;
    final DateTime now = DateTime(2026, 11, 6, 10);

    OrderAiService build(
      OrderBackend backend, {
      AiSettings settings = const AiSettings(noticeAccepted: true),
    }) {
      final AiCommandService guard = AiCommandService(
        backend: FakeBackend(<Object>['{"actions":[]}']),
        usageStore: usage,
        readSettings: () => settings,
        promptTemplate: kTestPrompt,
        firebaseConfigured: true,
        now: () => now,
        delay: (Duration d) async {},
      );
      return OrderAiService(
        guard: guard,
        backend: backend,
        promptTemplate: '{{text}}',
      );
    }

    setUp(() => usage = MemoryUsageStore());

    test('returns validated items and counts one call', () async {
      final _FakeOrderBackend backend =
          _FakeOrderBackend('{"items":[{"name":"Onion","quantity":1,"unit":"kg"}]}');
      final List<OrderAiItem> items =
          await build(backend).read(<String>['Onion', '1 kg x 1']);
      expect(items.single.row.rawName, 'Onion');
      expect(backend.calls, 1);
      expect(backend.lastPrompt, 'Onion\n1 kg x 1');
      expect(usage.usage.countOn(DateTime(2026, 11, 6)), 1);
    });

    test('an unusable answer is not retried', () async {
      final _FakeOrderBackend backend = _FakeOrderBackend('garbage');
      await expectLater(
        build(backend).read(<String>['Onion']),
        throwsA(isA<AiInvalidResponseFailure>()),
      );
      expect(backend.calls, 1);
    });

    test('does nothing when AI is off or the cap is used', () async {
      final _FakeOrderBackend backend = _FakeOrderBackend('{"items":[]}');
      await expectLater(
        build(backend, settings: const AiSettings(enabled: false))
            .read(<String>['Onion']),
        throwsA(isA<AiUnavailableFailure>()),
      );
      expect(backend.calls, 0);
    });

    test('sends nothing when no line is safe to send', () async {
      final _FakeOrderBackend backend = _FakeOrderBackend('{"items":[]}');
      await expectLater(
        build(backend).read(<String>['3:46', 'Order summary']),
        throwsA(isA<AiInvalidResponseFailure>()),
      );
      expect(backend.calls, 0);
    });
  });
}
