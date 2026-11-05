import 'alert_settings.dart';

/// Holds scheduled notifications back during quiet hours. Pure Dart.
///
/// Times are wall-clock times in the alert time zone, carried in UTC-labelled
/// [DateTime]s (see `AlertSchedule`): only the year, month, day, hour and
/// minute fields mean anything.
abstract final class QuietHours {
  /// [at] unchanged when it is outside the quiet hours, otherwise the moment
  /// the quiet hours end (today or, for a time after the start of a window
  /// that runs past midnight, tomorrow).
  static DateTime shift(DateTime at, AlertSettings settings) {
    final int minute = at.hour * 60 + at.minute;
    if (!settings.isQuiet(minute)) {
      return at;
    }
    final int end = settings.quietEnd;
    final bool endsTomorrow =
        settings.quietStart > settings.quietEnd && minute >= settings.quietStart;
    return DateTime.utc(
      at.year,
      at.month,
      at.day + (endsTomorrow ? 1 : 0),
      end ~/ 60,
      end % 60,
    );
  }
}
