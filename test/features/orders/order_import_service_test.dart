import 'package:akshaya/features/ai/domain/ai_command_service.dart';
import 'package:akshaya/features/ai/domain/ai_settings.dart';
import 'package:akshaya/features/commands/domain/grocery_lexicon.dart';
import 'package:akshaya/features/orders/domain/ocr_models.dart';
import 'package:akshaya/features/orders/domain/order_ai.dart';
import 'package:akshaya/features/orders/domain/order_import_service.dart';
import 'package:akshaya/features/orders/domain/order_models.dart';
import 'package:akshaya/features/pantry/domain/storage_location.dart';
import 'package:akshaya/features/pantry/domain/unit.dart';
import 'package:flutter_test/flutter_test.dart';

import '../ai/domain/ai_test_support.dart';
import '../commands/domain/command_test_support.dart';
import 'order_fixtures.dart';

class _FakeReader implements ScreenshotReader {
  _FakeReader(this.pages);

  final Map<String, OcrPage> pages;

  @override
  Future<OcrPage> read(String path) async {
    final OcrPage? page = pages[path];
    if (page == null) {
      throw StateError('no such picture');
    }
    return page;
  }
}

class _FakeOrderBackend implements OrderBackend {
  _FakeOrderBackend(this.answer);

  final String answer;
  int calls = 0;

  @override
  Future<String> parseOrderJson(String prompt) async {
    calls++;
    return answer;
  }
}

OcrPage _gibberish() {
  return OcrPage(
    width: 900,
    height: 1900,
    lines: <OcrLine>[
      for (int i = 0; i < 8; i++)
        OcrLine(
          text: 'Toor Dal pack $i',
          left: 100,
          top: 300.0 + i * 100,
          right: 400,
          bottom: 330.0 + i * 100,
        ),
    ],
  );
}

void main() {
  final GroceryLexicon lexicon = GroceryLexicon.build(loadDictionary());

  OrderImportService build(
    Map<String, OcrPage> pages, {
    OrderBackend? backend,
  }) {
    OrderAiService? ai;
    if (backend != null) {
      ai = OrderAiService(
        guard: AiCommandService(
          backend: FakeBackend(<Object>['{"actions":[]}']),
          usageStore: MemoryUsageStore(),
          readSettings: () => const AiSettings(noticeAccepted: true),
          promptTemplate: kTestPrompt,
          firebaseConfigured: true,
          now: () => DateTime(2026, 11, 6, 10),
          delay: (Duration d) async {},
        ),
        backend: backend,
        promptTemplate: '{{text}}',
      );
    }
    return OrderImportService(
      reader: _FakeReader(pages),
      lexicon: lexicon,
      ai: ai,
    );
  }

  test('turns a Zepto order into drafts with details by product type',
      () async {
    final OrderScan scan =
        await build(<String, OcrPage>{'z': zeptoPage()}).scan(<String>['z']);
    expect(scan.store, OrderStore.zepto);
    expect(scan.drafts.length, 9);
    expect(scan.isHard, isFalse);

    final OrderDraft milk = scan.drafts[3];
    expect(milk.name, 'Milk');
    expect(milk.quantity, 1);
    expect(milk.unit, Unit.l);
    expect(milk.price, 76);
    expect(milk.categoryId, 'cat_dairy');
    expect(milk.location, StorageLocation.fridge);
    expect(milk.estimateDays, 3);
    expect(milk.include, isTrue);

    final OrderDraft eggs = scan.drafts[2];
    expect(eggs.name, 'Eggs');
    expect(eggs.quantity, 10);
    expect(eggs.unit, Unit.pcs);
    expect(eggs.include, isTrue);

    final OrderDraft paper = scan.drafts[8];
    expect(paper.skip, SkipReason.notFood);
    expect(paper.include, isFalse);
  });

  test('non-food lines start unticked and food lines ticked (Swiggy)',
      () async {
    final OrderScan scan =
        await build(<String, OcrPage>{'s': swiggyPage()}).scan(<String>['s']);
    expect(scan.store, OrderStore.instamart);
    final Map<String, bool> ticked = <String, bool>{
      for (final OrderDraft d in scan.drafts) d.sourceName: d.include,
    };
    expect(ticked['WishCare Hydrating AHA BHA Anti Dandr'], isFalse);
    expect(ticked['Garlic'], isTrue);
    expect(ticked['Everest Chicken Masala Powder'], isTrue);
    expect(
      scan.drafts.first.notes,
      contains(DraftNote.amountNotShown),
    );
  });

  test('cut-off names get a note, and are not guessed', () async {
    final OrderScan scan = await build(<String, OcrPage>{'f': flipkartPage()})
        .scan(<String>['f']);
    expect(scan.store, OrderStore.flipkartMinutes);
    final OrderDraft white = scan.drafts[3];
    expect(white.notes, contains(DraftNote.nameCutOff));
    final OrderDraft toor = scan.drafts[2];
    expect(toor.name, 'Toor Dal');
  });

  test('the same product in two overlapping screenshots is listed once',
      () async {
    final OrderScan scan = await build(<String, OcrPage>{
      'a': blinkitPage(),
      'b': blinkitPage(),
    }).scan(<String>['a', 'b']);
    expect(scan.pages, 2);
    expect(scan.drafts.length, 10);
  });

  test('text without products is a hard page; a clean order is not',
      () async {
    final OrderScan hard =
        await build(<String, OcrPage>{'g': _gibberish()}).scan(<String>['g']);
    expect(hard.drafts, isEmpty);
    expect(hard.difficulty, OrderDifficulty.noProducts);

    const OcrPage blank = OcrPage(width: 900, height: 1900, lines: <OcrLine>[]);
    final OrderScan nothing =
        await build(<String, OcrPage>{'e': blank}).scan(<String>['e']);
    expect(nothing.isHard, isFalse);
  });

  test('a picture that cannot be read throws', () async {
    await expectLater(
      build(<String, OcrPage>{}).scan(<String>['missing']),
      throwsA(isA<StateError>()),
    );
  });

  test('AI replaces an empty offline reading with validated items', () async {
    final _FakeOrderBackend backend = _FakeOrderBackend('''
{"items":[
 {"name":"Toor Dal","brand":"Tata Sampann","quantity":1,"unit":"kg","price":164,"category":"cat_dals"},
 {"name":"Mystery Snack","quantity":2,"unit":"packet","category":"cat_snacks"},
 {"name":"Harpic","is_food":false}
]}''');
    final OrderImportService service =
        build(<String, OcrPage>{'g': _gibberish()}, backend: backend);
    final OrderScan hard = await service.scan(<String>['g']);
    final OrderScan better = await service.improveWithAi(hard);
    expect(backend.calls, 1);
    expect(better.usedAi, isTrue);
    expect(better.isHard, isFalse);
    expect(better.drafts.length, 3);
    expect(better.drafts[0].name, 'Toor Dal');
    expect(better.drafts[0].price, 164);
    expect(better.drafts[1].categoryId, 'cat_snacks');
    expect(better.drafts[2].include, isFalse);
  });

  test('AI answers with fewer items than offline keep the offline result',
      () async {
    final _FakeOrderBackend backend =
        _FakeOrderBackend('{"items":[{"name":"Onion"}]}');
    final OrderImportService service =
        build(<String, OcrPage>{'z': zeptoPage()}, backend: backend);
    final OrderScan offline = await service.scan(<String>['z']);
    final OrderScan result = await service.improveWithAi(offline);
    expect(result.usedAi, isFalse);
    expect(result.drafts.length, offline.drafts.length);
  });
}
