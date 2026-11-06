import 'package:akshaya/core/design/design.dart';
import 'package:akshaya/features/guide/domain/guide_content.dart';
import 'package:akshaya/features/guide/domain/guide_models.dart';
import 'package:akshaya/features/guide/presentation/guide_button.dart';
import 'package:akshaya/features/guide/presentation/guide_previews.dart';
import 'package:akshaya/features/guide/presentation/guide_screen.dart';
import 'package:akshaya/features/guide/presentation/guide_topic_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget host(Widget child, {ThemeData? theme, double textScale = 1}) {
  return MaterialApp(
    theme: theme ?? AkshayaTheme.light(),
    builder: (BuildContext context, Widget? app) {
      return MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
        ),
        child: app!,
      );
    },
    home: child,
  );
}

void main() {
  group('GuideScreen', () {
    testWidgets('shows the title, the start card and the first topics',
        (WidgetTester tester) async {
      await tester.pumpWidget(host(const GuideScreen()));
      await tester.pumpAndSettle();

      expect(find.text('User guide'), findsOneWidget);
      expect(find.text('New here?'), findsOneWidget);
      expect(find.text('The five tabs'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'All'), findsOneWidget);
    });

    testWidgets('searching shows matching topics and hides the area chips',
        (WidgetTester tester) async {
      await tester.pumpWidget(host(const GuideScreen()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'barcode');
      await tester.pumpAndSettle();

      expect(find.text('Scan a barcode'), findsOneWidget);
      expect(find.byType(ChoiceChip), findsNothing);
      expect(find.text('New here?'), findsNothing);
    });

    testWidgets('a search with no match shows an empty state',
        (WidgetTester tester) async {
      await tester.pumpWidget(host(const GuideScreen()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'xyzzyqq');
      await tester.pumpAndSettle();

      expect(find.text('Nothing found'), findsOneWidget);
    });

    testWidgets('the clear button brings the browse view back',
        (WidgetTester tester) async {
      await tester.pumpWidget(host(const GuideScreen()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'barcode');
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Clear search'));
      await tester.pumpAndSettle();

      expect(find.byType(ChoiceChip), findsWidgets);
      expect(find.text('New here?'), findsOneWidget);
    });

    testWidgets('an area chip shows only that area',
        (WidgetTester tester) async {
      await tester.pumpWidget(host(const GuideScreen()));
      await tester.pumpAndSettle();

      final Finder chip = find.widgetWithText(ChoiceChip, 'Alerts');
      await tester.scrollUntilVisible(
        chip,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(chip);
      await tester.pumpAndSettle();

      expect(find.text('Daily alert'), findsOneWidget);
      expect(find.text('The five tabs'), findsNothing);
      expect(find.text('New here?'), findsNothing);
    });

    testWidgets('tapping a topic opens its page', (WidgetTester tester) async {
      await tester.pumpWidget(host(const GuideScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('The five tabs'));
      await tester.pumpAndSettle();

      expect(find.text('Where to find it'), findsOneWidget);
      expect(find.text('How to'), findsOneWidget);
      expect(find.byType(GuidePreviewView), findsOneWidget);
    });
  });

  group('GuideButton', () {
    testWidgets('opens the guide', (WidgetTester tester) async {
      await tester.pumpWidget(
        host(const Scaffold(body: Center(child: GuideButton()))),
      );

      await tester.tap(find.byTooltip('User guide'));
      await tester.pumpAndSettle();

      expect(find.byType(GuideScreen), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });
  });

  group('GuideTopicScreen', () {
    testWidgets('a Read next chip opens the related topic',
        (WidgetTester tester) async {
      final GuideTopic topic = guideTopicById('tabs')!;
      await tester.pumpWidget(host(GuideTopicScreen(topic: topic)));
      await tester.pumpAndSettle();

      final GuideTopic next = guideTopicById(topic.related.first)!;
      final Finder chip = find.widgetWithText(ActionChip, next.title);
      await tester.scrollUntilVisible(
        chip,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(chip);
      await tester.pumpAndSettle();

      expect(find.text(next.title), findsWidgets);
      expect(find.text('Where to find it'), findsOneWidget);
    });

    for (final ThemeData theme in <ThemeData>[
      AkshayaTheme.light(),
      AkshayaTheme.dark(),
    ]) {
      for (final double scale in <double>[1, 2]) {
        testWidgets(
          'every page builds without overflow '
          '(${theme.brightness.name}, text x$scale)',
          (WidgetTester tester) async {
            tester.view.physicalSize = const Size(360, 800);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);

            final List<String> failures = <String>[];
            for (final GuideTopic topic in kGuideTopics) {
              await tester.pumpWidget(
                host(
                  GuideTopicScreen(topic: topic),
                  theme: theme,
                  textScale: scale,
                ),
              );
              await tester.pump();
              final Object? error = tester.takeException();
              if (error != null) {
                failures.add('${topic.id}: $error');
              }
            }
            // One run lists every page that overflows, not just the first.
            expect(failures, isEmpty);
          },
        );
      }
    }

    testWidgets('every picture builds on its own',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      for (final GuidePreview preview in GuidePreview.values) {
        await tester.pumpWidget(
          host(
            Scaffold(
              body: SingleChildScrollView(
                child: GuidePreviewView(preview: preview),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull, reason: preview.name);
        expect(preview.caption, isNotEmpty);
      }
    });
  });
}
