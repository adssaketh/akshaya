/// Calendar-date helpers.
///
/// Akshaya stores purchase, expiry and opened dates as calendar dates (no time
/// of day), so every comparison here works on year/month/day only. This keeps
/// "expires today" and "expired yesterday" correct around midnight, across
/// daylight-saving changes and across time zones.
library;

/// Drops the time of day: `2026-11-04 17:30` becomes `2026-11-04 00:00`.
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Whole calendar days from [from] to [to] (negative when [to] is earlier).
int daysBetween(DateTime from, DateTime to) {
  final DateTime a = DateTime.utc(from.year, from.month, from.day);
  final DateTime b = DateTime.utc(to.year, to.month, to.day);
  return b.difference(a).inDays;
}

/// Adds [days] calendar days (negative values subtract).
DateTime addDays(DateTime d, int days) {
  return DateTime(d.year, d.month, d.day + days);
}

/// Adds [months] calendar months, clamping to the last day of the target month
/// (31 Jan + 1 month = 28/29 Feb).
DateTime addMonths(DateTime d, int months) {
  final int total = d.month - 1 + months;
  final int year = d.year + (total / 12).floor();
  final int month = total - (total / 12).floor() * 12 + 1;
  final int lastDay = DateTime(year, month + 1, 0).day;
  return DateTime(year, month, d.day > lastDay ? lastDay : d.day);
}

const List<String> _monthNames = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// "4 Nov 2026".
String formatDate(DateTime d) {
  return '${d.day} ${_monthNames[d.month - 1]} ${d.year}';
}

/// "4 Nov".
String formatDateShort(DateTime d) {
  return '${d.day} ${_monthNames[d.month - 1]}';
}
