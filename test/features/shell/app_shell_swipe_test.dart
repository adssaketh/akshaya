import 'dart:typed_data';

import 'package:akshaya/core/design/design.dart';
import 'package:akshaya/features/commands/domain/speech_gateway.dart';
import 'package:akshaya/features/ai/presentation/providers.dart';
import 'package:akshaya/features/commands/presentation/providers.dart';
import 'package:akshaya/features/pantry/data/database/app_database.dart';
import 'package:akshaya/features/pantry/presentation/providers.dart';
import 'package:akshaya/features/settings/presentation/providers.dart';
import 'package:akshaya/features/shell/app_shell.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../commands/domain/command_test_support.dart';

class _Speech implements SpeechGateway {
  @override
  Future<SpeechResult> listen({
    required String localeId,
    void Function(String partial)? onPartial,
  }) async => const SpeechResult(SpeechStatus.noSpeech);

  @override
  Future<void> stop() async {}

  @override
  Future<void> cancel() async {}
}

class _Recorder implements AudioRecorderGateway {
  @override
  Future<bool> start() async => false;

  @override
  Future<Uint8List?> stop() async => null;

  @override
  Future<void> cancel() async {}
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2376);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    final AppDatabase db = AppDatabase(NativeDatabase.memory());
    addTearDown(() async => db.close());
    final ProviderContainer container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        speechGatewayProvider.overrideWithValue(_Speech()),
        audioRecorderProvider.overrideWithValue(_Recorder()),
        groceryDictionaryProvider.overrideWith((ref) => loadDictionary()),
        parsePromptProvider.overrideWith((ref) => 'p {{text}}'),
      ],
    );
    addTearDown(container.dispose);
    container.listen(settingsMapProvider, (_, __) {});
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: AkshayaTheme.light(), home: const AppShell()),
      ),
    );
    await tester.pumpAndSettle();
  }

  int selected(WidgetTester tester) =>
      tester.widget<AkshayaNavBar>(find.byType(AkshayaNavBar)).selectedIndex;

  testWidgets('starts on Home with the bar on Home', (tester) async {
    await pump(tester);
    expect(selected(tester), 0);
  });

  testWidgets('swiping the page moves to Pantry and the bar follows', (
    tester,
  ) async {
    await pump(tester);
    await tester.fling(find.byType(PageView), const Offset(-300, 0), 2000);
    await tester.pumpAndSettle();
    expect(selected(tester), 1);
    final PageView pages = tester.widget<PageView>(find.byType(PageView));
    expect(pages.controller!.page, 1);
  });

  testWidgets('swiping back returns to Home', (tester) async {
    await pump(tester);
    await tester.fling(find.byType(PageView), const Offset(-300, 0), 2000);
    await tester.pumpAndSettle();
    await tester.fling(find.byType(PageView), const Offset(300, 0), 2000);
    await tester.pumpAndSettle();
    expect(selected(tester), 0);
  });

  testWidgets('tapping a bar tab slides the page there', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Pantry'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    final PageView pages = tester.widget<PageView>(find.byType(PageView));
    expect(
      pages.controller!.page,
      inExclusiveRange(0.0, 1.0),
      reason: 'sliding, not jumping',
    );
    await tester.pumpAndSettle();
    expect(pages.controller!.page, 1);
    expect(selected(tester), 1);
  });

  testWidgets('the bar indicator is exactly between tabs mid-swipe', (
    tester,
  ) async {
    await pump(tester);
    final TestGesture g = await tester.startGesture(const Offset(300, 400));
    await g.moveBy(const Offset(-150, 0));
    await tester.pump();
    final PageView pages = tester.widget<PageView>(find.byType(PageView));
    final double page = pages.controller!.page!;
    expect(page, inExclusiveRange(0.05, 0.95));
    final Positioned indicator = tester
        .widgetList<Positioned>(find.byType(Positioned))
        .firstWhere((Positioned p) => p.width == AppSizes.navIndicatorWidth);
    expect(indicator.left, greaterThan(0));
    await g.up();
    await tester.pumpAndSettle();
  });

  testWidgets('no errors while swiping through the first tabs', (tester) async {
    await pump(tester);
    for (int i = 0; i < 2; i++) {
      await tester.fling(find.byType(PageView), const Offset(-300, 0), 2000);
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
    expect(selected(tester), 2);
  });
}
