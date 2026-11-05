import 'dart:convert';

import '../../../core/util/date_only.dart';
import '../../pantry/domain/unit.dart';

/// The longest trip that can be entered, in nights.
const int kMaxTripNights = 365;

/// One thing to buy on the way back ("Milk, 1 L"). Kept on the trip, so the
/// list can be edited per trip.
final class EssentialLine {
  const EssentialLine({
    required this.name,
    required this.quantity,
    required this.unit,
  });

  /// English name, as it would be typed on the shopping list.
  final String name;
  final double quantity;
  final Unit unit;

  /// "Milk (1 L)".
  String get label => '$name (${unit.format(quantity)})';

  Map<String, Object?> toJson() => <String, Object?>{
        'name': name,
        'quantity': quantity,
        'unit': unit.name,
      };

  /// Reads one line; null when it is damaged or empty.
  static EssentialLine? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      return null;
    }
    final Object? name = json['name'];
    final Object? quantity = json['quantity'];
    final Object? unitName = json['unit'];
    if (name is! String || name.trim().isEmpty || quantity is! num) {
      return null;
    }
    if (quantity <= 0 || quantity > 100000) {
      return null;
    }
    Unit? unit;
    for (final Unit u in Unit.values) {
      if (u.name == unitName) {
        unit = u;
        break;
      }
    }
    if (unit == null) {
      return null;
    }
    return EssentialLine(
      name: name.trim(),
      quantity: quantity.toDouble(),
      unit: unit,
    );
  }

  /// Reads the stored list; anything unreadable gives an empty list.
  static List<EssentialLine> decodeList(String? text) {
    if (text == null || text.trim().isEmpty) {
      return const <EssentialLine>[];
    }
    try {
      final Object? decoded = jsonDecode(text);
      if (decoded is! List<dynamic>) {
        return const <EssentialLine>[];
      }
      final List<EssentialLine> out = <EssentialLine>[];
      for (final Object? part in decoded) {
        final EssentialLine? line = fromJson(part);
        if (line != null) {
          out.add(line);
        }
      }
      return out;
    } on FormatException {
      return const <EssentialLine>[];
    }
  }

  /// The text stored on the trip.
  static String encodeList(List<EssentialLine> lines) {
    return jsonEncode(<Map<String, Object?>>[
      for (final EssentialLine line in lines) line.toJson(),
    ]);
  }

  /// What a new trip starts with.
  static const List<EssentialLine> defaults = <EssentialLine>[
    EssentialLine(name: 'Milk', quantity: 1, unit: Unit.l),
    EssentialLine(name: 'Bread', quantity: 1, unit: Unit.packet),
    EssentialLine(name: 'Vegetables', quantity: 1, unit: Unit.kg),
  ];
}

/// Where a trip is on a given day.
enum TripPhase {
  /// Not left yet.
  upcoming,

  /// Away: from the leaving day up to the day before the return.
  away,

  /// The return day or later.
  back,
}

/// A trip the household is away on. The leaving day is [start]; [end] is the
/// day everyone is back (the first day alerts and repeating items resume).
final class Trip {
  const Trip({
    required this.id,
    required this.name,
    required this.start,
    required this.end,
    required this.pauseRecurring,
    required this.pauseAlerts,
    required this.essentials,
    required this.essentialsAdded,
  });

  final String id;

  /// What the person called it; may be empty.
  final String name;
  final DateTime start;
  final DateTime end;

  /// Hold repeating shopping items back until [end].
  final bool pauseRecurring;

  /// Stop the daily expiry and low-stock alerts until [end].
  final bool pauseAlerts;

  /// What to put on the shopping list the day before [end].
  final List<EssentialLine> essentials;

  /// True once the essentials were put on the list.
  final bool essentialsAdded;

  /// The name to show: the trip's own or "Trip".
  String get label => name.trim().isEmpty ? 'Trip' : name.trim();

  /// Nights away.
  int get nights => daysBetween(start, end);

  /// "4 Nov to 9 Nov 2026".
  String get dateRange =>
      '${formatDateShort(start)} to ${formatDate(end)}';

  TripPhase phaseOn(DateTime today) {
    final DateTime day = dateOnly(today);
    if (day.isBefore(start)) {
      return TripPhase.upcoming;
    }
    if (day.isBefore(end)) {
      return TripPhase.away;
    }
    return TripPhase.back;
  }

  /// The day the essentials go on the shopping list: the day before [end].
  DateTime get essentialsDay => addDays(end, -1);

  Trip copyWith({
    String? name,
    DateTime? start,
    DateTime? end,
    bool? pauseRecurring,
    bool? pauseAlerts,
    List<EssentialLine>? essentials,
    bool? essentialsAdded,
  }) {
    return Trip(
      id: id,
      name: name ?? this.name,
      start: start ?? this.start,
      end: end ?? this.end,
      pauseRecurring: pauseRecurring ?? this.pauseRecurring,
      pauseAlerts: pauseAlerts ?? this.pauseAlerts,
      essentials: essentials ?? this.essentials,
      essentialsAdded: essentialsAdded ?? this.essentialsAdded,
    );
  }
}

/// Everything needed to add a trip.
final class TripDraft {
  const TripDraft({
    required this.name,
    required this.start,
    required this.end,
    this.pauseRecurring = true,
    this.pauseAlerts = true,
    this.essentials = EssentialLine.defaults,
  });

  final String name;
  final DateTime start;
  final DateTime end;
  final bool pauseRecurring;
  final bool pauseAlerts;
  final List<EssentialLine> essentials;
}

/// Why a trip's dates are not acceptable, or null when they are.
String? validateTripDates(DateTime start, DateTime end) {
  final DateTime s = dateOnly(start);
  final DateTime e = dateOnly(end);
  if (!e.isAfter(s)) {
    return 'The return day must be after the day you leave.';
  }
  if (daysBetween(s, e) > kMaxTripNights) {
    return 'A trip can be at most $kMaxTripNights nights.';
  }
  return null;
}

/// Which days are "away" days and what that pauses. Pure Dart.
abstract final class TripSchedule {
  /// Whether [day] is an away day of [trip]: the leaving day up to the day
  /// before the return.
  static bool awayOn(Trip trip, DateTime day) {
    final DateTime d = dateOnly(day);
    return !d.isBefore(trip.start) && d.isBefore(trip.end);
  }

  /// Whether the daily alerts are paused on [day].
  static bool alertsPausedOn(DateTime day, Iterable<Trip> trips) {
    for (final Trip trip in trips) {
      if (trip.pauseAlerts && awayOn(trip, day)) {
        return true;
      }
    }
    return false;
  }

  /// The day repeating shopping items come back, when they are paused on
  /// [day]; null when they are not. With overlapping trips, the latest return
  /// wins.
  static DateTime? recurringResumeOn(DateTime day, Iterable<Trip> trips) {
    DateTime? latest;
    for (final Trip trip in trips) {
      if (trip.pauseRecurring && awayOn(trip, day)) {
        if (latest == null || trip.end.isAfter(latest)) {
          latest = trip.end;
        }
      }
    }
    return latest;
  }

  /// Trips whose return day is [day] and that held something back.
  static List<Trip> returningOn(DateTime day, Iterable<Trip> trips) {
    final DateTime d = dateOnly(day);
    return <Trip>[
      for (final Trip trip in trips)
        if (trip.end == d && (trip.pauseAlerts || trip.pauseRecurring)) trip,
    ];
  }

  /// The trip to feature: the one away now, else the next one to start
  /// within [lookAheadDays], else null.
  static Trip? featured(
    DateTime today,
    Iterable<Trip> trips, {
    int lookAheadDays = 14,
  }) {
    final DateTime day = dateOnly(today);
    Trip? next;
    for (final Trip trip in trips) {
      switch (trip.phaseOn(day)) {
        case TripPhase.away:
          return trip;
        case TripPhase.upcoming:
          if (daysBetween(day, trip.start) <= lookAheadDays &&
              (next == null || trip.start.isBefore(next.start))) {
            next = trip;
          }
        case TripPhase.back:
          break;
      }
    }
    return next;
  }
}
