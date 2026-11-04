import 'package:akshaya/features/ai/domain/ai_command_service.dart';
import 'package:akshaya/features/ai/domain/ai_settings.dart';
import 'package:akshaya/features/commands/domain/command_models.dart';
import 'package:akshaya/features/commands/domain/command_service.dart';
import 'package:akshaya/features/commands/domain/grocery_lexicon.dart';
import 'package:akshaya/features/commands/domain/offline_command_parser.dart';
import 'package:akshaya/features/pantry/domain/unit.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../ai/domain/ai_test_support.dart';
import 'command_test_support.dart';

void main() {
  final GroceryLexicon lexicon = GroceryLexicon.build(loadDictionary());
  final OfflineCommandParser parser = OfflineCommandParser(lexicon);

  CommandService build(
    FakeBackend backend, {
    AiSettings settings = const AiSettings(noticeAccepted: true),
    bool configured = true,
    MemoryUsageStore? usage,
  }) {
    return CommandService(
      parser: parser,
      lexicon: lexicon,
      ai: AiCommandService(
        backend: backend,
        usageStore: usage ?? MemoryUsageStore(),
        readSettings: () => settings,
        promptTemplate: kTestPrompt,
        firebaseConfigured: configured,
        now: () => DateTime(2026, 11, 4, 10),
        delay: (Duration d) async {},
      ),
    );
  }

  test('a confident offline reading never calls the AI', () async {
    final FakeBackend backend = FakeBackend(<Object>[kGoodJson]);
    final CommandInterpretation r =
        await build(backend).interpret('rendu kilo biyyam add cheyyi');
    expect(r.source, CommandSource.offline);
    expect(backend.calls, 0);
  });

  test('an unsure reading goes to the AI, and the answer is mapped to the '
      'app\'s own item names', () async {
    final FakeBackend backend = FakeBackend(<Object>[
      '{"actions":[{"intent":"add_stock","item_name_en":"rice",'
          '"original_text":"zzzz","quantity":2,"unit":"kg"}]}',
    ]);
    final CommandInterpretation r =
        await build(backend).interpret('zzzz 2 kg something odd');
    expect(r.source, CommandSource.ai);
    expect(backend.calls, 1);
    expect(r.actions.single.itemName, 'Rice');
    expect(r.actions.single.originalText, 'zzzz');
    expect(r.actions.single.unit, Unit.kg);
    expect(r.actions.single.categoryId, 'cat_grains');
  });

  test('at the daily cap the offline reading is kept, with a clear note',
      () async {
    final FakeBackend backend = FakeBackend(<Object>[kGoodJson]);
    final CommandInterpretation r = await build(
      backend,
      usage: MemoryUsageStore(AiUsage(date: '2026-11-04', count: 50)),
    ).interpret('xyzzy 2 kg add');
    expect(r.source, CommandSource.offline);
    expect(r.note, 'AI limit reached for today, using offline mode.');
    expect(r.actions, isNotEmpty);
    expect(backend.calls, 0);
  });

  test('with AI off the offline reading is returned', () async {
    final FakeBackend backend = FakeBackend(<Object>[kGoodJson]);
    final CommandInterpretation r = await build(
      backend,
      settings: const AiSettings(enabled: false),
    ).interpret('xyzzy 2 kg add');
    expect(r.source, CommandSource.offline);
    expect(backend.calls, 0);
  });

  test('an AI failure falls back to offline with the reason', () async {
    final FakeBackend backend =
        FakeBackend(<Object>[Exception('429 quota exceeded')]);
    final CommandInterpretation r =
        await build(backend).interpret('xyzzy 2 kg add');
    expect(r.source, CommandSource.offline);
    expect(r.note, contains('using offline mode'));
    expect(r.actions, isNotEmpty);
  });

  test('an invalid AI answer is rejected and offline is kept', () async {
    final FakeBackend backend = FakeBackend(
      <Object>['{"actions":[{"intent":"fly_to_moon"}]}'],
    );
    final CommandInterpretation r =
        await build(backend).interpret('xyzzy 2 kg add');
    expect(r.source, CommandSource.offline);
  });

  test('without any AI service it just returns the offline reading', () async {
    final CommandInterpretation r = await CommandService(
      parser: parser,
      lexicon: lexicon,
    ).interpret('xyzzy 2 kg add');
    expect(r.source, CommandSource.offline);
    expect(r.confident, isFalse);
  });
}
