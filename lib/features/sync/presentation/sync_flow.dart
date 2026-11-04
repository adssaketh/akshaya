import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/feedback.dart';
import '../domain/sync_models.dart';
import 'household_setup_screen.dart';
import 'providers.dart';
import 'sign_in_screen.dart';
import 'sync_ui.dart';

/// What to do with the pantry already on this phone when joining a household.
enum LocalDataChoice { upload, replace }

/// Asks whether the pantry on this phone is uploaded to the household or
/// replaced by the household's. Null when cancelled.
Future<LocalDataChoice?> askAboutLocalData(
  BuildContext context,
  String householdName,
) {
  return showDialog<LocalDataChoice>(
    context: context,
    builder: (BuildContext dialog) => AlertDialog(
      title: const Text('Your pantry on this phone'),
      content: Text(
        'This phone already has pantry data. Add it to "$householdName", or '
        'start with only what the household has? Starting fresh clears this '
        'phone\'s pantry.',
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialog).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialog).pop(LocalDataChoice.replace),
          child: const Text('Start fresh'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialog).pop(LocalDataChoice.upload),
          child: const Text('Add my data'),
        ),
      ],
    ),
  );
}

/// Sign in, then join the household the account already has, or let the
/// person create or join one.
Future<void> startSignInFlow(BuildContext context, WidgetRef ref) async {
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  final SignInOutcome? outcome = await Navigator.of(context).push<SignInOutcome>(
    MaterialPageRoute<SignInOutcome>(
      builder: (BuildContext _) => const SignInScreen(),
    ),
  );
  if (outcome == null || !context.mounted) {
    return;
  }
  final HouseholdInfo? existing = outcome.household;
  if (existing == null) {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext _) => HouseholdSetupScreen(user: outcome.user),
      ),
    );
    return;
  }
  final SyncController controller = ref.read(syncControllerProvider);
  try {
    bool keep = true;
    if (await controller.mustAskAboutLocalData(existing.id)) {
      if (!context.mounted) {
        return;
      }
      final LocalDataChoice? choice =
          await askAboutLocalData(context, existing.name);
      if (choice == null) {
        return;
      }
      keep = choice == LocalDataChoice.upload;
    }
    await controller.activate(
      user: outcome.user,
      household: existing,
      keepLocalData: keep,
    );
    showMessage(messenger, 'Signed in. Syncing "${existing.name}".');
  } on Object catch (error) {
    showMessage(messenger, syncFailureMessage(error));
  }
}
