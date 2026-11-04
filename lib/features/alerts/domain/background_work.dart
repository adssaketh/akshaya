/// Keeps a periodic background check running, so alerts stay up to date even
/// when the app is not opened. The real implementation uses WorkManager.
abstract interface class BackgroundWork {
  /// Makes sure the periodic check is registered. Does nothing to a check
  /// that is already running.
  Future<void> ensureAlertRefreshRegistered();

  /// Stops the periodic check.
  Future<void> cancelAlertRefresh();
}
