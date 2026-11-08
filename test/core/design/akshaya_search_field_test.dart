import 'package:akshaya/core/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(TextEditingController controller, List<String> changes) {
  return MaterialApp(
    theme: AkshayaTheme.light(),
    home: Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: AkshayaSearchField(
          controller: controller,
          hint: 'Search things',
          onChanged: changes.add,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('tapping the field focuses it and opens the keyboard',
      (WidgetTester tester) async {
    final TextEditingController controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_host(controller, <String>[]));

    expect(tester.testTextInput.isVisible, isFalse);
    await tester.tap(find.byType(TextField));
    await tester.pump();

    expect(tester.testTextInput.isVisible, isTrue);
    expect(
      tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus,
      isTrue,
    );
  });

  testWidgets('typing reports changes and the clear button empties the box',
      (WidgetTester tester) async {
    final TextEditingController controller = TextEditingController();
    addTearDown(controller.dispose);
    final List<String> changes = <String>[];
    await tester.pumpWidget(_host(controller, changes));

    await tester.enterText(find.byType(TextField), 'rice');
    await tester.pump();
    expect(changes.last, 'rice');
    expect(find.byTooltip('Clear search'), findsOneWidget);

    await tester.tap(find.byTooltip('Clear search'));
    await tester.pump();
    expect(controller.text, isEmpty);
    expect(changes.last, '');
    expect(find.byTooltip('Clear search'), findsNothing);
  });
}
