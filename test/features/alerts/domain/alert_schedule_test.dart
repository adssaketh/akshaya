import 'package:akshaya/features/alerts/domain/alert_schedule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const int eight = 8 * 60;

  group('AlertSchedule.nextFire', () {
    test('later today when the time has not come yet', () {
      expect(
        AlertSchedule.nextFire(DateTime(2026, 11, 4, 7), eight),
        DateTime.utc(2026, 11, 4, 8),
      );
    });

    test('tomorrow once the time has passed', () {
      expect(
        AlertSchedule.nextFire(DateTime(2026, 11, 4, 9), eight),
        DateTime.utc(2026, 11, 5, 8),
      );
    });

    test('tomorrow when it is exactly the time', () {
      expect(
        AlertSchedule.nextFire(DateTime(2026, 11, 4, 8), eight),
        DateTime.utc(2026, 11, 5, 8),
      );
    });

    test('a moment only seconds away counts as passed', () {
      // 15 s before 8:00 is inside the 30 s lead.
      expect(
        AlertSchedule.nextFire(DateTime(2026, 11, 4, 7, 59, 45), eight),
        DateTime.utc(2026, 11, 5, 8),
      );
      // A minute before is far enough.
      expect(
        AlertSchedule.nextFire(DateTime(2026, 11, 4, 7, 59), eight),
        DateTime.utc(2026, 11, 4, 8),
      );
    });

    test('rolls over month and year ends', () {
      expect(
        AlertSchedule.nextFire(DateTime(2026, 11, 30, 9), eight),
        DateTime.utc(2026, 12, 1, 8),
      );
      expect(
        AlertSchedule.nextFire(DateTime(2026, 12, 31, 9), eight),
        DateTime.utc(2027, 1, 1, 8),
      );
    });

    test('handles a midnight alert time', () {
      expect(
        AlertSchedule.nextFire(DateTime(2026, 11, 4, 10), 0),
        DateTime.utc(2026, 11, 5),
      );
    });

    test('reads a UTC-flagged now by its wall-clock fields', () {
      expect(
        AlertSchedule.nextFire(DateTime.utc(2026, 11, 4, 7), eight),
        DateTime.utc(2026, 11, 4, 8),
      );
    });
  });

  group('AlertSchedule.fireTimes', () {
    test('is the first time then one day later each, three in all', () {
      expect(AlertSchedule.horizonDays, 3);
      expect(
        AlertSchedule.fireTimes(DateTime.utc(2026, 11, 29, 8, 30)),
        <DateTime>[
          DateTime.utc(2026, 11, 29, 8, 30),
          DateTime.utc(2026, 11, 30, 8, 30),
          DateTime.utc(2026, 12, 1, 8, 30),
        ],
      );
    });
  });

  test('dateOf drops the time of day', () {
    expect(
      AlertSchedule.dateOf(DateTime.utc(2026, 11, 5, 8, 30)),
      DateTime(2026, 11, 5),
    );
  });
}
