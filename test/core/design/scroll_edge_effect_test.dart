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

class _Probe extends StatefulWidget {
  const _Probe();

  static int created = 0;

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  void initState() {
    super.initState();
    _Probe.created++;
  }

  @override
  Widget build(BuildContext context) => const Text('probe');
}

Widget _probeHost(ScrollEdgeKind kind, double barHeight) {
  return MaterialApp(
    theme: AkshayaTheme.light(),
    home: Scaffold(
      body: ScrollEdgeEffect(
        kind: kind,
        barHeight: barHeight,
        glass: false,
        child: const _Probe(),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'the child keeps its state when the bar height drops to 0 (keyboard open) '
    'or the kind changes',
    (tester) async {
      _Probe.created = 0;
      await tester.pumpWidget(_probeHost(ScrollEdgeKind.fade, 90));
      await tester.pumpWidget(_probeHost(ScrollEdgeKind.fade, 0));
      await tester.pumpWidget(_probeHost(ScrollEdgeKind.fade, 90));
      await tester.pumpWidget(_probeHost(ScrollEdgeKind.off, 90));
      await tester.pumpWidget(_probeHost(ScrollEdgeKind.blur, 90));
      expect(_Probe.created, 1);
    },
  );

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
    // The faintest bands (under 0.6 sigma, invisible) are skipped: at the
    // default strength that leaves 4 of the 6 steps.
    expect(find.byType(BackdropFilter), findsNWidgets(4));
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
