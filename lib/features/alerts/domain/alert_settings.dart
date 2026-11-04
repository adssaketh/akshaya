import '../../pantry/domain/stock_logic.dart' show kDefaultExpiryWarningDays;

/// Keys under which the alert settings are stored (see `SettingsRepository`).
abstract final class AlertSettingKeys {
  static const String enabled = 'alerts.enabled';
  static const String minutesOfDay = 'alerts.minutes_of_day';
  static const String warningDays = 'alerts.warning_days';
  static const String lowStock = 'alerts.low_stock';

  /// Set once the first-run "allow notifications?" explanation has been
  /// shown, whatever the person answered.
  static const String permissionPrompted = 'alerts.permission_prompted';
}

/// 08:00, as minutes after midnight.
const int kDefaultAlertMinutes = 8 * 60;

/// How the daily alert behaves. Stored per phone.
final class AlertSettings {
  const AlertSettings({
    this.enabled = true,
    this.minutesOfDay = kDefaultAlertMinutes,
    this.warningDays = kDefaultExpiryWarningDays,
    this.lowStock = true,
  });

  /// Reads the settings from stored text, using defaults for anything missing
  /// or unreadable.
  factory AlertSettings.fromMap(Map<String, String> values) {
    return AlertSettings(
      enabled: _readBool(values[AlertSettingKeys.enabled], true),
      minutesOfDay: _limit(
        _readInt(values[AlertSettingKeys.minutesOfDay], kDefaultAlertMinutes),
        0,
        24 * 60 - 1,
      ),
      warningDays: _limit(
        _readInt(
          values[AlertSettingKeys.warningDays],
          kDefaultExpiryWarningDays,
        ),
        minWarningDays,
        maxWarningDays,
      ),
      lowStock: _readBool(values[AlertSettingKeys.lowStock], true),
    );
  }

  static const int minWarningDays = 1;
  static const int maxWarningDays = 14;

  /// Master switch for the daily alert.
  final bool enabled;

  /// Time of day the alert is due, as minutes after midnight (0 to 1439).
  final int minutesOfDay;

  /// Items expiring within this many days count as "expiring soon". The
  /// pantry list uses the same number for its Expiring soon status.
  final int warningDays;

  /// Whether low-stock and out-of-stock items are part of the alert.
  final bool lowStock;

  int get hour => minutesOfDay ~/ 60;

  int get minute => minutesOfDay % 60;

  /// "8:00 am".
  String get timeLabel => formatMinutesOfDay(minutesOfDay);

  AlertSettings copyWith({
    bool? enabled,
    int? minutesOfDay,
    int? warningDays,
    bool? lowStock,
  }) {
    return AlertSettings(
      enabled: enabled ?? this.enabled,
      minutesOfDay: minutesOfDay ?? this.minutesOfDay,
      warningDays: warningDays ?? this.warningDays,
      lowStock: lowStock ?? this.lowStock,
    );
  }

  /// The text form stored by the settings repository.
  Map<String, String> toMap() {
    return <String, String>{
      AlertSettingKeys.enabled: enabled.toString(),
      AlertSettingKeys.minutesOfDay: minutesOfDay.toString(),
      AlertSettingKeys.warningDays: warningDays.toString(),
      AlertSettingKeys.lowStock: lowStock.toString(),
    };
  }

  @override
  bool operator ==(Object other) {
    return other is AlertSettings &&
        other.enabled == enabled &&
        other.minutesOfDay == minutesOfDay &&
        other.warningDays == warningDays &&
        other.lowStock == lowStock;
  }

  @override
  int get hashCode => Object.hash(enabled, minutesOfDay, warningDays, lowStock);

  static bool _readBool(String? text, bool fallback) {
    if (text == 'true') {
      return true;
    }
    if (text == 'false') {
      return false;
    }
    return fallback;
  }

  static int _readInt(String? text, int fallback) {
    if (text == null) {
      return fallback;
    }
    return int.tryParse(text) ?? fallback;
  }

  static int _limit(int value, int lowest, int highest) {
    if (value < lowest) {
      return lowest;
    }
    if (value > highest) {
      return highest;
    }
    return value;
  }
}

/// "8:00 am", "12:30 pm", "12:00 am" for 0 to 1439 minutes after midnight.
String formatMinutesOfDay(int minutesOfDay) {
  final int hour24 = minutesOfDay ~/ 60;
  final int minute = minutesOfDay % 60;
  final String suffix = hour24 < 12 ? 'am' : 'pm';
  final int hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
  return '$hour12:${minute.toString().padLeft(2, '0')} $suffix';
}
