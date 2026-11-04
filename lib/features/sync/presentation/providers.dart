import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/clock.dart';
import '../../ai/data/firebase_runtime.dart';
import '../../ai/presentation/providers.dart' show firebaseRuntimeProvider;
import '../../alerts/domain/alert_plan.dart';
import '../../alerts/domain/notification_gateway.dart';
import '../../alerts/presentation/providers.dart'
    show notificationGatewayProvider;
import '../../pantry/presentation/providers.dart' show appDatabaseProvider;
import '../../settings/domain/settings_repository.dart';
import '../../settings/presentation/providers.dart';
import '../data/firebase_auth_gateway.dart';
import '../data/firestore_household_gateway.dart';
import '../data/firestore_sync_remote.dart';
import '../data/sync_engine.dart';
import '../data/sync_store.dart';
import '../domain/account_gateways.dart';
import '../domain/change_digest.dart';
import '../domain/invite_code.dart';
import '../domain/sync_models.dart';
import '../domain/sync_remote.dart';
import '../domain/sync_settings.dart';

// ---------------------------------------------------------------------------
// Building blocks (tests override these)
// ---------------------------------------------------------------------------

final Provider<AuthGateway> authGatewayProvider = Provider<AuthGateway>(
  (Ref ref) => FirebaseAuthGateway(ref.watch(firebaseRuntimeProvider)),
);

final Provider<HouseholdGateway> householdGatewayProvider =
    Provider<HouseholdGateway>((Ref ref) {
  return FirestoreHouseholdGateway(
    ref.watch(firebaseRuntimeProvider),
    clock: ref.watch(clockProvider),
  );
});

final Provider<SyncRemote> syncRemoteProvider = Provider<SyncRemote>(
  (Ref ref) => FirestoreSyncRemote(ref.watch(firebaseRuntimeProvider)),
);

final Provider<SyncStore> syncStoreProvider = Provider<SyncStore>((Ref ref) {
  return SyncStore(
    ref.watch(appDatabaseProvider),
    clock: ref.watch(clockProvider),
  );
});

/// The sync engine. It does nothing until [syncCoordinatorProvider] (or the
/// controller) attaches it to a household.
final Provider<SyncEngine> syncEngineProvider = Provider<SyncEngine>((Ref ref) {
  final List<RemoteChange> buffered = <RemoteChange>[];
  Timer? alertTimer;
  int pendingReads = 0;
  int pendingWrites = 0;
  Timer? usageTimer;

  final SyncEngine engine = SyncEngine(
    store: ref.watch(syncStoreProvider),
    remote: ref.watch(syncRemoteProvider),
    clock: ref.watch(clockProvider),
    onChanges: (List<RemoteChange> changes) {
      // A burst of changes becomes one notification.
      buffered.addAll(changes);
      alertTimer?.cancel();
      alertTimer = Timer(const Duration(seconds: 4), () {
        final List<RemoteChange> batch = List<RemoteChange>.of(buffered);
        buffered.clear();
        unawaited(_notifyHouseholdChanges(ref, batch));
      });
    },
    onUsage: ({int reads = 0, int writes = 0}) {
      // Counts are saved every half minute, not on every document, so the
      // settings (and the alerts that watch them) are not stirred up.
      pendingReads += reads;
      pendingWrites += writes;
      usageTimer ??= Timer(const Duration(seconds: 30), () {
        usageTimer = null;
        final int r = pendingReads;
        final int w = pendingWrites;
        pendingReads = 0;
        pendingWrites = 0;
        unawaited(_recordUsage(ref, r, w));
      });
    },
    onDenied: () => ref.read(syncControllerProvider).handleDenied(),
  );

  ref.onDispose(() {
    alertTimer?.cancel();
    usageTimer?.cancel();
    unawaited(engine.dispose());
  });
  return engine;
});

Future<void> _notifyHouseholdChanges(
  Ref ref,
  List<RemoteChange> changes,
) async {
  try {
    final Map<String, String> names =
        await ref.read(syncStoreProvider).memberNames();
    final List<String> shopping = ChangeDigest.shoppingLines(changes, names);
    final List<String> pantry = ChangeDigest.pantryLines(changes, names);
    final List<AlertNotification> alerts = <AlertNotification>[
      if (shopping.isNotEmpty)
        AlertNotification(
          id: 4301,
          target: AlertTarget.householdShopping,
          channel: AlertChannelKind.household,
          title: shopping.length == 1 ? shopping.first : 'Shopping list updated',
          body: shopping.join('\n'),
        ),
      if (pantry.isNotEmpty)
        AlertNotification(
          id: 4302,
          target: AlertTarget.householdPantry,
          channel: AlertChannelKind.household,
          title: pantry.length == 1 ? pantry.first : 'Pantry updated',
          body: pantry.join('\n'),
        ),
    ];
    if (alerts.isEmpty) {
      return;
    }
    final NotificationGateway gateway = ref.read(notificationGatewayProvider);
    await gateway.initialize();
    await gateway.showNow(alerts);
  } on Object catch (error) {
    debugPrint('Could not show the household alert: $error');
  }
}

Future<void> _recordUsage(Ref ref, int reads, int writes) async {
  if (reads == 0 && writes == 0) {
    return;
  }
  try {
    final SettingsRepository settings = ref.read(settingsRepositoryProvider);
    final FirestoreUsage current =
        FirestoreUsage.fromMap(await settings.readAll());
    final DateTime now = ref.read(clockProvider)();
    final String today = '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    await settings.writeAll(
      current.add(today, moreReads: reads, moreWrites: writes).toMap(),
    );
  } on Object catch (error) {
    debugPrint('Could not save Firestore usage: $error');
  }
}

// ---------------------------------------------------------------------------
// What the screens watch
// ---------------------------------------------------------------------------

/// Who and which household this phone syncs as (from the local database, so
/// it is known without starting Firebase).
final StreamProvider<SyncIdentity> syncIdentityProvider =
    StreamProvider<SyncIdentity>(
  (Ref ref) => ref.watch(syncStoreProvider).watchIdentity(),
);

/// The saved sync settings.
final Provider<SyncSettings> syncSettingsProvider = Provider<SyncSettings>((
  Ref ref,
) {
  final Map<String, String> stored =
      ref.watch(settingsMapProvider).value ?? const <String, String>{};
  return SyncSettings.fromMap(stored);
});

/// Firestore reads and writes made today (an estimate).
final Provider<FirestoreUsage> firestoreUsageProvider =
    Provider<FirestoreUsage>((Ref ref) {
  final Map<String, String> stored =
      ref.watch(settingsMapProvider).value ?? const <String, String>{};
  return FirestoreUsage.fromMap(stored);
});

/// The sync indicator.
final StreamProvider<SyncStatusInfo> syncStatusProvider =
    StreamProvider<SyncStatusInfo>((Ref ref) async* {
  final SyncEngine engine = ref.watch(syncEngineProvider);
  yield engine.status;
  yield* engine.statusStream;
});

/// Rows waiting to be sent.
final StreamProvider<int> pendingCountProvider = StreamProvider<int>(
  (Ref ref) => ref.watch(syncStoreProvider).watchPendingCount(),
);

/// The household's members as last seen.
final StreamProvider<List<Member>> householdMembersProvider =
    StreamProvider<List<Member>>(
  (Ref ref) => ref.watch(syncStoreProvider).watchMembers(),
);

// ---------------------------------------------------------------------------
// Actions
// ---------------------------------------------------------------------------

/// A person who just signed in, and the household they already belong to
/// (from another phone, say), if any.
final class SignInOutcome {
  const SignInOutcome({required this.user, this.household});

  final AuthUser user;
  final HouseholdInfo? household;
}

final Provider<SyncController> syncControllerProvider =
    Provider<SyncController>((Ref ref) => SyncController(ref));

/// Everything the sync screens do. Methods throw `AccountFailure` with a
/// message safe to show.
class SyncController {
  SyncController(this._ref);

  final Ref _ref;

  SyncStore get _store => _ref.read(syncStoreProvider);
  AuthGateway get _auth => _ref.read(authGatewayProvider);
  HouseholdGateway get _households => _ref.read(householdGatewayProvider);
  SyncEngine get _engine => _ref.read(syncEngineProvider);
  SettingsRepository get _settings => _ref.read(settingsRepositoryProvider);

  /// False in a build without Firebase settings.
  bool get isAvailable => _auth.isAvailable;

  Future<SignInOutcome> signInWithGoogle() =>
      _afterSignIn(() => _auth.signInWithGoogle());

  Future<SignInOutcome> signInWithEmail(String email, String password) =>
      _afterSignIn(() => _auth.signInWithEmail(email, password));

  Future<SignInOutcome> register(
    String email,
    String password,
    String displayName,
  ) =>
      _afterSignIn(() => _auth.registerWithEmail(email, password, displayName));

  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordReset(email);

  Future<AuthUser?> currentUser() => _auth.currentUser();

  Future<SignInOutcome> _afterSignIn(Future<AuthUser> Function() signIn) async {
    final AuthUser user = await signIn();
    await _settings.writeAll(<String, String>{
      SyncSettingKeys.userName: user.displayName,
      SyncSettingKeys.userEmail: user.email ?? '',
    });
    HouseholdInfo? household;
    try {
      household = await _households.findMine(user.uid);
    } on AccountFailure {
      // Offline, say: the person can still create or join one.
      household = null;
    }
    return SignInOutcome(user: user, household: household);
  }

  /// Whether the pantry on this phone holds data the person should decide
  /// about before it meets [householdId]'s data.
  Future<bool> mustAskAboutLocalData(String householdId) async {
    final SyncSettings stored = SyncSettings.fromMap(await _settings.readAll());
    if (stored.lastHouseholdId == householdId) {
      return false;
    }
    return _store.hasLocalData();
  }

  Future<bool> hasLocalData() => _store.hasLocalData();

  Future<HouseholdInfo> createHousehold(AuthUser user, String name) async {
    final HouseholdInfo household = await _households.create(user, name);
    await activate(user: user, household: household, keepLocalData: true);
    return household;
  }

  Future<HouseholdInfo> joinHousehold(
    AuthUser user,
    String rawCode, {
    required bool keepLocalData,
  }) async {
    final String? code = InviteCode.normalize(rawCode);
    if (code == null) {
      throw const AccountFailure(
        'That does not look like an invite code. It has 8 letters and digits.',
      );
    }
    final HouseholdInfo household = await _households.join(user, code);
    await activate(user: user, household: household, keepLocalData: keepLocalData);
    return household;
  }

  /// Makes [household] this phone's household and starts syncing. With
  /// [keepLocalData] false the pantry on this phone is cleared first.
  Future<void> activate({
    required AuthUser user,
    required HouseholdInfo household,
    required bool keepLocalData,
  }) async {
    final SyncSettings stored = SyncSettings.fromMap(await _settings.readAll());
    final bool changed = stored.lastHouseholdId != household.id;
    if (!keepLocalData) {
      await _store.clearLocalData();
    }
    await _settings.writeAll(<String, String>{
      SyncSettingKeys.householdName: household.name,
      SyncSettingKeys.inviteCode: household.inviteCode,
      SyncSettingKeys.lastHouseholdId: household.id,
      SyncSettingKeys.userName: user.displayName,
      SyncSettingKeys.userEmail: user.email ?? '',
      SyncSettingKeys.enabled: 'true',
    });
    // Identity first, so the coordinator sees the pair it will attach to and
    // does not detach in between.
    await _store.setIdentity(householdId: household.id, userId: user.uid);
    await _engine.attach(
      householdId: household.id,
      userId: user.uid,
      resetCursors: changed || !keepLocalData,
    );
  }

  /// A member (not the owner) leaves; the person stays signed in.
  Future<void> leaveHousehold() async {
    final SyncIdentity id = await _store.identity();
    final String? household = id.householdId;
    final String? user = id.userId;
    if (household == null || user == null) {
      return;
    }
    await _households.leave(user, household);
    await _engine.detach();
    await _store.setIdentity(userId: user);
    await _store.replaceMembers(const <Member>[]);
    await _clearHouseholdSettings();
  }

  /// Signs out. The pantry stays on the phone unless [clearData] is true.
  Future<void> signOut({required bool clearData}) async {
    await _engine.detach();
    await _store.setIdentity();
    await _store.replaceMembers(const <Member>[]);
    try {
      await _auth.signOut();
    } on AccountFailure {
      // The local state is already signed out; nothing to undo.
    }
    await _settings.writeAll(<String, String>{
      SyncSettingKeys.userName: '',
      SyncSettingKeys.userEmail: '',
      SyncSettingKeys.householdName: '',
      SyncSettingKeys.inviteCode: '',
    });
    if (clearData) {
      await _store.clearLocalData();
      await _settings.remove(SyncSettingKeys.lastHouseholdId);
    }
  }

  Future<void> setEnabled(bool enabled) {
    return _settings.writeAll(<String, String>{
      SyncSettingKeys.enabled: enabled.toString(),
    });
  }

  Future<void> syncNow() => _engine.syncNow();

  /// The owner removes another member.
  Future<void> removeMember(String memberUid) async {
    final SyncIdentity id = await _store.identity();
    final String? household = id.householdId;
    if (household == null) {
      return;
    }
    await _households.removeMember(household, memberUid);
  }

  /// The owner replaces the invite code. Returns the new code.
  Future<String> newInviteCode() async {
    final SyncIdentity id = await _store.identity();
    final String? household = id.householdId;
    final SyncSettings stored = SyncSettings.fromMap(await _settings.readAll());
    final String? old = stored.inviteCode;
    if (household == null || old == null) {
      throw const AccountFailure('Open the household first.');
    }
    final String code = await _households.newInviteCode(household, old);
    await _settings.writeAll(<String, String>{SyncSettingKeys.inviteCode: code});
    return code;
  }

  /// Reads the household document again (name, invite code). Failures are
  /// ignored, except that finding out the account is no longer a member
  /// ends the sync.
  Future<void> refreshHousehold() async {
    final SyncIdentity id = await _store.identity();
    final String? household = id.householdId;
    if (household == null) {
      return;
    }
    try {
      final HouseholdInfo? info = await _households.get(household);
      if (info == null) {
        await handleDenied();
        return;
      }
      await _settings.writeAll(<String, String>{
        SyncSettingKeys.householdName: info.name,
        SyncSettingKeys.inviteCode: info.inviteCode,
      });
    } on AccountFailure {
      // Offline or busy: the saved values stay.
    }
  }

  /// The cloud refused this account. If it is no longer a member of the
  /// household, the sync ends and the pantry stays on the phone.
  Future<void> handleDenied() async {
    final SyncIdentity id = await _store.identity();
    final String? household = id.householdId;
    final String? user = id.userId;
    if (household == null || user == null) {
      return;
    }
    HouseholdInfo? info;
    try {
      info = await _households.get(household);
    } on AccountFailure {
      return;
    }
    if (info != null) {
      // Still a member: the refusal was something else.
      return;
    }
    await _engine.markRemoved();
    await _store.setIdentity(userId: user);
    await _store.replaceMembers(const <Member>[]);
    await _clearHouseholdSettings();
    try {
      await _households.clearPointer(user);
    } on AccountFailure {
      // The pointer is cleaned up the next time it is read.
    }
  }

  Future<void> _clearHouseholdSettings() {
    return _settings.writeAll(<String, String>{
      SyncSettingKeys.householdName: '',
      SyncSettingKeys.inviteCode: '',
    });
  }
}

// ---------------------------------------------------------------------------
// Keeping the engine running
// ---------------------------------------------------------------------------

/// Starts and stops the sync engine as the identity and the sync switch
/// change, keeps the member list fresh, and pushes edits soon after they are
/// made. Read once at start-up.
///
/// Firebase itself starts only when someone is signed in to a household, so a
/// phone that never signs in never loads it.
final Provider<void> syncCoordinatorProvider = Provider<void>((Ref ref) {
  final SyncStore store = ref.watch(syncStoreProvider);
  final SyncEngine engine = ref.watch(syncEngineProvider);
  StreamSubscription<List<Member>>? membersSubscription;
  String? membersFor;
  Timer? pushTimer;
  bool disposed = false;

  Future<void> evaluate() async {
    if (disposed) {
      return;
    }
    try {
      final SyncIdentity id =
          ref.read(syncIdentityProvider).value ?? await store.identity();
      final bool enabled = ref.read(syncSettingsProvider).enabled;
      final String? household = id.householdId;
      final String? user = id.userId;

      if (!FirebaseBuildConfig.isConfigured ||
          household == null ||
          user == null ||
          !enabled) {
        await membersSubscription?.cancel();
        membersSubscription = null;
        membersFor = null;
        if (engine.isAttached) {
          await engine.detach();
        }
        return;
      }

      await engine.attach(householdId: household, userId: user);
      if (membersFor != household) {
        await membersSubscription?.cancel();
        membersFor = household;
        membersSubscription =
            ref.read(householdGatewayProvider).watchMembers(household).listen(
          (List<Member> members) => unawaited(store.replaceMembers(members)),
          onError: (Object error, StackTrace stack) {
            if (error is SyncException && error.kind == SyncErrorKind.denied) {
              unawaited(ref.read(syncControllerProvider).handleDenied());
            }
          },
        );
        unawaited(ref.read(syncControllerProvider).refreshHousehold());
      }
    } on Object catch (error) {
      debugPrint('Could not start sync: $error');
    }
  }

  ref.listen<AsyncValue<SyncIdentity>>(
    syncIdentityProvider,
    (AsyncValue<SyncIdentity>? previous, AsyncValue<SyncIdentity> next) =>
        unawaited(evaluate()),
    fireImmediately: true,
  );
  ref.listen<SyncSettings>(
    syncSettingsProvider,
    (SyncSettings? previous, SyncSettings next) {
      if (previous?.enabled != next.enabled) {
        unawaited(evaluate());
      }
    },
  );
  ref.listen<AsyncValue<int>>(
    pendingCountProvider,
    (AsyncValue<int>? previous, AsyncValue<int> next) {
      final int? count = next.value;
      if (count == null || count == 0) {
        return;
      }
      pushTimer?.cancel();
      pushTimer = Timer(const Duration(seconds: 3), () {
        if (disposed || !engine.isAttached) {
          return;
        }
        final SyncPhase phase = engine.status.phase;
        // A retry is already scheduled for these; asking again would only
        // repeat the failure.
        if (phase == SyncPhase.offline ||
            phase == SyncPhase.quotaReached ||
            phase == SyncPhase.removed) {
          return;
        }
        unawaited(engine.syncNow());
      });
    },
  );

  ref.onDispose(() {
    disposed = true;
    pushTimer?.cancel();
    unawaited(membersSubscription?.cancel());
  });
});
