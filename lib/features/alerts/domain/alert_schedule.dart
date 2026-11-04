/// When the daily alert is due. Pure date arithmetic.
///
/// Times here are wall-clock times in the alert time zone (Asia/Kolkata).
/// They travel in [DateTime] objects marked UTC purely as carriers, so adding
/// days never meets a daylight-saving jump; only the year, month, day, hour
/// and minute fields mean anything.
abstract final class AlertSchedule {
  /// How many days ahead alerts are scheduled. If the background check is
  /// delayed (battery savers do this), the next days' alerts are already
  /// waiting. Every refresh replaces them with fresh content.
  static const int horizonDays = 3;

  /// A fire time closer than this is moved to the next day: the system
  /// refuses to schedule a moment that has already passed by the time the
  /// request arrives.
  static const Duration minLead = Duration(seconds: 30);

  /// The next time [minutesOfDay] (minutes after midnight) comes round, at
  /// least [minLead] after [now].
  static DateTime nextFire(DateTime now, int minutesOfDay) {
    final DateTime nowWall = DateTime.utc(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute,
      now.second,
    );
    final DateTime todayAt = DateTime.utc(
      now.year,
      now.month,
      now.day,
      minutesOfDay ~/ 60,
      minutesOfDay % 60,
    );
    if (todayAt.isAfter(nowWall.add(minLead))) {
      return todayAt;
    }
    return DateTime.utc(
      todayAt.year,
      todayAt.month,
      todayAt.day + 1,
      todayAt.hour,
      todayAt.minute,
    );
  }

  /// The fire times of the scheduled days: [first], then one day later each,
  /// [horizonDays] in all.
  static List<DateTime> fireTimes(DateTime first) {
    return <DateTime>[
      for (int d = 0; d < horizonDays; d++)
        DateTime.utc(
          first.year,
          first.month,
          first.day + d,
          first.hour,
          first.minute,
        ),
    ];
  }

  /// The calendar date of [wall], with no time of day, the way pantry dates
  /// are kept.
  static DateTime dateOf(DateTime wall) {
    return DateTime(wall.year, wall.month, wall.day);
  }
}
