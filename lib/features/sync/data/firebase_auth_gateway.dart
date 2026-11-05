import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../ai/data/firebase_runtime.dart';
import '../domain/account_gateways.dart';
import '../domain/sync_models.dart';
import 'firebase_errors.dart';

/// [AuthGateway] on Firebase Auth: Google and email/password. Firebase starts
/// when this is first used, never at app start.
class FirebaseAuthGateway implements AuthGateway {
  FirebaseAuthGateway(this._runtime);

  final FirebaseRuntime _runtime;
  bool _googleReady = false;

  @override
  bool get isAvailable => FirebaseBuildConfig.isConfigured;

  Future<FirebaseAuth> _auth() async {
    await _runtime.ensureReady();
    return FirebaseAuth.instance;
  }

  static AuthUser? _toUser(User? user) {
    if (user == null) {
      return null;
    }
    final String? name = user.displayName?.trim();
    final String? email = user.email;
    String shown = 'Member';
    if (name != null && name.isNotEmpty) {
      shown = name;
    } else if (email != null && email.contains('@')) {
      shown = email.split('@').first;
    }
    return AuthUser(uid: user.uid, displayName: shown, email: email);
  }

  static AuthUser _require(User? user) {
    final AuthUser? mapped = _toUser(user);
    if (mapped == null) {
      throw const AccountFailure('Sign-in did not finish. Please try again.');
    }
    return mapped;
  }

  @override
  Stream<AuthUser?> userChanges() async* {
    try {
      final FirebaseAuth auth = await _auth();
      yield* auth.userChanges().map(_toUser);
    } on Object catch (error) {
      throw accountFailureOf(error);
    }
  }

  @override
  Future<AuthUser?> currentUser() async {
    try {
      final FirebaseAuth auth = await _auth();
      // The first event carries the person restored from the last session.
      final User? user = await auth.authStateChanges().first;
      return _toUser(user);
    } on Object catch (error) {
      throw accountFailureOf(error);
    }
  }

  @override
  Future<AuthUser> signInWithGoogle() async {
    try {
      final FirebaseAuth auth = await _auth();
      final GoogleSignIn google = GoogleSignIn.instance;
      if (!_googleReady) {
        await google.initialize(
          serverClientId: FirebaseBuildConfig.webClientId.isEmpty
              ? null
              : FirebaseBuildConfig.webClientId,
        );
        _googleReady = true;
      }
      final GoogleSignInAccount account = await google.authenticate();
      final String? idToken = account.authentication.idToken;
      if (idToken == null) {
        throw const AccountFailure('Google did not return a sign-in token.');
      }
      final AuthCredential credential =
          GoogleAuthProvider.credential(idToken: idToken);
      final UserCredential result = await auth.signInWithCredential(credential);
      return _require(result.user);
    } on GoogleSignInException catch (error) {
      // Android reports a rejected app key (wrong SHA-1, client not ready yet)
      // as "cancelled" too, so the message covers both.
      final String detail = error.description ?? error.code.name;
      if (error.code == GoogleSignInExceptionCode.canceled) {
        throw AccountFailure(
          'Google sign-in was cancelled or not accepted ($detail). If you did '
          'not cancel it, check that this build\'s SHA-1 is registered in '
          'Firebase and that a Google account is on this phone.',
        );
      }
      throw AccountFailure(
        'Google sign-in did not work ($detail). Check that this build\'s '
        'SHA-1 key is added to the Firebase project, or use email and password.',
      );
    } on FirebaseAuthException catch (error) {
      throw _authFailure(error);
    } on Object catch (error) {
      throw accountFailureOf(error);
    }
  }

  @override
  Future<AuthUser> signInWithEmail(String email, String password) async {
    try {
      final FirebaseAuth auth = await _auth();
      final UserCredential result = await auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return _require(result.user);
    } on FirebaseAuthException catch (error) {
      throw _authFailure(error);
    } on Object catch (error) {
      throw accountFailureOf(error);
    }
  }

  @override
  Future<AuthUser> registerWithEmail(
    String email,
    String password,
    String displayName,
  ) async {
    try {
      final FirebaseAuth auth = await _auth();
      final UserCredential result = await auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final User? user = result.user;
      final String name = displayName.trim();
      if (user != null && name.isNotEmpty) {
        await user.updateDisplayName(name);
        await user.reload();
      }
      return _require(auth.currentUser ?? user);
    } on FirebaseAuthException catch (error) {
      throw _authFailure(error);
    } on Object catch (error) {
      throw accountFailureOf(error);
    }
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    try {
      final FirebaseAuth auth = await _auth();
      await auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (error) {
      throw _authFailure(error);
    } on Object catch (error) {
      throw accountFailureOf(error);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      final FirebaseAuth auth = await _auth();
      await auth.signOut();
      if (_googleReady) {
        await GoogleSignIn.instance.signOut();
      }
    } on Object catch (error) {
      throw accountFailureOf(error);
    }
  }

  static AccountFailure _authFailure(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-email':
        return const AccountFailure('That email address does not look right.');
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return const AccountFailure('The email or password is not right.');
      case 'user-disabled':
        return const AccountFailure('This account has been disabled.');
      case 'email-already-in-use':
        return const AccountFailure(
          'An account with this email already exists. Sign in instead.',
        );
      case 'weak-password':
        return const AccountFailure(
          'Choose a longer password (at least 6 characters).',
        );
      case 'network-request-failed':
        return const AccountFailure('No internet connection. Try again online.');
      case 'too-many-requests':
        return const AccountFailure('Too many attempts. Try again later.');
      case 'operation-not-allowed':
        return const AccountFailure(
          'This sign-in method is not switched on in the Firebase project '
          '(Authentication, Sign-in method).',
        );
      case 'account-exists-with-different-credential':
        return const AccountFailure(
          'This email is already used with another sign-in method.',
        );
    }
    return const AccountFailure('Sign-in failed. Please try again.');
  }
}
