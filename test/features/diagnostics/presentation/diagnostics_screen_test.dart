import 'package:akshaya/core/design/design.dart';
import 'package:akshaya/core/diagnostics/app_info.dart';
import 'package:akshaya/core/diagnostics/diag_entry.dart';
import 'package:akshaya/core/diagnostics/diag_log.dart';
import 'package:akshaya/core/diagnostics/diag_sink.dart';
import 'package:akshaya/core/share/share_service.dart';
import 'package:akshaya/features/diagnostics/presentation/diagnostics_screen.dart';
import 'package:akshaya/features/diagnostics/presentation/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeShare implements ShareService {
  final List<String> texts = <String>[];

  @override
  Future<void> shareText(String text, {String? subject}) async {
    texts.add(text);
  }
}

const AppInfo _info = AppInfo(
  version: '1.0.8',
  build: '9',
  mode: 'release',
  device: 'Google Pixel 7',
  system: 'Android 15 (API 35)',
  locale: 'en_IN',
);

void main() {
  late DiagLog log;
  late _FakeShare share;

  setUp(() {
    final DateTime base = DateTime.utc(2026, 11, 6, 9);
    final MemoryDiagSink sink = MemoryDiagSink();
    log = DiagLog(sink: sink, clock: () => base);
    log.log(DiagLevel.info, 'app', 'Session start');
    log.log(DiagLevel.warning, 'ai', 'Call failed (attempt 1 of 3)');
    log.log(
      DiagLevel.error,
      'sync',
      'Sync failed',
      error: StateError('boom'),
      stack: StackTrace.fromString('#0 SyncEngine.run (package:akshaya/x.dart:1)'),
    );
    share = _FakeShare();
  });

  Future<void> open(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 3200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          diagLogProvider.overrideWithValue(log),
          appInfoProvider.overrideWith((Ref ref) async => _info),
          diagStateProvider.overrideWith(
            (Ref ref) async => const <MapEntry<String, String>>[
              MapEntry<String, String>('Items', '12'),
              MapEntry<String, String>('Sync', 'off, 0 waiting to send'),
            ],
          ),
          shareServiceProvider.overrideWithValue(share),
        ],
        child: MaterialApp(
          theme: AkshayaTheme.light(),
          home: const DiagnosticsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the build, the counts and the log newest first',
      (WidgetTester tester) async {
    await open(tester);
    expect(find.text('Diagnostics'), findsOneWidget);
    expect(find.text('1.0.8+9'), findsOneWidget);
    expect(find.text('Google Pixel 7'), findsOneWidget);
    expect(find.text('Items'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);

    expect(find.text('Session start'), findsOneWidget);
    expect(find.text('Call failed (attempt 1 of 3)'), findsOneWidget);
    expect(find.text('Sync failed: StateError: Bad state: boom'), findsOneWidget);

    final double newest =
        tester.getTopLeft(find.text('Sync failed: StateError: Bad state: boom')).dy;
    final double oldest = tester.getTopLeft(find.text('Session start')).dy;
    expect(newest, lessThan(oldest));
  });

  testWidgets('the filters hide entries below their level',
      (WidgetTester tester) async {
    await open(tester);

    await tester.tap(find.text('Warnings and errors'));
    await tester.pumpAndSettle();
    expect(find.text('Session start'), findsNothing);
    expect(find.text('Call failed (attempt 1 of 3)'), findsOneWidget);

    await tester.tap(find.text('Errors'));
    await tester.pumpAndSettle();
    expect(find.text('Call failed (attempt 1 of 3)'), findsNothing);
    expect(find.text('Sync failed: StateError: Bad state: boom'), findsOneWidget);

    await tester.tap(find.text('Everything'));
    await tester.pumpAndSettle();
    expect(find.text('Session start'), findsOneWidget);
  });

  testWidgets('an entry with a stack opens to show it',
      (WidgetTester tester) async {
    await open(tester);
    expect(find.textContaining('SyncEngine.run'), findsNothing);
    await tester.tap(find.text('Sync failed: StateError: Bad state: boom'));
    await tester.pumpAndSettle();
    expect(find.textContaining('SyncEngine.run'), findsOneWidget);
  });

  testWidgets('Share report sends the build, counts and log',
      (WidgetTester tester) async {
    await open(tester);
    await tester.tap(find.text('Share report'));
    await tester.pumpAndSettle();

    expect(share.texts, hasLength(1));
    final String report = share.texts.single;
    expect(report, contains('Akshaya Patra diagnostics report'));
    expect(report, contains('App: 1.0.8+9'));
    expect(report, contains('Items: 12'));
    expect(report, contains('Sync failed: StateError: Bad state: boom'));
    expect(report, contains('SyncEngine.run'));
  });

  testWidgets('Clear log asks first, then empties the log',
      (WidgetTester tester) async {
    await open(tester);

    await tester.tap(find.text('Clear log'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Session start'), findsOneWidget);

    await tester.tap(find.text('Clear log'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Clear log'));
    await tester.pumpAndSettle();
    expect(find.text('Session start'), findsNothing);
    // The clearing itself is noted, so the log is not silently empty.
    expect(find.text('Diagnostics log cleared'), findsOneWidget);
  });
}
