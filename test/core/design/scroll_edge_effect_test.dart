import 'package:akshaya/core/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(ScrollEdgeKind kind, {bool glass = false}) {
  return MaterialApp(
    theme: AkshayaTheme.light(),
    home: Scaffold(
      body: ScrollEdgeEffect(
        kind: kind,
        barHeight: 90,
        glass: glass,
        child: ListView(
          children: <Widget>[
            for (int i = 0; i < 30; i++) ListTile(title: Text('Row $i')),
          ],
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('off leaves the page untouched', (tester) async {
    await tester.pumpWidget(_host(ScrollEdgeKind.off));
    expect(find.byType(ShaderMask), findsNothing);
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('fade masks the page without blurring', (tester) async {
    await tester.pumpWidget(_host(ScrollEdgeKind.fade));
    // No offscreen layer: the fade is a plain gradient over the list.
    expect(find.byType(ShaderMask), findsNothing);
    expect(find.byType(BackdropFilter), findsNothing);
    expect(find.text('Row 0'), findsOneWidget);
  });

  testWidgets('blur adds one backdrop band per step', (tester) async {
    await tester.pumpWidget(_host(ScrollEdgeKind.blur, glass: true));
    expect(find.byType(ShaderMask), findsNothing);
    expect(find.byType(BackdropFilter), findsNWidgets(AppSizes.edgeBlurBands));
  });

  test('zone: solid hides inside the bar, glass starts at the edge', () {
    const Widget c = SizedBox();
    const ScrollEdgeEffect solid = ScrollEdgeEffect(
      kind: ScrollEdgeKind.fade,
      barHeight: 100,
      glass: false,
      child: c,
    );
    const ScrollEdgeEffect glass = ScrollEdgeEffect(
      kind: ScrollEdgeKind.fade,
      barHeight: 100,
      glass: true,
      child: c,
    );
    expect(solid.hide, greaterThan(0));
    expect(solid.full, greaterThan(100));
    expect(glass.hide, 0);
    expect(glass.full, lessThan(solid.full));
  });
}
