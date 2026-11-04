import 'sync_models.dart';

/// Sign-in. The real implementation uses Firebase Auth (Google and
/// email/password); tests use a fake. Methods throw `AccountFailure` with a
/// message safe to show.
abstract interface class AuthGateway {
  /// False in a build without Firebase settings.
  bool get isAvailable;

  /// The signed-in person now and whenever it changes (null when signed out).
  Stream<AuthUser?> userChanges();

  Future<AuthUser?> currentUser();

  Future<AuthUser> signInWithGoogle();

  Future<AuthUser> signInWithEmail(String email, String password);

  Future<AuthUser> registerWithEmail(
    String email,
    String password,
    String displayName,
  );

  Future<void> sendPasswordReset(String email);

  Future<void> signOut();
}

/// Households and their members. Methods throw `AccountFailure` with a
/// message safe to show.
abstract interface class HouseholdGateway {
  /// The household this person already belongs to (on another phone, say), or
  /// null.
  Future<HouseholdInfo?> findMine(String uid);

  Future<HouseholdInfo> create(AuthUser user, String name);

  /// Joins with an invite code (already normalised).
  Future<HouseholdInfo> join(AuthUser user, String code);

  /// A member leaves. The owner cannot leave.
  Future<void> leave(String uid, String householdId);

  /// The owner removes another member.
  Future<void> removeMember(String householdId, String memberUid);

  /// Makes a new invite code and retires [oldCode]. Returns the new code.
  Future<String> newInviteCode(String householdId, String oldCode);

  /// The household's members now and whenever they change. Fails with a
  /// `SyncException` of kind `denied` when this account is no longer a member.
  Stream<List<Member>> watchMembers(String householdId);

  /// The household document, or null when it is gone or this account is not a
  /// member.
  Future<HouseholdInfo?> get(String householdId);

  /// Forgets which household this account belongs to.
  Future<void> clearPointer(String uid);
}
