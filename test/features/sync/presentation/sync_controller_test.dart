import 'package:akshaya/core/design/design.dart';
import 'package:akshaya/features/pantry/data/database/app_database.dart';
import 'package:akshaya/features/pantry/data/drift_pantry_repository.dart';
import 'package:akshaya/features/pantry/presentation/providers.dart';
import 'package:akshaya/features/settings/presentation/providers.dart';
import 'package:akshaya/features/sync/domain/account_gateways.dart';
import 'package:akshaya/features/sync/domain/sync_models.dart';
import 'package:akshaya/features/sync/presentation/providers.dart';
import 'package:akshaya/features/sync/presentation/sync_section.dart';
import 'package:drift/drift.dart' show QueryRow, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../pantry/sample_data.dart';
import '../data/fake_sync_remote.dart';

const AuthUser _asha = AuthUser(uid: 'u1', displayName: 'Asha', email: 'a@x.in');

class _FakeAuth implements AuthGateway {
  bool signedOut = false;

  @override
  bool get isAvailable => true;

  @override
  Stream<AuthUser?> userChanges() => const Stream<AuthUser?>.empty();

  @override
  Future<AuthUser?> currentUser() async => signedOut ? null : _asha;

  @override
  Future<AuthUser> signInWithGoogle() async => _asha;

  @override
  Future<AuthUser> signInWithEmail(String email, String password) async =>
      _asha;

  @override
  Future<AuthUser> registerWithEmail(
    String email,
    String password,
    String displayName,
  ) async =>
      _asha;

  @override
  Future<void> sendPasswordReset(String email) async {}

  @override
  Future<void> signOut() async => signedOut = true;
}

class _FakeHouseholds implements HouseholdGateway {
  HouseholdInfo? existing;
  HouseholdInfo? lookup;
  final List<String> cleared = <String>[];

  static const HouseholdInfo home = HouseholdInfo(
    id: 'h1',
    name: 'Our home',
    ownerId: 'u1',
    inviteCode: 'ABCD2345',
  );

  @override
  Future<HouseholdInfo?> findMine(String uid) async => existing;

  @override
  Future<HouseholdInfo> create(AuthUser user, String name) async =>
      HouseholdInfo(
        id: 'h1',
        name: name,
        ownerId: user.uid,
        inviteCode: 'ABCD2345',
      );

  @override
  Future<HouseholdInfo> join(AuthUser user, String code) async => home;

  @override
  Future<void> leave(String uid, String householdId) async {}

  @override
  Future<void> removeMember(String householdId, String memberUid) async {}

  @override
  Future<String> newInviteCode(String householdId, String oldCode) async =>
      'WXYZ6789';

  @override
  Stream<List<Member>> watchMembers(String householdId) =>
      const Stream<List<Member>>.empty();

  @override
  Future<HouseholdInfo?> get(String householdId) async => lookup;

  @override
  Future<void> clearPointer(String uid) async => cleared.add(uid);
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late _FakeAuth auth;
  late _FakeHouseholds households;
  late FakeSyncRemote remote;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    auth = _FakeAuth();
    households = _FakeHouseholds();
    remote = FakeSyncRemote();
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        authGatewayProvider.overrideWithValue(auth),
        householdGatewayProvider.overrideWithValue(households),
        syncRemoteProvider.overrideWithValue(remote),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<int> items() async {
    final List<QueryRow> rows =
        await db.customSelect('SELECT COUNT(*) AS c FROM items').get();
    return (rows.first.data['c']! as num).toInt();
  }

  Future<void> settle() async {
    for (int i = 0; i < 10; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  }

  test('creating a household keeps local data and uploads it', () async {
    await DriftPantryRepository(db).insertSampleData();
    final SyncController controller = container.read(syncControllerProvider);

    final HouseholdInfo info =
        await controller.createHousehold(_asha, 'Our home');
    await settle();

    expect(info.id, 'h1');
    expect(await items(), 10);
    expect(remote.count('items'), 10);
    final SyncIdentity id = await container.read(syncStoreProvider).identity();
    expect(id.householdId, 'h1');
    expect(id.userId, 'u1');
  });

  test('asks about local data only for a household not seen before', () async {
    final SyncController controller = container.read(syncControllerProvider);
    expect(await controller.mustAskAboutLocalData('h1'), isFalse);

    await DriftPantryRepository(db).insertSampleData();
    expect(await controller.mustAskAboutLocalData('h1'), isTrue);

    await controller.createHousehold(_asha, 'Our home');
    await settle();
    expect(await controller.mustAskAboutLocalData('h1'), isFalse);
    expect(await controller.mustAskAboutLocalData('h2'), isTrue);
  });

  test('joining and choosing a fresh start clears this phone first', () async {
    await DriftPantryRepository(db).insertSampleData();
    final SyncController controller = container.read(syncControllerProvider);

    await controller.joinHousehold(_asha, 'abcd-2345', keepLocalData: false);
    await settle();

    expect(await items(), 0);
    expect(remote.count('items'), 0);
  });

  test('a bad invite code is explained, not thrown as a crash', () async {
    final SyncController controller = container.read(syncControllerProvider);
    expect(
      () => controller.joinHousehold(_asha, 'nope', keepLocalData: true),
      throwsA(isA<AccountFailure>()),
    );
  });

  test('signing out keeps the pantry unless asked to clear it', () async {
    await DriftPantryRepository(db).insertSampleData();
    final SyncController controller = container.read(syncControllerProvider);
    await controller.createHousehold(_asha, 'Our home');
    await settle();

    await controller.signOut(clearData: false);
    expect(await items(), 10);
    expect(auth.signedOut, isTrue);
    expect(
      (await container.read(syncStoreProvider).identity()).isActive,
      isFalse,
    );

    await controller.signOut(clearData: true);
    expect(await items(), 0);
  });

  test('being removed from the household ends the sync but keeps data',
      () async {
    await DriftPantryRepository(db).insertSampleData();
    final SyncController controller = container.read(syncControllerProvider);
    await controller.createHousehold(_asha, 'Our home');
    await settle();

    households.lookup = null; // the household no longer lets this account in
    await controller.handleDenied();

    expect(await items(), 10);
    expect(households.cleared, <String>['u1']);
    expect(
      (await container.read(syncStoreProvider).identity()).householdId,
      isNull,
    );
    expect(container.read(syncEngineProvider).status.phase, SyncPhase.removed);
  });

  test('a refusal while still a member is not treated as removal', () async {
    final SyncController controller = container.read(syncControllerProvider);
    await controller.createHousehold(_asha, 'Our home');
    await settle();

    households.lookup = _FakeHouseholds.home;
    await controller.handleDenied();

    expect(
      (await container.read(syncStoreProvider).identity()).householdId,
      'h1',
    );
  });

  testWidgets('settings section says sync is not set up without Firebase',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsMapProvider.overrideWith(
            (ref) => Stream<Map<String, String>>.value(
              const <String, String>{},
            ),
          ),
          syncIdentityProvider.overrideWith(
            (ref) => Stream<SyncIdentity>.value(SyncIdentity.none),
          ),
        ],
        child: MaterialApp(
          theme: AkshayaTheme.light(),
          home: const Scaffold(body: SyncSection()),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Household & sync'), findsOneWidget);
    expect(find.text('Sync is not set up in this build'), findsOneWidget);
  });
}
