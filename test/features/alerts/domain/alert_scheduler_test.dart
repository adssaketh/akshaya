import 'package:akshaya/features/alerts/domain/alert_plan.dart';
import 'package:akshaya/features/alerts/domain/alert_scheduler.dart';
import 'package:akshaya/features/alerts/domain/alert_settings.dart';
import 'package:akshaya/features/alerts/domain/notification_gateway.dart';
import 'package:akshaya/features/pantry/domain/entities.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../pantry/domain/test_data.dart';
import '../fake_notification_gateway.dart';

ItemWithBatches stocked(String id, String name, DateTime expiry) {
  return ItemWithBatches(
    item: makeItem(id: id, name: name),
    batches: <StockBatch>[
      makeBatch(id: 'b-$id', itemId: id, bought: 2, expiry: expiry),
    ],
  );
}

void main() {
  // 2026-11-04 18:30 in India; the alert time is 8:00, so the first alert is
  // 5 Nov, then 6 and 7 Nov.
  late FakeNotificationGateway gateway;
  late AlertScheduler scheduler;

  setUp(() {
    gateway = FakeNotificationGateway(now: DateTime(2026, 11, 4, 18, 30));
    scheduler = AlertScheduler(gateway);
  });

  final List<ItemWithBatches> items = <ItemWithBatches>[
    stocked('c', 'Curd', DateTime(2026, 11, 5)),
    stocked('s', 'Spinach', DateTime(2026, 11, 7)),
  ];

  test('schedules three days, each with that day\'s own content', () async {
    final List<ScheduledAlert> result = await scheduler.refresh(
      settings: const AlertSettings(),
      items: items,
      entries: const [],
    );

    expect(gateway.replaceCalls, 1);
    expect(gateway.scheduled, hasLength(3));
    expect(result.map((a) => a.fireAt), <DateTime>[
      DateTime.utc(2026, 11, 5, 8),
      DateTime.utc(2026, 11, 6, 8),
      DateTime.utc(2026, 11, 7, 8),
    ]);

    // 5 Nov: Curd expires that day, Spinach is two days away.
    final List<AlertNotification> day0 = gateway.scheduled[0].notifications;
    expect(day0, hasLength(1));
    expect(day0.single.title, '1 expiring today, 1 more soon');
    expect(day0.single.id, AlertPlanner.idFor(0, 2));

    // 6 Nov: Curd has expired, Spinach is tomorrow.
    final List<AlertNotification> day1 = gateway.scheduled[1].notifications;
    expect(day1.map((n) => n.title), <String>[
      '1 item has expired',
      '1 item expiring soon',
    ]);
    expect(day1.map((n) => n.id), <int>[
      AlertPlanner.idFor(1, 1),
      AlertPlanner.idFor(1, 2),
    ]);

    // 7 Nov: Curd expired two days ago, Spinach expires that day.
    final List<AlertNotification> day2 = gateway.scheduled[2].notifications;
    expect(day2.map((n) => n.title), <String>[
      '1 item has expired',
      '1 item expires today',
    ]);
    expect(day2.first.body, 'Curd (2d ago)');
  });

  test('starts tomorrow when the time has passed today', () async {
    gateway.now = DateTime(2026, 11, 5, 9);
    final List<ScheduledAlert> result = await scheduler.refresh(
      settings: const AlertSettings(),
      items: items,
      entries: const [],
    );
    expect(result.first.fireAt, DateTime.utc(2026, 11, 6, 8));
  });

  test('uses the chosen time', () async {
    final List<ScheduledAlert> result = await scheduler.refresh(
      settings: const AlertSettings(minutesOfDay: 19 * 60 + 15),
      items: items,
      entries: const [],
    );
    expect(result.first.fireAt, DateTime.utc(2026, 11, 4, 19, 15));
  });

  test('schedules nothing, but clears the old alerts, when there is nothing '
      'to say', () async {
    await scheduler.refresh(
      settings: const AlertSettings(),
      items: items,
      entries: const [],
    );
    expect(gateway.scheduled, isNotEmpty);

    await scheduler.refresh(
      settings: const AlertSettings(),
      items: const <ItemWithBatches>[],
      entries: const [],
    );
    expect(gateway.replaceCalls, 2);
    expect(gateway.scheduled, isEmpty);
  });

  test('with alerts off, only cancels', () async {
    await scheduler.refresh(
      settings: const AlertSettings(),
      items: items,
      entries: const [],
    );
    final List<ScheduledAlert> result = await scheduler.refresh(
      settings: const AlertSettings(enabled: false),
      items: items,
      entries: const [],
    );
    expect(result, isEmpty);
    expect(gateway.cancelCalls, 1);
    expect(gateway.replaceCalls, 1);
    expect(gateway.scheduled, isEmpty);
  });

  group('showPreview', () {
    test('shows today\'s alert right now with preview ids', () async {
      final List<AlertNotification> shown = await scheduler.showPreview(
        settings: const AlertSettings(),
        items: items,
        entries: const [],
      );
      // On 4 Nov, Curd is one day away and Spinach three.
      expect(shown.single.title, '2 items expiring soon');
      expect(shown.single.id, AlertPlanner.idFor(9, 2));
      expect(gateway.shown, hasLength(1));
      expect(gateway.shown.single, shown);
      // A preview never touches the schedule.
      expect(gateway.replaceCalls, 0);
    });

    test('shows nothing when there is nothing to say', () async {
      final List<AlertNotification> shown = await scheduler.showPreview(
        settings: const AlertSettings(),
        items: const <ItemWithBatches>[],
        entries: const [],
      );
      expect(shown, isEmpty);
      expect(gateway.shown, isEmpty);
    });
  });
}
