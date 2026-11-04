import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../../ai/data/firebase_runtime.dart';
import '../domain/account_gateways.dart';
import '../domain/invite_code.dart';
import '../domain/sync_models.dart';
import 'firebase_errors.dart';

/// [HouseholdGateway] on Cloud Firestore.
///
/// Layout (see firestore.rules):
/// - `households/{id}`: name, ownerId, inviteCode, createdAt
/// - `households/{id}/members/{uid}`: displayName, role, joinedAt
/// - `inviteCodes/{code}`: householdId (how a new member finds a household)
/// - `users/{uid}`: householdId (how a second phone finds the household)
///
/// Every change is a transaction, so it needs a connection and fails cleanly
/// without one.
class FirestoreHouseholdGateway implements HouseholdGateway {
  FirestoreHouseholdGateway(
    this._runtime, {
    Random? random,
    Uuid? uuid,
    DateTime Function()? clock,
  })  : _random = random,
        _uuid = uuid ?? const Uuid(),
        _clock = clock ?? DateTime.now;

  final FirebaseRuntime _runtime;
  final Random? _random;
  final Uuid _uuid;
  final DateTime Function() _clock;

  static const Duration _timeout = Duration(seconds: 20);

  Future<FirebaseFirestore> _firestore() async {
    await _runtime.ensureReady();
    return FirebaseFirestore.instance;
  }

  DocumentReference<Map<String, dynamic>> _household(
    FirebaseFirestore fs,
    String id,
  ) =>
      fs.collection('households').doc(id);

  DocumentReference<Map<String, dynamic>> _member(
    FirebaseFirestore fs,
    String household,
    String uid,
  ) =>
      _household(fs, household).collection('members').doc(uid);

  DocumentReference<Map<String, dynamic>> _pointer(
    FirebaseFirestore fs,
    String uid,
  ) =>
      fs.collection('users').doc(uid);

  DocumentReference<Map<String, dynamic>> _code(
    FirebaseFirestore fs,
    String code,
  ) =>
      fs.collection('inviteCodes').doc(code);

  static HouseholdInfo? _info(DocumentSnapshot<Map<String, dynamic>> snap) {
    final Map<String, dynamic>? data = snap.data();
    if (!snap.exists || data == null) {
      return null;
    }
    final dynamic name = data['name'];
    final dynamic owner = data['ownerId'];
    final dynamic code = data['inviteCode'];
    if (name is! String || owner is! String || code is! String) {
      return null;
    }
    return HouseholdInfo(
      id: snap.id,
      name: name,
      ownerId: owner,
      inviteCode: code,
    );
  }

  @override
  Future<HouseholdInfo?> findMine(String uid) async {
    try {
      final FirebaseFirestore fs = await _firestore();
      final DocumentSnapshot<Map<String, dynamic>> pointer = await _pointer(
        fs,
        uid,
      ).get(const GetOptions(source: Source.server)).timeout(_timeout);
      final dynamic id = pointer.data()?['householdId'];
      if (id is! String || id.isEmpty) {
        return null;
      }
      return get(id);
    } on Object catch (error) {
      throw accountFailureOf(error);
    }
  }

  @override
  Future<HouseholdInfo?> get(String householdId) async {
    try {
      final FirebaseFirestore fs = await _firestore();
      final DocumentSnapshot<Map<String, dynamic>> snap =
          await _household(fs, householdId)
              .get(const GetOptions(source: Source.server))
              .timeout(_timeout);
      return _info(snap);
    } on FirebaseException catch (error) {
      // Not a member (any more), or the household is gone.
      if (error.code == 'permission-denied' || error.code == 'not-found') {
        return null;
      }
      throw accountFailureOf(error);
    } on Object catch (error) {
      throw accountFailureOf(error);
    }
  }

  @override
  Future<HouseholdInfo> create(AuthUser user, String name) async {
    final String cleaned = name.trim();
    if (cleaned.isEmpty) {
      throw const AccountFailure('Give the household a name.');
    }
    final String id = _uuid.v4();
    final String code = InviteCode.generate(_random);
    final int now = _clock().millisecondsSinceEpoch;
    try {
      final FirebaseFirestore fs = await _firestore();
      await fs.runTransaction<void>(
        (Transaction tx) async {
          tx.set(_household(fs, id), <String, dynamic>{
            'id': id,
            'name': cleaned,
            'ownerId': user.uid,
            'inviteCode': code,
            'createdAt': now,
          });
          tx.set(_member(fs, id, user.uid), <String, dynamic>{
            'userId': user.uid,
            'displayName': user.displayName,
            'role': 'owner',
            'joinedAt': now,
          });
          tx.set(_code(fs, code), <String, dynamic>{
            'householdId': id,
            'ownerId': user.uid,
          });
          tx.set(_pointer(fs, user.uid), <String, dynamic>{'householdId': id});
        },
        timeout: _timeout,
        maxAttempts: 3,
      );
    } on Object catch (error) {
      throw accountFailureOf(error);
    }
    return HouseholdInfo(
      id: id,
      name: cleaned,
      ownerId: user.uid,
      inviteCode: code,
    );
  }

  @override
  Future<HouseholdInfo> join(AuthUser user, String code) async {
    final int now = _clock().millisecondsSinceEpoch;
    final String householdId;
    try {
      final FirebaseFirestore fs = await _firestore();
      householdId = await fs.runTransaction<String>(
        (Transaction tx) async {
          final DocumentSnapshot<Map<String, dynamic>> invite =
              await tx.get(_code(fs, code));
          final dynamic target = invite.data()?['householdId'];
          if (!invite.exists || target is! String) {
            throw const AccountFailure(
              'That invite code is not valid. Ask for a new one.',
            );
          }
          tx.set(_member(fs, target, user.uid), <String, dynamic>{
            'userId': user.uid,
            'displayName': user.displayName,
            'role': 'member',
            'inviteCode': code,
            'joinedAt': now,
          });
          tx.set(_pointer(fs, user.uid), <String, dynamic>{
            'householdId': target,
          });
          return target;
        },
        timeout: _timeout,
        maxAttempts: 3,
      );
    } on Object catch (error) {
      throw accountFailureOf(error);
    }
    final HouseholdInfo? info = await get(householdId);
    if (info == null) {
      throw const AccountFailure(
        'Joined, but the household could not be opened. Try again.',
      );
    }
    return info;
  }

  @override
  Future<void> leave(String uid, String householdId) async {
    try {
      final FirebaseFirestore fs = await _firestore();
      await fs.runTransaction<void>(
        (Transaction tx) async {
          tx.delete(_member(fs, householdId, uid));
          tx.delete(_pointer(fs, uid));
        },
        timeout: _timeout,
        maxAttempts: 3,
      );
    } on Object catch (error) {
      throw accountFailureOf(error);
    }
  }

  @override
  Future<void> removeMember(String householdId, String memberUid) async {
    try {
      final FirebaseFirestore fs = await _firestore();
      await _member(fs, householdId, memberUid).delete().timeout(_timeout);
    } on Object catch (error) {
      throw accountFailureOf(error);
    }
  }

  @override
  Future<String> newInviteCode(String householdId, String oldCode) async {
    final String code = InviteCode.generate(_random);
    try {
      final FirebaseFirestore fs = await _firestore();
      final DocumentSnapshot<Map<String, dynamic>> snap =
          await _household(fs, householdId)
              .get(const GetOptions(source: Source.server))
              .timeout(_timeout);
      final dynamic owner = snap.data()?['ownerId'];
      if (owner is! String) {
        throw const AccountFailure('The household could not be opened.');
      }
      await fs.runTransaction<void>(
        (Transaction tx) async {
          tx.update(_household(fs, householdId), <String, dynamic>{
            'inviteCode': code,
          });
          tx.delete(_code(fs, oldCode));
          tx.set(_code(fs, code), <String, dynamic>{
            'householdId': householdId,
            'ownerId': owner,
          });
        },
        timeout: _timeout,
        maxAttempts: 3,
      );
    } on Object catch (error) {
      throw accountFailureOf(error);
    }
    return code;
  }

  @override
  Stream<List<Member>> watchMembers(String householdId) async* {
    try {
      final FirebaseFirestore fs = await _firestore();
      await for (final QuerySnapshot<Map<String, dynamic>> snap
          in _household(fs, householdId).collection('members').snapshots()) {
        final List<Member> members = <Member>[];
        for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
            in snap.docs) {
          final Map<String, dynamic> data = doc.data();
          final dynamic name = data['displayName'];
          members.add(
            Member(
              userId: doc.id,
              displayName: name is String && name.trim().isNotEmpty
                  ? name.trim()
                  : 'Member',
              role: MemberRole.parse(
                data['role'] is String ? data['role'] as String : null,
              ),
            ),
          );
        }
        yield members;
      }
    } on Object catch (error) {
      throw mapSyncError(error);
    }
  }

  @override
  Future<void> clearPointer(String uid) async {
    try {
      final FirebaseFirestore fs = await _firestore();
      await _pointer(fs, uid).delete().timeout(_timeout);
    } on Object catch (error) {
      throw accountFailureOf(error);
    }
  }
}
