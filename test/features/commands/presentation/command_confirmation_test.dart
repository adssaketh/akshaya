import 'package:akshaya/core/design/design.dart';
import 'package:akshaya/features/commands/domain/command_models.dart';
import 'package:akshaya/features/commands/presentation/command_confirmation_sheet.dart';
import 'package:akshaya/features/pantry/domain/unit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  CommandInterpretation interpretation({
    CommandSource source = CommandSource.offline,
    bool confident = true,
    String? note,
  }) {
    return CommandInterpretation(
      recognizedText: 'rendu kilo biyyam add cheyyi',
      actions: const <CommandAction>[
        CommandAction(
          intent: CommandIntent.addStock,
          itemName: 'Rice',
          originalText: 'biyyam',
          quantity: 2,
          unit: Unit.kg,
          itemId: 'item-1',
        ),
        CommandAction(
          intent: CommandIntent.addStock,
          itemName: 'Eggs',
          originalText: 'eggs',
          quantity: 6,
        ),
      ],
      source: source,
      confident: confident,
      note: note,
    );
  }

  Future<List<ConfirmationResult>> pump(
    WidgetTester tester,
    CommandInterpretation value,
  ) async {
    // Tall enough for the whole card, so every button can be tapped.
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final List<ConfirmationResult> results = <ConfirmationResult>[];
    int cancelled = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AkshayaTheme.light(),
        home: Scaffold(
          body: CommandConfirmationCard(
            interpretation: value,
            onResult: results.add,
            onCancel: () => cancelled++,
          ),
        ),
      ),
    );
    expect(cancelled, 0);
    return results;
  }

  testWidgets('shows what was heard and the English action', (tester) async {
    await pump(tester, interpretation());

    expect(find.text('rendu kilo biyyam add cheyyi'), findsOneWidget);
    expect(find.text('I heard'), findsOneWidget);
    expect(find.text('Understood on your phone.'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Rice'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Eggs'), findsOneWidget);
    expect(find.text('You said: biyyam'), findsOneWidget);
    expect(find.text('In your pantry'), findsOneWidget);
    expect(find.text('New item, it will be created'), findsOneWidget);
  });

  testWidgets('nothing happens until Confirm is pressed', (tester) async {
    final List<ConfirmationResult> results = await pump(tester, interpretation());
    expect(results, isEmpty);

    await tester.tap(find.text('Confirm'));
    await tester.pump();

    expect(results, hasLength(1));
    final List<CommandAction> actions = results.single.actions!;
    expect(actions.map((CommandAction a) => a.itemName), <String>['Rice', 'Eggs']);
    expect(actions.first.quantity, 2);
    expect(actions.first.unit, Unit.kg);
    expect(actions.first.itemId, 'item-1');
  });

  testWidgets('AI results are labelled and ask for a careful look',
      (tester) async {
    await pump(tester, interpretation(source: CommandSource.ai));
    expect(
      find.text('Read by AI (Google Gemini). Please check it.'),
      findsOneWidget,
    );
  });

  testWidgets('the person can edit the name and quantity before confirming',
      (tester) async {
    final List<ConfirmationResult> results = await pump(tester, interpretation());

    await tester.enterText(find.widgetWithText(TextField, 'Rice'), 'Basmati Rice');
    await tester.enterText(find.widgetWithText(TextField, '2'), '3');
    await tester.tap(find.text('Confirm'));
    await tester.pump();

    final CommandAction first = results.single.actions!.first;
    expect(first.itemName, 'Basmati Rice');
    expect(first.quantity, 3);
    // Renamed, so it no longer points at the old pantry item.
    expect(first.itemId, isNull);
  });

  testWidgets('removing an action leaves the rest', (tester) async {
    final List<ConfirmationResult> results = await pump(tester, interpretation());

    await tester.tap(find.byTooltip('Remove this action').first);
    await tester.pump();
    await tester.tap(find.text('Confirm'));
    await tester.pump();

    expect(
      results.single.actions!.map((CommandAction a) => a.itemName),
      <String>['Eggs'],
    );
  });

  testWidgets('a bad quantity or empty name is refused', (tester) async {
    final List<ConfirmationResult> results = await pump(tester, interpretation());

    await tester.enterText(find.widgetWithText(TextField, '2'), '0');
    await tester.tap(find.text('Confirm'));
    await tester.pump();
    expect(results, isEmpty);
    expect(find.text('Enter an amount greater than zero.'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, '0'), '2');
    await tester.enterText(find.widgetWithText(TextField, 'Rice'), '  ');
    await tester.tap(find.text('Confirm'));
    await tester.pump();
    expect(results, isEmpty);
    expect(find.text('Every action needs an item name.'), findsOneWidget);
  });

  testWidgets('Change words goes back to editing the text', (tester) async {
    final List<ConfirmationResult> results = await pump(tester, interpretation());
    await tester.ensureVisible(find.text('Change words'));
    await tester.tap(find.text('Change words'));
    await tester.pump();
    expect(results.single.editText, isTrue);
    expect(results.single.actions, isNull);
  });

  testWidgets('an unsure offline reading says so', (tester) async {
    await pump(tester, interpretation(confident: false));
    expect(
      find.text('I am not sure I understood everything. Please check each line.'),
      findsOneWidget,
    );
  });
}
