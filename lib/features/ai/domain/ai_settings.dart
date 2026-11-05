import '../../commands/domain/voice_language.dart';

/// Keys under which the AI and voice settings are stored.
abstract final class AiSettingKeys {
  static const String enabled = 'ai.enabled';
  static const String dailyCap = 'ai.daily_cap';

  /// "true" once the person has seen and accepted the notice that AI features
  /// send grocery text and audio to Google.
  static const String noticeAccepted = 'ai.notice_accepted';
  static const String usageDate = 'ai.usage_date';
  static const String usageCount = 'ai.usage_count';
  static const String voiceLanguage = 'voice.language';

  /// "true" once the microphone explanation has been shown.
  static const String micExplained = 'voice.mic_explained';
}

const int kDefaultAiDailyCap = 50;
const int kMinAiDailyCap = 5;
const int kMaxAiDailyCap = 200;

/// AI and voice preferences. Stored per phone.
final class AiSettings {
  const AiSettings({
    this.enabled = true,
    this.dailyCap = kDefaultAiDailyCap,
    this.noticeAccepted = false,
    this.voiceLanguage = VoiceLanguage.auto,
  });

  factory AiSettings.fromMap(Map<String, String> values) {
    final int cap = int.tryParse(values[AiSettingKeys.dailyCap] ?? '') ??
        kDefaultAiDailyCap;
    return AiSettings(
      enabled: (values[AiSettingKeys.enabled] ?? 'true') != 'false',
      dailyCap: cap < kMinAiDailyCap
          ? kMinAiDailyCap
          : (cap > kMaxAiDailyCap ? kMaxAiDailyCap : cap),
      noticeAccepted: values[AiSettingKeys.noticeAccepted] == 'true',
      voiceLanguage: VoiceLanguage.fromKey(values[AiSettingKeys.voiceLanguage]),
    );
  }

  final bool enabled;

  /// Soft limit on AI calls per day; offline mode takes over after it.
  final int dailyCap;
  final bool noticeAccepted;
  final VoiceLanguage voiceLanguage;

  @override
  bool operator ==(Object other) {
    return other is AiSettings &&
        other.enabled == enabled &&
        other.dailyCap == dailyCap &&
        other.noticeAccepted == noticeAccepted &&
        other.voiceLanguage == voiceLanguage;
  }

  @override
  int get hashCode =>
      Object.hash(enabled, dailyCap, noticeAccepted, voiceLanguage);

  AiSettings copyWith({
    bool? enabled,
    int? dailyCap,
    bool? noticeAccepted,
    VoiceLanguage? voiceLanguage,
  }) {
    return AiSettings(
      enabled: enabled ?? this.enabled,
      dailyCap: dailyCap ?? this.dailyCap,
      noticeAccepted: noticeAccepted ?? this.noticeAccepted,
      voiceLanguage: voiceLanguage ?? this.voiceLanguage,
    );
  }
}

/// How many AI calls were made on one calendar day.
final class AiUsage {
  const AiUsage({this.date, this.count = 0});

  factory AiUsage.fromMap(Map<String, String> values) {
    return AiUsage(
      date: values[AiSettingKeys.usageDate],
      count: int.tryParse(values[AiSettingKeys.usageCount] ?? '') ?? 0,
    );
  }

  /// "2026-11-04", or null before the first call.
  final String? date;
  final int count;

  @override
  bool operator ==(Object other) {
    return other is AiUsage && other.date == date && other.count == count;
  }

  @override
  int get hashCode => Object.hash(date, count);

  /// Calls made on [today] (a new day starts again at zero).
  int countOn(DateTime today) => date == dayKey(today) ? count : 0;

  /// The usage after one more call on [today].
  AiUsage incremented(DateTime today) {
    return AiUsage(date: dayKey(today), count: countOn(today) + 1);
  }

  static String dayKey(DateTime day) {
    final String m = day.month.toString().padLeft(2, '0');
    final String d = day.day.toString().padLeft(2, '0');
    return '${day.year}-$m-$d';
  }
}
