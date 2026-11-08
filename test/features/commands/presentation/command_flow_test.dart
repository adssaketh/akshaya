import 'dart:typed_data';

import 'package:akshaya/core/design/design.dart';
import 'package:akshaya/features/ai/domain/ai_settings.dart';
import 'package:akshaya/features/ai/presentation/providers.dart';
import 'package:akshaya/features/commands/domain/speech_gateway.dart';
import 'package:akshaya/features/commands/presentation/providers.dart';
import 'package:akshaya/features/commands/presentation/voice_mic_button.dart';
import 'package:akshaya/features/pantry/data/database/app_database.dart';
import 'package:akshaya/features/pantry/presentation/providers.dart';
import 'package:akshaya/features/settings/presentation/providers.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'command_flow_support.dart';

class _Speech implements SpeechGateway {
  @override
  Future<SpeechResult> listen({
    required String localeId,
    void Function(String partial)? onPartial,
  }) async =>
      const SpeechResult(SpeechStatus.noSpeech);

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

  /// Pumps the mic button on a plain page, backed by a real in-memory
  /// database. [visible] can remove the button while a sheet is open.
  Future<ValueNotifier<bool>> pump(WidgetTester tester) async {
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
        groceryDictionaryProvider.overrideWith((ref) => loadTestDictionary()),
        parsePromptProvider.overrideWith((ref) => 'p {{text}}'),
      ],
    );
    addTearDown(container.dispose);
    await container
        .read(settingsRepositoryProvider)
        .writeAll(<String, String>{AiSettingKeys.micExplained: 'true'});
    container.listen(settingsMapProvider, (_, __) {});
    container.listen(commandServiceProvider, (_, __) {});
    await tester.runAsync(() => container.read(settingsMapProvider.future));
    final ValueNotifier<bool> visible = ValueNotifier<bool>(true);
    addTearDown(visible.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AkshayaTheme.light(),
          home: Scaffold(
            body: Center(
              child: ValueListenableBuilder<bool>(
                valueListenable: visible,
                builder: (BuildContext _, bool show, Widget? __) =>
                    show ? const VoiceMicButton() : const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return visible;
  }

  Future<void> typeAndSubmit(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.pump();
    await tester.tap(find.text('Understand'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a typed command shows the card, and Confirm adds the item',
      (WidgetTester tester) async {
    await pump(tester);
    await tester.tap(find.byTooltip('Voice or text command'));
    await tester.pumpAndSettle();
    await typeAndSubmit(tester, 'add 10 kg potato');
    expect(find.text('Confirm'), findsOneWidget);
    await tester.tap(find.text('Confirm'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Added 10 kg Potato to your pantry.'), findsOneWidget);
  });

  testWidgets(
      'the flow carries on when the screen it started from is rebuilt '
      'while the sheet is open', (WidgetTester tester) async {
    final ValueNotifier<bool> visible = await pump(tester);
    await tester.tap(find.byTooltip('Voice or text command'));
    await tester.pumpAndSettle();
    // The screen under the sheet drops the button (as a rebuild would).
    visible.value = false;
    await tester.pump();
    expect(find.byTooltip('Voice or text command'), findsNothing);
    await typeAndSubmit(tester, 'add 10 kg potato');
    expect(find.text('Confirm'), findsOneWidget);
  });
}
