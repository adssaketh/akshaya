import '../../../core/util/date_only.dart';

/// Keys under which Count mode keeps its settings and progress (see
/// `SettingsRepository`). They belong to this phone and are never synced.
abstract final class CountSettingKeys {
  static const String reminderEnabled = 'count.reminder_enabled';
  static const String reminderDay = 'count.reminder_day';

  /// Calendar date (yyyy-mm-dd) of the last finished count.
  static const String lastCompletedOn = 'count.last_completed_on';

  /// The count in progress, as JSON (see `CountSession`).
  static const String session = 'count.session';
}

/// The monthly "time to count" reminder and when a count last finished.
final class CountSettings {
  const CountSettings({
    this.reminderEnabled = false,
    this.reminderDay = defaultReminderDay,
    this.lastCompletedOn,
  });

  /// Reads the settings from stored text, using defaults for anything missing
  /// or unreadable.
  factory CountSettings.fromMap(Map<String, String> values) {
    final String? day = values[CountSettingKeys.reminderDay];
    final int parsedDay = day == null ? defaultReminderDay : (int.tryParse(day) ?? defaultReminderDay);
    final String? last = values[CountSettingKeys.lastCompletedOn];
    return CountSettings(
      reminderEnabled: values[CountSettingKeys.reminderEnabled] == 'true',
      reminderDay: parsedDay < minReminderDay
          ? minReminderDay
          : (parsedDay > maxReminderDay ? maxReminderDay : parsedDay),
      lastCompletedOn: last == null ? null : parseIsoDate(last),
    );
  }

  static const int defaultReminderDay = 1;

  /// Days 29 to 31 are left out so the reminder comes every month.
  static const int minReminderDay = 1;
  static const int maxReminderDay = 28;

  final bool reminderEnabled;

  /// Day of the month the reminder is due (1 to 28).
  final int reminderDay;

  /// The day the last count was finished, or null when none has been.
  final DateTime? lastCompletedOn;

  /// True when a count was finished in the same calendar month as [date].
  bool countedInMonthOf(DateTime date) {
    final DateTime? last = lastCompletedOn;
    return last != null && last.year == date.year && last.month == date.month;
  }

  /// True when the reminder should be shown on [date]: it is switched on, it
  /// is the chosen day, and no count was finished yet this month.
  bool reminderDueOn(DateTime date) {
    return reminderEnabled && date.day == reminderDay && !countedInMonthOf(date);
  }

  /// "Last counted 4 Nov 2026", or "Never counted".
  String get lastCountedLabel {
    final DateTime? last = lastCompletedOn;
    return last == null ? 'Never counted' : 'Last counted ${formatDate(last)}';
  }

  Map<String, String> toMap() {
    final DateTime? last = lastCompletedOn;
    return <String, String>{
      CountSettingKeys.reminderEnabled: reminderEnabled.toString(),
      CountSettingKeys.reminderDay: reminderDay.toString(),
      if (last != null) CountSettingKeys.lastCompletedOn: formatIsoDate(last),
    };
  }

  CountSettings copyWith({bool? reminderEnabled, int? reminderDay}) {
    return CountSettings(
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderDay: reminderDay ?? this.reminderDay,
      lastCompletedOn: lastCompletedOn,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is CountSettings &&
        other.reminderEnabled == reminderEnabled &&
        other.reminderDay == reminderDay &&
        other.lastCompletedOn == lastCompletedOn;
  }

  @override
  int get hashCode => Object.hash(reminderEnabled, reminderDay, lastCompletedOn);
}
