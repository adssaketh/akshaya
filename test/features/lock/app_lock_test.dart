import 'package:akshaya/core/design/design.dart';
import 'package:akshaya/features/lock/app_lock.dart';
import 'package:akshaya/features/settings/domain/app_settings.dart';
import 'package:akshaya/features/settings/presentation/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../settings/fake_settings_repository.dart';

class FakeAuthenticator implements AppAuthenticator {
  FakeAuthenticator({this.available = true, this.accept = true});

  bool available;
  bool accept;
  int prompts = 0;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<bool> authenticate(String reason) async {
    prompts++;
    return accept;
  }
}

Widget host(FakeAuthenticator auth, {required bool lockOn}) {
  return ProviderScope(
    overrides: [
      settingsRepositoryProvider.overrideWithValue(
        FakeSettingsRepository(<String, String>{
          if (lockOn) AppSettingKeys.appLock: 'true',
        }),
      ),
      appAuthenticatorProvider.overrideWithValue(auth),
    ],
    child: MaterialApp(
      theme: AkshayaTheme.light(),
      home: const AppLockGate(child: Scaffold(body: Text('secret pantry'))),
    ),
  );
}

void main() {
  testWidgets('does nothing when the lock is off', (WidgetTester tester) async {
    final FakeAuthenticator auth = FakeAuthenticator();
    await tester.pumpWidget(host(auth, lockOn: false));
    await tester.pumpAndSettle();
    expect(find.text('secret pantry'), findsOneWidget);
    expect(auth.prompts, 0);
  });

  testWidgets('asks to unlock, and opens when it succeeds',
      (WidgetTester tester) async {
    final FakeAuthenticator auth = FakeAuthenticator();
    await tester.pumpWidget(host(auth, lockOn: true));
    await tester.pumpAndSettle();
    expect(auth.prompts, 1);
    expect(find.text('Akshaya Patra is locked'), findsNothing);
    expect(find.text('secret pantry'), findsOneWidget);
  });

  testWidgets('stays locked when the check fails, until it succeeds',
      (WidgetTester tester) async {
    final FakeAuthenticator auth = FakeAuthenticator(accept: false);
    await tester.pumpWidget(host(auth, lockOn: true));
    await tester.pumpAndSettle();
    expect(find.text('Akshaya Patra is locked'), findsOneWidget);
    expect(find.text('secret pantry'), findsNothing);

    auth.accept = true;
    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();
    expect(find.text('secret pantry'), findsOneWidget);
  });

  testWidgets('never locks out a phone with no screen lock',
      (WidgetTester tester) async {
    final FakeAuthenticator auth = FakeAuthenticator(available: false);
    await tester.pumpWidget(host(auth, lockOn: true));
    await tester.pumpAndSettle();
    expect(find.text('secret pantry'), findsOneWidget);
    expect(auth.prompts, 0);
  });
}
