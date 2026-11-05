import '../../pantry/domain/stock_logic.dart' show kDefaultExpiryWarningDays;

/// Keys under which the alert settings are stored (see `SettingsRepository`).
abstract final class AlertSettingKeys {
  static const String enabled = 'alerts.enabled';
  static const String minutesOfDay = 'alerts.minutes_of_day';
  static const String warningDays = 'alerts.warning_days';
  static const String lowStock = 'alerts.low_stock';
  static const String expired = 'alerts.expired';
  static const String expiring = 'alerts.expiring';
  static const String prep = 'alerts.prep';
  static const String household = 'alerts.household';
  static const String quietEnabled = 'alerts.quiet_enabled';
  static const String quietStart = 'alerts.quiet_start';
  static const String quietEnd = 'alerts.quiet_end';

  /// Set once the first-run "allow notifications?" explanation has been
  /// shown, whatever the person answered.
  static const String permissionPrompted = 'alerts.permission_prompted';
}

/// 08:00, as minutes after midnight.
const int kDefaultAlertMinutes = 8 * 60;

/// Quiet hours start at 22:00 by default.
const int kDefaultQuietStartMinutes = 22 * 60;

/// Quiet hours end at 07:00 by default.
const int kDefaultQuietEndMinutes = 7 * 60;

/// How the daily alert behaves. Stored per phone.
final class AlertSettings {
  const AlertSettings({
    this.enabled = true,
    this.minutesOfDay = kDefaultAlertMinutes,
    this.warningDays = kDefaultExpiryWarningDays,
    this.lowStock = true,
    this.expired = true,
    this.expiring = true,
    this.prep = true,
    this.household = true,
    this.quietEnabled = false,
    this.quietStart = kDefaultQuietStartMinutes,
    this.quietEnd = kDefaultQuietEndMinutes,
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
      expired: _readBool(values[AlertSettingKeys.expired], true),
      expiring: _readBool(values[AlertSettingKeys.expiring], true),
      prep: _readBool(values[AlertSettingKeys.prep], true),
      household: _readBool(values[AlertSettingKeys.household], true),
      quietEnabled: _readBool(values[AlertSettingKeys.quietEnabled], false),
      quietStart: _limit(
        _readInt(values[AlertSettingKeys.quietStart], kDefaultQuietStartMinutes),
        0,
        24 * 60 - 1,
      ),
      quietEnd: _limit(
        _readInt(values[AlertSettingKeys.quietEnd], kDefaultQuietEndMinutes),
        0,
        24 * 60 - 1,
      ),
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

  /// Whether the alert lists food that has already expired.
  final bool expired;

  /// Whether the alert lists food expiring today or soon.
  final bool expiring;

  /// Whether meal prep reminders ("Soak rajma") are shown.
  final bool prep;

  /// Whether a change another member made to the household's lists is shown.
  final bool household;

  /// Whether notifications are held back during quiet hours.
  final bool quietEnabled;

  /// Quiet hours start (minutes after midnight). When the end is earlier, the
  /// quiet hours run past midnight.
  final int quietStart;

  /// Quiet hours end (minutes after midnight).
  final int quietEnd;

  /// "10:00 pm".
  String get quietStartLabel => formatMinutesOfDay(quietStart);

  /// "7:00 am".
  String get quietEndLabel => formatMinutesOfDay(quietEnd);

  /// Whether [minutesOfDay] falls inside the quiet hours (false when they are
  /// off or empty because start and end are the same).
  bool isQuiet(int minutesOfDay) {
    if (!quietEnabled || quietStart == quietEnd) {
      return false;
    }
    if (quietStart < quietEnd) {
      return minutesOfDay >= quietStart && minutesOfDay < quietEnd;
    }
    return minutesOfDay >= quietStart || minutesOfDay < quietEnd;
  }

  int get hour => minutesOfDay ~/ 60;

  int get minute => minutesOfDay % 60;

  /// "8:00 am".
  String get timeLabel => formatMinutesOfDay(minutesOfDay);

  AlertSettings copyWith({
    bool? enabled,
    int? minutesOfDay,
    int? warningDays,
    bool? lowStock,
    bool? expired,
    bool? expiring,
    bool? prep,
    bool? household,
    bool? quietEnabled,
    int? quietStart,
    int? quietEnd,
  }) {
    return AlertSettings(
      enabled: enabled ?? this.enabled,
      minutesOfDay: minutesOfDay ?? this.minutesOfDay,
      warningDays: warningDays ?? this.warningDays,
      lowStock: lowStock ?? this.lowStock,
      expired: expired ?? this.expired,
      expiring: expiring ?? this.expiring,
      prep: prep ?? this.prep,
      household: household ?? this.household,
      quietEnabled: quietEnabled ?? this.quietEnabled,
      quietStart: quietStart ?? this.quietStart,
      quietEnd: quietEnd ?? this.quietEnd,
    );
  }

  /// The text form stored by the settings repository.
  Map<String, String> toMap() {
    return <String, String>{
      AlertSettingKeys.enabled: enabled.toString(),
      AlertSettingKeys.minutesOfDay: minutesOfDay.toString(),
      AlertSettingKeys.warningDays: warningDays.toString(),
      AlertSettingKeys.lowStock: lowStock.toString(),
      AlertSettingKeys.expired: expired.toString(),
      AlertSettingKeys.expiring: expiring.toString(),
      AlertSettingKeys.prep: prep.toString(),
      AlertSettingKeys.household: household.toString(),
      AlertSettingKeys.quietEnabled: quietEnabled.toString(),
      AlertSettingKeys.quietStart: quietStart.toString(),
      AlertSettingKeys.quietEnd: quietEnd.toString(),
    };
  }

  @override
  bool operator ==(Object other) {
    return other is AlertSettings &&
        other.enabled == enabled &&
        other.minutesOfDay == minutesOfDay &&
        other.warningDays == warningDays &&
        other.lowStock == lowStock &&
        other.expired == expired &&
        other.expiring == expiring &&
        other.prep == prep &&
        other.household == household &&
        other.quietEnabled == quietEnabled &&
        other.quietStart == quietStart &&
        other.quietEnd == quietEnd;
  }

  @override
  int get hashCode => Object.hash(
        enabled,
        minutesOfDay,
        warningDays,
        lowStock,
        expired,
        expiring,
        prep,
        household,
        quietEnabled,
        quietStart,
        quietEnd,
      );

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
