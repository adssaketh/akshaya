import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/clock.dart';
import '../../settings/domain/settings_repository.dart';
import '../../settings/presentation/providers.dart';
import '../data/firebase_generative_backend.dart';
import '../data/firebase_runtime.dart';
import '../domain/ai_command_service.dart';
import '../domain/ai_gate.dart';
import '../domain/ai_settings.dart';

/// Keeps the daily AI call count in the settings table.
final class SettingsAiUsageStore implements AiUsageStore {
  const SettingsAiUsageStore(this._settings);

  final SettingsRepository _settings;

  @override
  Future<AiUsage> read() async => AiUsage.fromMap(await _settings.readAll());

  @override
  Future<void> write(AiUsage usage) {
    return _settings.writeAll(<String, String>{
      AiSettingKeys.usageDate: usage.date ?? '',
      AiSettingKeys.usageCount: usage.count.toString(),
    });
  }
}

/// The saved AI and voice settings (defaults until they have loaded).
final Provider<AiSettings> aiSettingsProvider = Provider<AiSettings>((Ref ref) {
  final Map<String, String> stored =
      ref.watch(settingsMapProvider).value ?? const <String, String>{};
  return AiSettings.fromMap(stored);
});

/// Today's AI call count.
final Provider<AiUsage> aiUsageProvider = Provider<AiUsage>((Ref ref) {
  final Map<String, String> stored =
      ref.watch(settingsMapProvider).value ?? const <String, String>{};
  return AiUsage.fromMap(stored);
});

/// Starts Firebase lazily. Tests override it.
final Provider<FirebaseRuntime> firebaseRuntimeProvider =
    Provider<FirebaseRuntime>((Ref ref) {
  return FirebaseRuntime(
    modelOverride: () => ref.read(settingsMapProvider).value?[kAiModelKey],
  );
});

final Provider<GenerativeBackend> generativeBackendProvider =
    Provider<GenerativeBackend>((Ref ref) {
  return FirebaseGenerativeBackend(ref.watch(firebaseRuntimeProvider));
});

/// The prompt template bundled with the app.
final FutureProvider<String> parsePromptProvider = FutureProvider<String>(
  (Ref ref) => rootBundle.loadString('assets/prompts/parse_command.txt'),
);

/// The AI command reader, or null while its prompt loads.
final Provider<AiCommandService?> aiCommandServiceProvider =
    Provider<AiCommandService?>((Ref ref) {
  final String? prompt = ref.watch(parsePromptProvider).value;
  if (prompt == null) {
    return null;
  }
  return AiCommandService(
    backend: ref.watch(generativeBackendProvider),
    usageStore: SettingsAiUsageStore(ref.watch(settingsRepositoryProvider)),
    readSettings: () => ref.read(aiSettingsProvider),
    promptTemplate: prompt,
    firebaseConfigured: FirebaseBuildConfig.isConfigured,
    now: ref.watch(clockProvider),
  );
});

/// Why AI can or cannot be used right now, for Settings.
final Provider<AiAvailability> aiAvailabilityProvider =
    Provider<AiAvailability>((Ref ref) {
  final DateTime today = ref.watch(todayProvider);
  return AiGate.check(
    settings: ref.watch(aiSettingsProvider),
    usage: ref.watch(aiUsageProvider),
    today: today,
    firebaseConfigured: FirebaseBuildConfig.isConfigured,
    now: ref.read(clockProvider)(),
  );
});
