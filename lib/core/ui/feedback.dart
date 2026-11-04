import 'package:flutter/material.dart';

import '../../features/pantry/domain/failures.dart';

/// Text safe to show for any error: the failure's own message, or a generic
/// line for anything unexpected.
String failureMessage(Object error) {
  if (error is PantryFailure) {
    return error.message;
  }
  return 'Something went wrong. Please try again.';
}

/// Shows a plain message.
void showMessage(ScaffoldMessengerState messenger, String message) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Shows [message] with an Undo button that runs [onUndo]. Every destructive
/// action in the app uses this.
void showUndoSnackBar(
  ScaffoldMessengerState messenger, {
  required String message,
  required Future<void> Function() onUndo,
}) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            try {
              await onUndo();
            } on Object catch (error) {
              showMessage(messenger, failureMessage(error));
            }
          },
        ),
      ),
    );
}
