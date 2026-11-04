/// A small key/value store for the person's settings (alert time, warning
/// days and so on; Phase 8 adds the rest).
///
/// Settings belong to this phone, so they are never synced to a household.
/// Values are plain text; each feature owns the keys it uses and turns them
/// into typed settings (see `AlertSettings`).
abstract interface class SettingsRepository {
  /// Every stored setting. Emits again on every change.
  Stream<Map<String, String>> watchAll();

  /// Every stored setting right now.
  Future<Map<String, String>> readAll();

  /// Saves [values] together: all of them or none.
  Future<void> writeAll(Map<String, String> values);

  /// Forgets one setting, so its default applies again.
  Future<void> remove(String key);
}
