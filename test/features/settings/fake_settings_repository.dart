import 'dart:async';

import 'package:akshaya/features/settings/domain/settings_repository.dart';

/// In-memory settings for widget tests. The stream re-emits on every write,
/// like the database does.
class FakeSettingsRepository implements SettingsRepository {
  FakeSettingsRepository([Map<String, String> initial = const {}])
      : values = Map<String, String>.of(initial);

  final Map<String, String> values;
  final StreamController<void> _changes = StreamController<void>.broadcast();

  @override
  Stream<Map<String, String>> watchAll() async* {
    yield Map<String, String>.of(values);
    yield* _changes.stream.map((_) => Map<String, String>.of(values));
  }

  @override
  Future<Map<String, String>> readAll() async => Map<String, String>.of(values);

  @override
  Future<void> writeAll(Map<String, String> updates) async {
    values.addAll(updates);
    _changes.add(null);
  }

  @override
  Future<void> remove(String key) async {
    values.remove(key);
    _changes.add(null);
  }
}
