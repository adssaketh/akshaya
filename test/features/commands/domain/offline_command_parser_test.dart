import 'package:akshaya/features/commands/domain/command_models.dart';
import 'package:akshaya/features/commands/domain/offline_command_parser.dart';
import 'package:akshaya/features/pantry/domain/entities.dart';
import 'package:akshaya/features/pantry/domain/storage_location.dart';
import 'package:akshaya/features/pantry/domain/unit.dart';
import 'package:flutter_test/flutter_test.dart';

import 'command_test_support.dart';

void main() {
  final OfflineCommandParser parser = buildParser();

  void expectParsed(
    String text,
    List<String> expected, {
    CommandContext context = CommandContext.general,
    bool confident = true,
  }) {
    final CommandInterpretation result = parser.parse(text, context: context);
    expect(summaries(result), expected, reason: text);
    expect(result.confident, confident, reason: 'confidence of "$text"');
    expect(result.source, CommandSource.offline);
  }

  group('examples from the spec', () {
    test('Tenglish: rendu kilo biyyam add cheyyi', () {
      expectParsed('rendu kilo biyyam add cheyyi', <String>['add_stock:Rice 2 kg']);
    });

    test('Hinglish: do kilo chawal list mein daalo', () {
      expectParsed(
        'do kilo chawal list mein daalo',
        <String>['add_to_shopping_list:Rice 2 kg'],
      );
    });

    test('milk ayipoyindi', () {
      expectParsed('milk ayipoyindi', <String>['mark_finished:Milk']);
    });

    test('half packet ravva vaadesanu', () {
      expectParsed(
        'half packet ravva vaadesanu',
        <String>['use_stock:Semolina (Rava) 0.5 packet'],
      );
    });

    test('several items in one sentence, with and without commas', () {
      final List<String> expected = <String>[
        'add_stock:Milk 1 L',
        'add_stock:Eggs 6',
        'add_stock:Tomato 0.5 kg',
      ];
      expectParsed('add 1 litre milk, 6 eggs and half kilo tomatoes', expected);
      expectParsed('add 1 litre milk 6 eggs half kilo tomatoes', expected);
    });
  });

  group('Telugu', () {
    test('native script', () {
      expectParsed(
        'రెండు కిలోలు బియ్యం యాడ్ చేయి',
        <String>['add_stock:Rice 2 kg'],
      );
      expectParsed('పాలు అయిపోయింది', <String>['mark_finished:Milk']);
      expectParsed('ఉల్లిపాయలు అయిపోయాయి', <String>['mark_finished:Onion']);
      expectParsed('2 kg ఉల్లిపాయలు add cheyyi', <String>['add_stock:Onion 2 kg']);
    });

    test('romanised', () {
      expectParsed('ullipaya ayipoyindi', <String>['mark_finished:Onion']);
      expectParsed('kandi pappu 1 kg konnanu', <String>['add_stock:Toor Dal 1 kg']);
      expectParsed('pallilu 1 kg konnanu', <String>['add_stock:Peanuts 1 kg']);
      expectParsed('perugu kavali', <String>['add_to_shopping_list:Curd']);
      expectParsed('paalu rendu litre vaadesanu', <String>['use_stock:Milk 2 L']);
      expectParsed(
        'ara kilo pachi mirchi kavali',
        <String>['add_to_shopping_list:Green Chilli 0.5 kg'],
      );
    });

    test('a list of items with plural endings', () {
      expectParsed(
        'paal 2 litres, guddulu 12, ullipayalu 1 kilo list lo veyyi',
        <String>[
          'add_to_shopping_list:Milk 2 L',
          'add_to_shopping_list:Eggs 12',
          'add_to_shopping_list:Onion 1 kg',
        ],
      );
    });
  });

  group('Hindi', () {
    test('native script', () {
      expectParsed(
        'दो किलो चावल लिस्ट में डालो',
        <String>['add_to_shopping_list:Rice 2 kg'],
      );
      expectParsed('दूध खत्म हो गया', <String>['mark_finished:Milk']);
      expectParsed('पनीर आधा किलो खरीदा', <String>['add_stock:Paneer 0.5 kg']);
    });

    test('romanised', () {
      expectParsed('pyaaz khatam ho gaya', <String>['mark_finished:Onion']);
      expectParsed('dahi kitna hai', <String>['query_stock:Curd']);
      expectParsed('oil khatam', <String>['mark_finished:Cooking Oil']);
      expectParsed('tamatar do kilo kharida', <String>['add_stock:Tomato 2 kg']);
      expectParsed(
        'moongphali 250 gram list mein daalo',
        <String>['add_to_shopping_list:Peanuts 250 g'],
      );
      expectParsed('dedh kilo aloo add karo', <String>['add_stock:Potato 1.5 kg']);
    });

    test('items with no amount share one intent', () {
      expectParsed('aloo pyaaz tamatar chahiye', <String>[
        'add_to_shopping_list:Potato',
        'add_to_shopping_list:Onion',
        'add_to_shopping_list:Tomato',
      ]);
    });
  });

  group('English', () {
    test('shopping list and need', () {
      expectParsed(
        'add 2 kg arhar dal to shopping list',
        <String>['add_to_shopping_list:Toor Dal 2 kg'],
      );
      expectParsed(
        'need 3 packets bread',
        <String>['add_to_shopping_list:Bread 3 packet'],
      );
      expectParsed(
        'two kilo onions and one litre milk list lo add cheyyi',
        <String>['add_to_shopping_list:Onion 2 kg', 'add_to_shopping_list:Milk 1 L'],
      );
    });

    test('use, remove and questions', () {
      expectParsed('half litre milk use', <String>['use_stock:Milk 0.5 L']);
      expectParsed(
        'remove milk from list',
        <String>['remove_from_shopping_list:Milk'],
      );
      expectParsed('how much rice is left', <String>['query_stock:Rice']);
      expectParsed('what is expiring', <String>['query_expiring:']);
    });

    test('a spelling slip is forgiven', () {
      expectParsed('tomatos 2 kg add', <String>['add_stock:Tomato 2 kg']);
    });
  });

  group('intent from the screen', () {
    test('bare add is the pantry in general and the list on Shopping', () {
      expectParsed('eggs 12 add', <String>['add_stock:Eggs 12']);
      expectParsed(
        'eggs 12 add',
        <String>['add_to_shopping_list:Eggs 12'],
        context: CommandContext.shopping,
      );
    });
  });

  group('not understood', () {
    test('an unknown word is flagged as an unknown new item', () {
      final CommandInterpretation r = parser.parse('xyzzy 2 kg add');
      expect(r.confident, isFalse);
      expect(r.actions, hasLength(1));
      expect(r.actions.single.isKnown, isFalse);
      expect(r.actions.single.originalText, 'xyzzy');
    });

    test('an item with no verb is not confident', () {
      final CommandInterpretation r = parser.parse('half kilo tomatoes');
      expect(r.confident, isFalse);
      expect(summaries(r), <String>['add_stock:Tomato 0.5 kg']);
    });

    test('empty text gives no actions', () {
      final CommandInterpretation r = parser.parse('   ');
      expect(r.actions, isEmpty);
      expect(r.confident, isFalse);
    });

    test('two kinds of request in one clause are flagged', () {
      final CommandInterpretation r = parser.parse('milk khatam add karo');
      expect(r.confident, isFalse);
    });
  });

  group('the pantry\'s own words win', () {
    final Item basmati = Item(
      id: 'item-1',
      name: 'Basmati Rice',
      categoryId: 'cat_grains',
      defaultUnit: Unit.kg,
      aliases: const <String>['biyyam'],
      isEssential: true,
      defaultStorageLocation: StorageLocation.pantry,
      createdAt: DateTime(2026, 11, 1),
      updatedAt: DateTime(2026, 11, 1),
    );

    test('rice in any language means the pantry item', () {
      final OfflineCommandParser withPantry = buildParser(
        items: <Item>[basmati],
      );
      for (final String text in <String>[
        'rice 2 kg add',
        'chawal 2 kg add',
        'బియ్యం 2 kg add',
      ]) {
        final CommandInterpretation r = withPantry.parse(text);
        expect(r.actions.single.itemName, 'Basmati Rice', reason: text);
        expect(r.actions.single.itemId, 'item-1', reason: text);
        expect(r.actions.single.typicalUnit, Unit.kg);
      }
    });
  });
}
