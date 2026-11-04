import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/firebase_runtime.dart';
import '../domain/ai_settings.dart';
import '../../settings/presentation/providers.dart';
import 'providers.dart';

/// The one-time notice that AI features send grocery text and audio to Google.
///
/// Returns true when AI may be used. "Use offline only" turns AI off (it can
/// be turned on again in Settings, which shows this notice again).
Future<bool> ensureAiNotice(BuildContext context, WidgetRef ref) async {
  final AiSettings settings = ref.read(aiSettingsProvider);
  if (!settings.enabled || !FirebaseBuildConfig.isConfigured) {
    return false;
  }
  if (settings.noticeAccepted) {
    return true;
  }
  final bool? allowed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) => const _AiNoticeDialog(),
  );
  final bool yes = allowed ?? false;
  await ref.read(settingsRepositoryProvider).writeAll(<String, String>{
    if (yes) AiSettingKeys.noticeAccepted: 'true',
    if (!yes) AiSettingKeys.enabled: 'false',
  });
  return yes;
}

class _AiNoticeDialog extends StatelessWidget {
  const _AiNoticeDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Use AI for hard-to-read commands?'),
      content: const SingleChildScrollView(
        child: Text(
          'Akshaya understands most commands on your phone. When it cannot, '
          'it can ask Google Gemini.\n\n'
          'If you allow this, only the grocery words you typed or said '
          '(and a short recording, if your phone cannot recognise speech), '
          'item names, quantities, units and dates are sent to Google. '
          'Your name, email, household and location are never sent.\n\n'
          'The free Gemini tier may use what is sent to improve Google '
          'products. You can turn AI off at any time in Settings.',
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Use offline only'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Allow AI'),
        ),
      ],
    );
  }
}
