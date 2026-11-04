import 'ai_settings.dart';

/// Whether an AI call may be made right now, and if not, why.
enum AiAvailability {
  ready,

  /// Switched off in Settings.
  disabled,

  /// This build has no Firebase configuration.
  notConfigured,

  /// The person has not yet accepted the privacy notice.
  noticeNeeded,

  /// Today's soft cap is used up.
  capReached,

  /// The free quota answered "too many requests" a moment ago.
  coolingDown;

  bool get isReady => this == AiAvailability.ready;

  /// One line for the person, or null when ready.
  String? get message {
    switch (this) {
      case AiAvailability.ready:
        return null;
      case AiAvailability.disabled:
        return 'AI is turned off, using offline mode.';
      case AiAvailability.notConfigured:
        return 'AI is not set up in this build, using offline mode.';
      case AiAvailability.noticeNeeded:
        return 'AI needs your OK first, using offline mode.';
      case AiAvailability.capReached:
        return 'AI limit reached for today, using offline mode.';
      case AiAvailability.coolingDown:
        return 'AI is busy right now, using offline mode.';
    }
  }
}

/// The rules for when AI may be used. Pure, so they are easy to test.
abstract final class AiGate {
  static AiAvailability check({
    required AiSettings settings,
    required AiUsage usage,
    required DateTime today,
    required bool firebaseConfigured,
    required DateTime now,
    DateTime? cooldownUntil,
  }) {
    if (!settings.enabled) {
      return AiAvailability.disabled;
    }
    if (!firebaseConfigured) {
      return AiAvailability.notConfigured;
    }
    if (!settings.noticeAccepted) {
      return AiAvailability.noticeNeeded;
    }
    if (usage.countOn(today) >= settings.dailyCap) {
      return AiAvailability.capReached;
    }
    if (cooldownUntil != null && now.isBefore(cooldownUntil)) {
      return AiAvailability.coolingDown;
    }
    return AiAvailability.ready;
  }
}
