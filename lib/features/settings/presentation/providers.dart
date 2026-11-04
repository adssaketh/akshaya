import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/clock.dart';
import '../../pantry/presentation/providers.dart';
import '../data/drift_settings_repository.dart';
import '../domain/settings_repository.dart';

final Provider<SettingsRepository> settingsRepositoryProvider =
    Provider<SettingsRepository>((Ref ref) {
  return DriftSettingsRepository(
    ref.watch(appDatabaseProvider),
    clock: ref.watch(clockProvider),
  );
});

/// Every stored setting as text. Emits again on every change.
final StreamProvider<Map<String, String>> settingsMapProvider =
    StreamProvider<Map<String, String>>((Ref ref) {
  return ref.watch(settingsRepositoryProvider).watchAll();
});
