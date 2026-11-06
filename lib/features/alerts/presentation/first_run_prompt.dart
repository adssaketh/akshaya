import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/diagnostics/diag.dart';
import '../../settings/domain/settings_repository.dart';
import '../../settings/presentation/providers.dart';
import '../domain/alert_settings.dart';
import '../domain/notification_gateway.dart';
import 'providers.dart';

/// On the first launch, explains the daily alert and offers to allow
/// notifications. Asked once: whatever the person answers, the prompt is
/// remembered and never shown again (Settings has the switch and a banner).
Future<void> askForNotificationsOnFirstRun(
  BuildContext context,
  WidgetRef ref,
) async {
  final SettingsRepository repository = ref.read(settingsRepositoryProvider);
  final NotificationGateway gateway = ref.read(notificationGatewayProvider);
  try {
    final Map<String, String> stored = await repository.readAll();
    if (stored[AlertSettingKeys.permissionPrompted] == 'true') {
      return;
    }
    if (!AlertSettings.fromMap(stored).enabled) {
      return;
    }
    if (await gateway.areNotificationsAllowed()) {
      await repository.writeAll(
        const <String, String>{AlertSettingKeys.permissionPrompted: 'true'},
      );
      return;
    }
    if (!context.mounted) {
      return;
    }

    final bool? agreed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Daily expiry alerts'),
          content: const Text(
            'Akshaya Patra can remind you each morning about food that is '
            'expiring or running low. To do that it needs permission to show '
            'notifications. You can change the time or switch the alert off '
            'in Settings.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Not now'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Allow'),
            ),
          ],
        );
      },
    );

    await repository.writeAll(
      const <String, String>{AlertSettingKeys.permissionPrompted: 'true'},
    );
    if (agreed ?? false) {
      await gateway.requestPermission();
      ref.invalidate(notificationsAllowedProvider);
    }
  } on Object catch (error, stack) {
    Diag.error('alerts', 'Notification prompt failed', error: error, stack: stack);
  }
}
