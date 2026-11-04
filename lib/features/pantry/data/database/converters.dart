import 'package:drift/drift.dart';

/// Stores an instant (createdAt, updatedAt, log time) as UTC milliseconds
/// since the epoch. Milliseconds keep last-write-wins conflict resolution
/// accurate enough for two people editing at once.
class EpochMillisConverter extends TypeConverter<DateTime, int> {
  const EpochMillisConverter();

  @override
  DateTime fromSql(int fromDb) {
    return DateTime.fromMillisecondsSinceEpoch(fromDb);
  }

  @override
  int toSql(DateTime value) => value.millisecondsSinceEpoch;
}

/// Stores a calendar date (purchase, expiry, opened) as `yyyy-MM-dd` text.
///
/// A date with no time of day is not an instant, so it must not shift when
/// the phone changes time zone. Text dates also sort correctly.
class DateOnlyConverter extends TypeConverter<DateTime, String> {
  const DateOnlyConverter();

  @override
  DateTime fromSql(String fromDb) {
    final List<String> parts = fromDb.split('-');
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  @override
  String toSql(DateTime value) {
    final String year = value.year.toString().padLeft(4, '0');
    final String month = value.month.toString().padLeft(2, '0');
    final String day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
