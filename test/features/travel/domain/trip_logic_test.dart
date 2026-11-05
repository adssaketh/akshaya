import 'package:akshaya/features/pantry/domain/entities.dart';
import 'package:akshaya/features/pantry/domain/stock_logic.dart';
import 'package:akshaya/features/pantry/domain/unit.dart';
import 'package:akshaya/features/rescue/domain/freeze_rules.dart';
import 'package:akshaya/features/travel/domain/back_home.dart';
import 'package:akshaya/features/travel/domain/travel_plan.dart';
import 'package:akshaya/features/travel/domain/trip_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../pantry/domain/test_data.dart';
import '../../shopping/domain/shopping_test_data.dart';

Trip makeTrip({
  String id = 't1',
  DateTime? start,
  DateTime? end,
  bool pauseAlerts = true,
  bool pauseRecurring = true,
  bool essentialsAdded = false,
  List<EssentialLine> essentials = EssentialLine.defaults,
}) {
  return Trip(
    id: id,
    name: 'Goa',
    start: start ?? DateTime(2026, 11, 6),
    end: end ?? DateTime(2026, 11, 10),
    pauseRecurring: pauseRecurring,
    pauseAlerts: pauseAlerts,
    essentials: essentials,
    essentialsAdded: essentialsAdded,
  );
}

ItemStock stockOf(Item item, List<StockBatch> batches) {
  return StockLogic.summarize(
    ItemWithBatches(item: item, batches: batches),
    today: kToday,
    warningDays: 3,
  );
}

void main() {
  group('trip dates', () {
    test('the return day must come after the leaving day', () {
      expect(validateTripDates(DateTime(2026, 11, 6), DateTime(2026, 11, 6)),
          isNotNull);
      expect(validateTripDates(DateTime(2026, 11, 6), DateTime(2026, 11, 5)),
          isNotNull);
      expect(validateTripDates(DateTime(2026, 11, 6), DateTime(2026, 11, 7)),
          isNull);
    });

    test('a trip is limited to a year', () {
      final DateTime start = DateTime(2026, 11, 6);
      expect(validateTripDates(start, DateTime(2027, 11, 6)), isNull);
      expect(validateTripDates(start, DateTime(2027, 11, 7)), isNotNull);
    });

    test('phases and nights', () {
      final Trip trip = makeTrip();
      expect(trip.nights, 4);
      expect(trip.phaseOn(DateTime(2026, 11, 5)), TripPhase.upcoming);
      expect(trip.phaseOn(DateTime(2026, 11, 6)), TripPhase.away);
      expect(trip.phaseOn(DateTime(2026, 11, 9)), TripPhase.away);
      expect(trip.phaseOn(DateTime(2026, 11, 10)), TripPhase.back);
      expect(trip.essentialsDay, DateTime(2026, 11, 9));
    });
  });

  group('TripSchedule', () {
    final Trip trip = makeTrip();

    test('alerts pause on away days only, and resume on the return day', () {
      expect(TripSchedule.alertsPausedOn(DateTime(2026, 11, 5), [trip]), isFalse);
      expect(TripSchedule.alertsPausedOn(DateTime(2026, 11, 6), [trip]), isTrue);
      expect(TripSchedule.alertsPausedOn(DateTime(2026, 11, 9), [trip]), isTrue);
      expect(TripSchedule.alertsPausedOn(DateTime(2026, 11, 10), [trip]), isFalse);
    });

    test('a trip that does not pause alerts pauses nothing', () {
      expect(
        TripSchedule.alertsPausedOn(
          DateTime(2026, 11, 7),
          [makeTrip(pauseAlerts: false)],
        ),
        isFalse,
      );
    });

    test('repeating items come back on the latest return day', () {
      final Trip other = makeTrip(
        id: 't2',
        start: DateTime(2026, 11, 8),
        end: DateTime(2026, 11, 15),
      );
      expect(
        TripSchedule.recurringResumeOn(DateTime(2026, 11, 8), [trip, other]),
        DateTime(2026, 11, 15),
      );
      expect(
        TripSchedule.recurringResumeOn(DateTime(2026, 11, 5), [trip, other]),
        isNull,
      );
    });

    test('returning trips are found on their return day', () {
      expect(TripSchedule.returningOn(DateTime(2026, 11, 10), [trip]), [trip]);
      expect(TripSchedule.returningOn(DateTime(2026, 11, 9), [trip]), isEmpty);
    });

    test('featured: the trip away now, else one starting within two weeks', () {
      expect(TripSchedule.featured(DateTime(2026, 11, 7), [trip]), trip);
      expect(TripSchedule.featured(DateTime(2026, 11, 1), [trip]), trip);
      expect(TripSchedule.featured(DateTime(2026, 10, 1), [trip]), isNull);
      expect(TripSchedule.featured(DateTime(2026, 11, 12), [trip]), isNull);
    });
  });

  group('essentials', () {
    test('a line survives a round trip, damaged lines are dropped', () {
      const List<EssentialLine> lines = <EssentialLine>[
        EssentialLine(name: 'Milk', quantity: 1.5, unit: Unit.l),
        EssentialLine(name: 'Bread', quantity: 2, unit: Unit.packet),
      ];
      final List<EssentialLine> back =
          EssentialLine.decodeList(EssentialLine.encodeList(lines));
      expect(back.map((EssentialLine l) => l.label).toList(),
          <String>['Milk (1.5 L)', 'Bread (2 packets)']);
      expect(EssentialLine.decodeList('not json'), isEmpty);
      expect(EssentialLine.decodeList(null), isEmpty);
      expect(
        EssentialLine.decodeList('[{"name":"","quantity":1,"unit":"kg"},'
            '{"name":"Rice","quantity":-1,"unit":"kg"},'
            '{"name":"Dal","quantity":1,"unit":"nope"}]'),
        isEmpty,
      );
    });

    test('the checklist is due from the day before the return, once', () {
      final Trip trip = makeTrip();
      expect(BackHome.isDue(trip, DateTime(2026, 11, 8)), isFalse);
      expect(BackHome.isDue(trip, DateTime(2026, 11, 9)), isTrue);
      expect(BackHome.isDue(trip, DateTime(2026, 11, 10)), isTrue);
      expect(BackHome.isDue(trip, DateTime(2026, 11, 13)), isTrue);
      expect(BackHome.isDue(trip, DateTime(2026, 11, 14)), isFalse);
      expect(
        BackHome.isDue(makeTrip(essentialsAdded: true), DateTime(2026, 11, 9)),
        isFalse,
      );
      expect(
        BackHome.isDue(
          makeTrip(essentials: const <EssentialLine>[]),
          DateTime(2026, 11, 9),
        ),
        isFalse,
      );
    });

    test('items already waiting on a list are not doubled', () {
      final Trip trip = makeTrip();
      final missing = BackHome.missingFrom(
        trip,
        [makeEntry(id: 'e1', name: 'milk'), makeEntry(id: 'e2', name: 'Bread', checked: true)],
        DateTime(2026, 11, 9),
      );
      expect(
        missing.map((EssentialLine l) => l.name).toList(),
        <String>['Bread', 'Vegetables'],
      );
    });
  });

  group('TravelPlanner', () {
    final Trip trip = makeTrip(); // leaves 6 Nov, back 10 Nov; today 4 Nov.

    List<TravelRisk> plan(List<ItemStock> stocks) => TravelPlanner.build(
          trip: trip,
          stocks: stocks,
          today: kToday,
          freeze: const FreezeSettings(),
        );

    test('lists food that goes off before the return, soonest first', () {
      final List<TravelRisk> risks = plan(<ItemStock>[
        stockOf(makeItem(id: 'a', name: 'Milk', unit: Unit.l), <StockBatch>[
          makeBatch(id: 'a1', itemId: 'a', unit: Unit.l, expiry: DateTime(2026, 11, 8)),
        ]),
        stockOf(makeItem(id: 'b', name: 'Curd'), <StockBatch>[
          makeBatch(id: 'b1', itemId: 'b', expiry: DateTime(2026, 11, 5)),
        ]),
        stockOf(makeItem(id: 'c', name: 'Rice'), <StockBatch>[
          makeBatch(id: 'c1', itemId: 'c', expiry: DateTime(2026, 11, 10)),
        ]),
        stockOf(makeItem(id: 'd', name: 'Salt'), <StockBatch>[
          makeBatch(id: 'd1', itemId: 'd'),
        ]),
        stockOf(makeItem(id: 'e', name: 'Old'), <StockBatch>[
          makeBatch(id: 'e1', itemId: 'e', expiry: DateTime(2026, 11, 1)),
        ]),
      ]);
      expect(
        risks.map((TravelRisk r) => r.item.name).toList(),
        <String>['Curd', 'Milk'],
      );
      expect(risks.first.beforeLeaving, isTrue);
      expect(risks.first.advice, TravelAdvice.cookNow);
      expect(risks.first.reason, contains('before you leave'));
      expect(risks.last.beforeLeaving, isFalse);
      expect(risks.last.reason, contains('while you are away'));
    });

    test('food that goes off while away is frozen when it can be, else given', () {
      final DateTime expires = DateTime(2026, 11, 8);
      expect(
        TravelPlanner.adviceFor(
          trip: trip,
          today: kToday,
          expires: expires,
          canFreeze: true,
        ),
        TravelAdvice.freeze,
      );
      expect(
        TravelPlanner.adviceFor(
          trip: trip,
          today: kToday,
          expires: expires,
          canFreeze: false,
        ),
        TravelAdvice.giveAway,
      );
    });

    test('once the trip has started, nothing is cook-now', () {
      expect(
        TravelPlanner.adviceFor(
          trip: trip,
          today: DateTime(2026, 11, 7),
          expires: DateTime(2026, 11, 7),
          canFreeze: false,
        ),
        TravelAdvice.giveAway,
      );
    });
  });
}
