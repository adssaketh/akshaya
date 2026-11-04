/// The signed-in person, as far as the app needs to know.
final class AuthUser {
  const AuthUser({
    required this.uid,
    required this.displayName,
    this.email,
  });

  final String uid;

  /// Shown to other household members. Never empty.
  final String displayName;
  final String? email;
}

/// A household the person belongs to.
final class HouseholdInfo {
  const HouseholdInfo({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.inviteCode,
  });

  final String id;
  final String name;
  final String ownerId;

  /// Eight letters and digits, no dash.
  final String inviteCode;

  bool isOwner(String uid) => ownerId == uid;
}

enum MemberRole {
  owner,
  member;

  static MemberRole parse(String? value) =>
      value == 'owner' ? MemberRole.owner : MemberRole.member;
}

/// One person in a household.
final class Member {
  const Member({
    required this.userId,
    required this.displayName,
    required this.role,
  });

  final String userId;
  final String displayName;
  final MemberRole role;
}

/// Who and where the local database syncs to (`sync_state`).
final class SyncIdentity {
  const SyncIdentity({this.householdId, this.userId});

  static const SyncIdentity none = SyncIdentity();

  final String? householdId;
  final String? userId;

  bool get isActive => householdId != null && userId != null;

  @override
  bool operator ==(Object other) =>
      other is SyncIdentity &&
      other.householdId == householdId &&
      other.userId == userId;

  @override
  int get hashCode => Object.hash(householdId, userId);
}

/// What the sync indicator shows.
enum SyncPhase {
  /// Not signed in, no household, or sync switched off.
  off,

  /// Signed in and waiting.
  idle,

  /// Sending or receiving now.
  syncing,

  /// Everything sent and received.
  synced,

  /// No connection; will retry.
  offline,

  /// Something went wrong; will retry.
  error,

  /// The free daily Firestore quota is used up; will retry later.
  quotaReached,

  /// This account is no longer a member of the household.
  removed,
}

final class SyncStatusInfo {
  const SyncStatusInfo({
    this.phase = SyncPhase.off,
    this.lastSyncedAt,
    this.message,
    this.pending = 0,
  });

  final SyncPhase phase;
  final DateTime? lastSyncedAt;

  /// A one-line reason for [SyncPhase.offline], [SyncPhase.error] and
  /// [SyncPhase.quotaReached].
  final String? message;

  /// Changes waiting to be sent.
  final int pending;

  SyncStatusInfo copyWith({
    SyncPhase? phase,
    DateTime? lastSyncedAt,
    String? message,
    bool clearMessage = false,
    int? pending,
  }) {
    return SyncStatusInfo(
      phase: phase ?? this.phase,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      message: clearMessage ? null : (message ?? this.message),
      pending: pending ?? this.pending,
    );
  }
}

enum SyncErrorKind {
  /// No connection or the server could not be reached.
  offline,

  /// The free Firestore quota is used up.
  quota,

  /// The server refused: usually this account was removed from the household.
  denied,

  /// The sign-in is no longer valid.
  signedOut,

  /// Anything else.
  other,
}

/// A problem talking to the cloud, with a message safe to show.
final class SyncException implements Exception {
  const SyncException(this.kind, this.message);

  final SyncErrorKind kind;
  final String message;

  @override
  String toString() => 'SyncException($kind): $message';
}

/// A problem with sign-in or households, with a message safe to show.
final class AccountFailure implements Exception {
  const AccountFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
