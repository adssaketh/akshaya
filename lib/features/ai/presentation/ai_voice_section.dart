import 'dart:async';

import 'package:akshaya/core/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/clock.dart';
import '../../commands/domain/voice_language.dart';
import '../../settings/presentation/providers.dart';
import '../data/firebase_runtime.dart';
import '../domain/ai_gate.dart';
import '../domain/ai_settings.dart';
import 'ai_notice_dialog.dart';
import 'providers.dart';

/// The "AI and voice" block of Settings: AI switch, daily cap, today's usage,
/// voice language and the privacy note.
class AiVoiceSection extends ConsumerWidget {
  const AiVoiceSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AiSettings settings = ref.watch(aiSettingsProvider);
    final AiUsage usage = ref.watch(aiUsageProvider);
    final AiAvailability availability = ref.watch(aiAvailabilityProvider);
    final DateTime today = ref.watch(todayProvider);
    final int used = usage.countOn(today);
    final AkshayaColors colors = context.akColors;

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
          child: SectionHeader(title: 'AI and voice'),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.auto_awesome_outlined),
          title: const Text('Use AI for hard-to-read commands'),
          subtitle: Text(
            FirebaseBuildConfig.isConfigured
                ? 'Voice and typed commands are understood on your phone '
                    'first. Google Gemini is asked only when needed.'
                : 'Not set up in this build. Commands are understood on '
                    'your phone.',
          ),
          value: settings.enabled,
          onChanged: (bool value) => _setEnabled(context, ref, value),
        ),
        ListTile(
          enabled: settings.enabled,
          leading: const Icon(Icons.speed_rounded),
          title: const Text('Daily AI limit'),
          subtitle: Text('Offline mode takes over after ${settings.dailyCap} '
              'calls a day.'),
          trailing: _CapStepper(
            value: settings.dailyCap,
            enabled: settings.enabled,
            onChanged: (int value) => ref
                .read(settingsRepositoryProvider)
                .writeAll(<String, String>{
              AiSettingKeys.dailyCap: value.toString(),
            }),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.insights_outlined),
          title: Text('AI calls today: $used of ${settings.dailyCap}'),
          subtitle: Text(
            availability.message ?? 'AI is ready.',
            style: context.akText.bodySmall!.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.translate_rounded),
          title: const Text('Voice language'),
          subtitle: const Text('Words shown in the app are always English.'),
          trailing: DropdownButton<VoiceLanguage>(
            value: settings.voiceLanguage,
            underline: const SizedBox.shrink(),
            onChanged: (VoiceLanguage? value) {
              if (value == null) {
                return;
              }
              unawaited(
                ref.read(settingsRepositoryProvider).writeAll(<String, String>{
                  AiSettingKeys.voiceLanguage: value.key,
                }),
              );
            },
            items: <DropdownMenuItem<VoiceLanguage>>[
              for (final VoiceLanguage language in VoiceLanguage.values)
                DropdownMenuItem<VoiceLanguage>(
                  value: language,
                  child: Text(language.label),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          child: Text(
            'When AI is used, only the grocery words you typed or said (or a '
            'short recording), item names, quantities, units and dates go to '
            'Google. Never your name, email, household or location.',
            style: context.akText.bodySmall!.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _setEnabled(
    BuildContext context,
    WidgetRef ref,
    bool value,
  ) async {
    await ref.read(settingsRepositoryProvider).writeAll(<String, String>{
      AiSettingKeys.enabled: value.toString(),
    });
    if (value && context.mounted) {
      await ensureAiNotice(context, ref);
    }
  }
}

class _CapStepper extends StatelessWidget {
  const _CapStepper({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final int value;
  final bool enabled;
  final ValueChanged<int> onChanged;

  static const int _step = 10;

  static int _limit(int v) =>
      v < kMinAiDailyCap ? kMinAiDailyCap : (v > kMaxAiDailyCap ? kMaxAiDailyCap : v);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        IconButton(
          tooltip: 'Lower the daily limit',
          constraints: const BoxConstraints(
            minWidth: AppSizes.touchTarget,
            minHeight: AppSizes.touchTarget,
          ),
          icon: const Icon(Icons.remove_rounded),
          onPressed: enabled && value > kMinAiDailyCap
              ? () => onChanged(_limit(value - _step))
              : null,
        ),
        Text('$value', style: context.akText.titleMedium),
        IconButton(
          tooltip: 'Raise the daily limit',
          constraints: const BoxConstraints(
            minWidth: AppSizes.touchTarget,
            minHeight: AppSizes.touchTarget,
          ),
          icon: const Icon(Icons.add_rounded),
          onPressed: enabled && value < kMaxAiDailyCap
              ? () => onChanged(_limit(value + _step))
              : null,
        ),
      ],
    );
  }
}
