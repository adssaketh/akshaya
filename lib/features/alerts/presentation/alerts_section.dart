import 'package:akshaya/core/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/diagnostics/diag.dart';
import '../../../core/ui/feedback.dart';
import '../../pantry/domain/entities.dart';
import '../../pantry/presentation/providers.dart';
import '../../settings/domain/settings_repository.dart';
import '../../settings/presentation/providers.dart';
import '../../shopping/domain/shopping_entities.dart';
import '../../shopping/presentation/providers.dart';
import '../domain/alert_plan.dart';
import '../domain/alert_settings.dart';
import '../domain/notification_gateway.dart';
import 'providers.dart';

/// The "Alerts" block of the Settings tab: the daily alert's switch, time,
/// "expiring soon" window and low-stock option, plus a permission banner and a
/// preview button. Phase 8 moves it into the full Settings screen unchanged.
class AlertsSection extends ConsumerWidget {
  const AlertsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AlertSettings settings = ref.watch(alertSettingsProvider);
    final bool? allowed = ref.watch(notificationsAllowedProvider).value;
    // Kept loaded for the preview button. Listening (not watching) keeps them
    // subscribed without rebuilding this whole block on every pantry change.
    ref
      ..listen(itemsStreamProvider, (previous, next) {})
      ..listen(shoppingEntriesProvider, (previous, next) {});

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            0,
          ),
          child: SectionHeader(title: 'Alerts'),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.notifications_active_outlined),
          title: const Text('Daily alert'),
          subtitle: const Text(
            'A morning reminder about food that is expiring, has expired or '
            'is running low',
          ),
          value: settings.enabled,
          onChanged: (bool value) => _setEnabled(ref, settings, value),
        ),
        if (settings.enabled && allowed == false)
          _PermissionBanner(onAllow: () => _allow(context, ref)),
        ListTile(
          enabled: settings.enabled,
          leading: const Icon(Icons.schedule_rounded),
          title: const Text('Alert time'),
          subtitle: const Text('Asia/Kolkata (India) time'),
          trailing: Text(
            settings.timeLabel,
            style: context.akText.titleMedium,
          ),
          onTap: settings.enabled ? () => _pickTime(context, ref, settings) : null,
        ),
        ListTile(
          enabled: settings.enabled,
          leading: const Icon(Icons.hourglass_bottom_rounded),
          title: const Text('Expiring soon means'),
          subtitle: Text(
            'Within ${settings.warningDays} '
            '${settings.warningDays == 1 ? 'day' : 'days'} of the date. The '
            'Pantry list uses the same number.',
          ),
          trailing: _DaysStepper(
            days: settings.warningDays,
            enabled: settings.enabled,
            onChanged: (int days) =>
                _save(ref, settings.copyWith(warningDays: days)),
          ),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.event_busy_outlined),
          title: const Text('Expired food'),
          subtitle: const Text('Items that are past their date'),
          value: settings.expired,
          onChanged: settings.enabled
              ? (bool value) => _save(ref, settings.copyWith(expired: value))
              : null,
        ),
        SwitchListTile(
          secondary: const Icon(Icons.hourglass_top_rounded),
          title: const Text('Expiring soon'),
          subtitle: const Text('Items that expire today or within the window'),
          value: settings.expiring,
          onChanged: settings.enabled
              ? (bool value) => _save(ref, settings.copyWith(expiring: value))
              : null,
        ),
        SwitchListTile(
          secondary: const Icon(Icons.shopping_basket_outlined),
          title: const Text('Low stock'),
          subtitle: const Text('Items that ran out or are nearly out'),
          value: settings.lowStock,
          onChanged: settings.enabled
              ? (bool value) => _save(ref, settings.copyWith(lowStock: value))
              : null,
        ),
        SwitchListTile(
          secondary: const Icon(Icons.soup_kitchen_outlined),
          title: const Text('Meal prep reminders'),
          subtitle: const Text('Soak, thaw and other prep for planned meals'),
          value: settings.prep,
          onChanged: (bool value) =>
              _save(ref, settings.copyWith(prep: value)),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.group_outlined),
          title: const Text('Household changes'),
          subtitle: const Text('When another member changes the shared lists'),
          value: settings.household,
          onChanged: (bool value) =>
              _save(ref, settings.copyWith(household: value)),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.bedtime_outlined),
          title: const Text('Quiet hours'),
          subtitle: Text(
            settings.quietEnabled
                ? 'No alerts from ${settings.quietStartLabel} to '
                    '${settings.quietEndLabel}; they wait until it ends'
                : 'Hold alerts back overnight',
          ),
          value: settings.quietEnabled,
          onChanged: (bool value) =>
              _save(ref, settings.copyWith(quietEnabled: value)),
        ),
        if (settings.quietEnabled) ...<Widget>[
          ListTile(
            leading: const SizedBox(width: AppSizes.iconLg),
            title: const Text('Quiet from'),
            trailing: Text(
              settings.quietStartLabel,
              style: context.akText.titleMedium,
            ),
            onTap: () => _pickQuiet(context, ref, settings, start: true),
          ),
          ListTile(
            leading: const SizedBox(width: AppSizes.iconLg),
            title: const Text('Quiet until'),
            trailing: Text(
              settings.quietEndLabel,
              style: context.akText.titleMedium,
            ),
            onTap: () => _pickQuiet(context, ref, settings, start: false),
          ),
        ],
        ListTile(
          leading: const Icon(Icons.visibility_outlined),
          title: const Text('Show today’s alert now'),
          subtitle: const Text('A preview, using your pantry as it is'),
          onTap: () => _preview(context, ref, settings),
        ),
      ],
    );
  }

  Future<void> _save(WidgetRef ref, AlertSettings updated) {
    return ref.read(settingsRepositoryProvider).writeAll(updated.toMap());
  }

  Future<void> _setEnabled(
    WidgetRef ref,
    AlertSettings current,
    bool enabled,
  ) async {
    final SettingsRepository repository = ref.read(settingsRepositoryProvider);
    final NotificationGateway gateway = ref.read(notificationGatewayProvider);
    await repository.writeAll(current.copyWith(enabled: enabled).toMap());
    if (!enabled) {
      return;
    }
    try {
      if (!await gateway.areNotificationsAllowed()) {
        await gateway.requestPermission();
        ref.invalidate(notificationsAllowedProvider);
      }
    } on Object {
      // The banner below still offers to ask again.
    }
  }

  Future<void> _pickTime(
    BuildContext context,
    WidgetRef ref,
    AlertSettings settings,
  ) async {
    final SettingsRepository repository = ref.read(settingsRepositoryProvider);
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: settings.hour, minute: settings.minute),
    );
    if (picked == null) {
      return;
    }
    await repository.writeAll(
      settings
          .copyWith(minutesOfDay: picked.hour * 60 + picked.minute)
          .toMap(),
    );
  }

  Future<void> _pickQuiet(
    BuildContext context,
    WidgetRef ref,
    AlertSettings settings, {
    required bool start,
  }) async {
    final int current = start ? settings.quietStart : settings.quietEnd;
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
    );
    if (picked == null) {
      return;
    }
    final int minutes = picked.hour * 60 + picked.minute;
    await _save(
      ref,
      start
          ? settings.copyWith(quietStart: minutes)
          : settings.copyWith(quietEnd: minutes),
    );
  }

  Future<void> _allow(BuildContext context, WidgetRef ref) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final NotificationGateway gateway = ref.read(notificationGatewayProvider);
    bool allowed = false;
    try {
      allowed = await gateway.requestPermission();
    } on Object {
      allowed = false;
    }
    ref.invalidate(notificationsAllowedProvider);
    if (allowed) {
      return;
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text(
            'Notifications are still off. Switch them on in system settings.',
          ),
          action: SnackBarAction(
            label: 'Open settings',
            onPressed: () async {
              try {
                await gateway.openSystemSettings();
              } on Object {
                showMessage(messenger, 'Could not open system settings.');
              }
            },
          ),
        ),
      );
  }

  Future<void> _preview(
    BuildContext context,
    WidgetRef ref,
    AlertSettings settings,
  ) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final NotificationGateway gateway = ref.read(notificationGatewayProvider);
    try {
      if (!await gateway.areNotificationsAllowed()) {
        showMessage(
          messenger,
          'Allow notifications first, then try again.',
        );
        return;
      }
      // Watched in build, so both are already loaded (or still loading).
      final List<ItemWithBatches>? items = ref.read(itemsStreamProvider).value;
      final List<ShoppingEntry>? entries =
          ref.read(shoppingEntriesProvider).value;
      if (items == null || entries == null) {
        showMessage(messenger, 'Still loading your pantry. Try again.');
        return;
      }
      final List<AlertNotification> shown =
          await ref.read(alertSchedulerProvider).showPreview(
                settings: settings,
                items: items,
                entries: entries,
              );
      if (shown.isEmpty) {
        showMessage(messenger, 'Nothing to alert about right now.');
      }
    } on Object catch (error, stack) {
      Diag.error('alerts', 'Alert preview failed', error: error, stack: stack);
      showMessage(messenger, failureMessage(error));
    }
  }
}

class _PermissionBanner extends StatelessWidget {
  const _PermissionBanner({required this.onAllow});

  final VoidCallback onAllow;

  @override
  Widget build(BuildContext context) {
    final AkshayaColors colors = context.akColors;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceAlt,
          borderRadius: AppRadius.cardBorder,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Notifications are off for Akshaya Patra, so the daily alert '
                'cannot appear.',
                style: context.akText.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              FilledButton(
                onPressed: onAllow,
                child: const Text('Allow notifications'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DaysStepper extends StatelessWidget {
  const _DaysStepper({
    required this.days,
    required this.enabled,
    required this.onChanged,
  });

  final int days;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        IconButton(
          tooltip: 'One day fewer',
          icon: const Icon(Icons.remove_circle_outline_rounded),
          onPressed: enabled && days > AlertSettings.minWarningDays
              ? () => onChanged(days - 1)
              : null,
        ),
        Text('$days', style: context.akText.titleMedium),
        IconButton(
          tooltip: 'One day more',
          icon: const Icon(Icons.add_circle_outline_rounded),
          onPressed: enabled && days < AlertSettings.maxWarningDays
              ? () => onChanged(days + 1)
              : null,
        ),
      ],
    );
  }
}
