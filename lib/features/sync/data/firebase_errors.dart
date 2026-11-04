import 'dart:async';

import 'package:firebase_core/firebase_core.dart';

import '../domain/sync_models.dart';

/// Turns whatever Firebase threw into a [SyncException] with a message that is
/// safe to show.
SyncException mapSyncError(Object error) {
  if (error is SyncException) {
    return error;
  }
  if (error is TimeoutException) {
    return const SyncException(
      SyncErrorKind.offline,
      'No connection. Changes are kept and will be sent later.',
    );
  }
  if (error is FirebaseException) {
    switch (error.code) {
      case 'unavailable':
      case 'deadline-exceeded':
      case 'network-request-failed':
      case 'cancelled':
        return const SyncException(
          SyncErrorKind.offline,
          'No connection. Changes are kept and will be sent later.',
        );
      case 'resource-exhausted':
        return const SyncException(
          SyncErrorKind.quota,
          "Today's free sync limit is used up. Sync resumes automatically.",
        );
      case 'permission-denied':
        return const SyncException(
          SyncErrorKind.denied,
          'The server refused the sync. You may have been removed from the '
          'household.',
        );
      case 'unauthenticated':
        return const SyncException(
          SyncErrorKind.signedOut,
          'Your sign-in expired. Sign in again to keep syncing.',
        );
    }
  }
  return const SyncException(
    SyncErrorKind.other,
    'Sync did not finish. It will try again.',
  );
}

/// The same, as a message for sign-in and household screens.
AccountFailure accountFailureOf(Object error) {
  if (error is AccountFailure) {
    return error;
  }
  final SyncException mapped = mapSyncError(error);
  switch (mapped.kind) {
    case SyncErrorKind.offline:
      return const AccountFailure('No internet connection. Try again online.');
    case SyncErrorKind.quota:
      return const AccountFailure(
        "Today's free limit is used up. Try again tomorrow.",
      );
    case SyncErrorKind.denied:
      return const AccountFailure(
        'That was refused. The invite code may be wrong or replaced.',
      );
    case SyncErrorKind.signedOut:
      return const AccountFailure('Please sign in again.');
    case SyncErrorKind.other:
      return const AccountFailure('Something went wrong. Please try again.');
  }
}
