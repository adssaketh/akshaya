import 'package:akshaya/core/design/design.dart';
import 'package:akshaya/core/time/clock.dart';
import 'package:akshaya/features/alerts/domain/alert_settings.dart';
import 'package:akshaya/features/alerts/presentation/alerts_section.dart';
import 'package:akshaya/features/alerts/presentation/first_run_prompt.dart';
import 'package:akshaya/features/alerts/presentation/providers.dart';
import 'package:akshaya/features/pantry/domain/entities.dart';
import 'package:akshaya/features/pantry/presentation/providers.dart';
import 'package:akshaya/features/settings/presentation/providers.dart';
import 'package:akshaya/features/shopping/presentation/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../pantry/domain/test_data.dart';
import '../../pantry/presentation/fake_repository.dart';
import '../../settings/fake_settings_repository.dart';
import '../../shopping/presentation/fake_shopping_repository.dart';
import '../fake_notification_gateway.dart';

Widget host({
  required FakeSettingsRepository settings,
  required FakeNotificationGateway gateway,
  FakePantryRepository? pantry,
  required Widget home,
}) {
  return ProviderScope(
    overrides: [
      settingsRepositoryProvider.overrideWithValue(settings),
      notificationGatewayProvider.overrideWithValue(gateway),
      pantryRepositoryProvider
          .overrideWithValue(pantry ?? FakePantryRepository()),
      shoppingRepositoryProvider.overrideWithValue(FakeShoppingRepository()),
      clockProvider.overrideWithValue(() => DateTime(2026, 11, 4, 10)),
    ],
    child: MaterialApp(
      theme: AkshayaTheme.light(),
      home: Scaffold(body: SingleChildScrollView(child: home)),
    ),
  );
}

void main() {
  void bigScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  // The preview reads two streams and awaits the gateway, which takes several
  // event-loop turns; pump a few frames so they all finish.
  Future<void> letAsyncWorkFinish(WidgetTester tester) async {
    for (int i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  group('AlertsSection', () {
    testWidgets('shows the defaults', (WidgetTester tester) async {
      bigScreen(tester);
      await tester.pumpWidget(
        host(
          settings: FakeSettingsRepository(),
          gateway: FakeNotificationGateway(),
          home: const AlertsSection(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Daily alert'), findsOneWidget);
      expect(find.text('8:00 am'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('Allow notifications'), findsNothing);
    });

    testWidgets('the stepper changes and saves the window',
        (WidgetTester tester) async {
      bigScreen(tester);
      final FakeSettingsRepository settings = FakeSettingsRepository();
      await tester.pumpWidget(
        host(
          settings: settings,
          gateway: FakeNotificationGateway(),
          home: const AlertsSection(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('One day more'));
      await tester.pumpAndSettle();

      expect(find.text('4'), findsOneWidget);
      expect(settings.values[AlertSettingKeys.warningDays], '4');

      await tester.tap(find.byTooltip('One day fewer'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('One day fewer'));
      await tester.pumpAndSettle();
      expect(settings.values[AlertSettingKeys.warningDays], '2');
    });

    testWidgets('switching the alert off saves it and disables the options',
        (WidgetTester tester) async {
      bigScreen(tester);
      final FakeSettingsRepository settings = FakeSettingsRepository();
      await tester.pumpWidget(
        host(
          settings: settings,
          gateway: FakeNotificationGateway(),
          home: const AlertsSection(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Daily alert'));
      await tester.pumpAndSettle();

      expect(settings.values[AlertSettingKeys.enabled], 'false');
      final IconButton more = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.add_circle_outline_rounded),
      );
      expect(more.onPressed, isNull);
    });

    testWidgets('turning the alert back on asks for permission',
        (WidgetTester tester) async {
      bigScreen(tester);
      final FakeNotificationGateway gateway =
          FakeNotificationGateway(allowed: false);
      await tester.pumpWidget(
        host(
          settings: FakeSettingsRepository(
            const <String, String>{AlertSettingKeys.enabled: 'false'},
          ),
          gateway: gateway,
          home: const AlertsSection(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Daily alert'));
      await tester.pumpAndSettle();

      expect(gateway.permissionRequests, 1);
    });

    testWidgets('the banner appears when notifications are off and allows them',
        (WidgetTester tester) async {
      bigScreen(tester);
      final FakeNotificationGateway gateway =
          FakeNotificationGateway(allowed: false);
      await tester.pumpWidget(
        host(
          settings: FakeSettingsRepository(),
          gateway: gateway,
          home: const AlertsSection(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Allow notifications'), findsOneWidget);
      await tester.tap(find.text('Allow notifications'));
      await tester.pumpAndSettle();

      expect(gateway.permissionRequests, 1);
      expect(find.text('Allow notifications'), findsNothing);
    });

    testWidgets('a refusal shows how to open system settings',
        (WidgetTester tester) async {
      bigScreen(tester);
      final FakeNotificationGateway gateway =
          FakeNotificationGateway(allowed: false)..grantsPermission = false;
      await tester.pumpWidget(
        host(
          settings: FakeSettingsRepository(),
          gateway: gateway,
          home: const AlertsSection(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Allow notifications'));
      await tester.pumpAndSettle();

      expect(find.textContaining('still off'), findsOneWidget);
      await tester.tap(find.text('Open settings'));
      await tester.pumpAndSettle();
      expect(gateway.settingsOpened, 1);
    });

    testWidgets('the preview says so when there is nothing to alert about',
        (WidgetTester tester) async {
      bigScreen(tester);
      final FakeNotificationGateway gateway = FakeNotificationGateway();
      await tester.pumpWidget(
        host(
          settings: FakeSettingsRepository(),
          gateway: gateway,
          home: const AlertsSection(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Show today’s alert now'));
      await letAsyncWorkFinish(tester);

      expect(find.text('Nothing to alert about right now.'), findsOneWidget);
      expect(gateway.shown, isEmpty);
    });

    testWidgets('the preview shows the alert for expiring stock',
        (WidgetTester tester) async {
      bigScreen(tester);
      final FakeNotificationGateway gateway = FakeNotificationGateway();
      final FakePantryRepository pantry = FakePantryRepository(
        items: <ItemWithBatches>[
          ItemWithBatches(
            item: makeItem(name: 'Curd'),
            batches: <StockBatch>[makeBatch(expiry: DateTime(2026, 11, 5))],
          ),
        ],
      );
      await tester.pumpWidget(
        host(
          settings: FakeSettingsRepository(),
          gateway: gateway,
          pantry: pantry,
          home: const AlertsSection(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Show today’s alert now'));
      await letAsyncWorkFinish(tester);

      expect(gateway.shown, hasLength(1));
      expect(gateway.shown.single.single.title, '1 item expiring soon');
    });

    testWidgets('the preview asks to allow notifications first',
        (WidgetTester tester) async {
      bigScreen(tester);
      final FakeNotificationGateway gateway =
          FakeNotificationGateway(allowed: false);
      await tester.pumpWidget(
        host(
          settings: FakeSettingsRepository(),
          gateway: gateway,
          home: const AlertsSection(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Show today’s alert now'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Allow notifications first'), findsOneWidget);
      expect(gateway.shown, isEmpty);
    });
  });

  group('first-run prompt', () {
    Widget promptHost(
      FakeSettingsRepository settings,
      FakeNotificationGateway gateway,
    ) {
      return host(
        settings: settings,
        gateway: gateway,
        home: Consumer(
          builder: (BuildContext context, WidgetRef ref, Widget? _) {
            return FilledButton(
              onPressed: () => askForNotificationsOnFirstRun(context, ref),
              child: const Text('ask'),
            );
          },
        ),
      );
    }

    testWidgets('asks once, then remembers', (WidgetTester tester) async {
      bigScreen(tester);
      final FakeSettingsRepository settings = FakeSettingsRepository();
      final FakeNotificationGateway gateway =
          FakeNotificationGateway(allowed: false);
      await tester.pumpWidget(promptHost(settings, gateway));

      await tester.tap(find.text('ask'));
      await tester.pumpAndSettle();
      expect(find.text('Daily expiry alerts'), findsOneWidget);

      await tester.tap(find.text('Allow'));
      await tester.pumpAndSettle();
      expect(gateway.permissionRequests, 1);
      expect(settings.values[AlertSettingKeys.permissionPrompted], 'true');

      await tester.tap(find.text('ask'));
      await tester.pumpAndSettle();
      expect(find.text('Daily expiry alerts'), findsNothing);
      expect(gateway.permissionRequests, 1);
    });

    testWidgets('"Not now" does not ask the system, and is remembered',
        (WidgetTester tester) async {
      bigScreen(tester);
      final FakeSettingsRepository settings = FakeSettingsRepository();
      final FakeNotificationGateway gateway =
          FakeNotificationGateway(allowed: false);
      await tester.pumpWidget(promptHost(settings, gateway));

      await tester.tap(find.text('ask'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();

      expect(gateway.permissionRequests, 0);
      expect(settings.values[AlertSettingKeys.permissionPrompted], 'true');
    });

    testWidgets('does not ask when notifications are already allowed',
        (WidgetTester tester) async {
      bigScreen(tester);
      final FakeSettingsRepository settings = FakeSettingsRepository();
      await tester.pumpWidget(promptHost(settings, FakeNotificationGateway()));

      await tester.tap(find.text('ask'));
      await tester.pumpAndSettle();

      expect(find.text('Daily expiry alerts'), findsNothing);
      expect(settings.values[AlertSettingKeys.permissionPrompted], 'true');
    });

    testWidgets('does not ask when the alert is switched off',
        (WidgetTester tester) async {
      bigScreen(tester);
      final FakeSettingsRepository settings = FakeSettingsRepository(
        const <String, String>{AlertSettingKeys.enabled: 'false'},
      );
      await tester.pumpWidget(
        promptHost(settings, FakeNotificationGateway(allowed: false)),
      );

      await tester.tap(find.text('ask'));
      await tester.pumpAndSettle();

      expect(find.text('Daily expiry alerts'), findsNothing);
    });
  });
}
