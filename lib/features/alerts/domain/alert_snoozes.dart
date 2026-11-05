import 'dart:convert';

import '../../../core/util/date_only.dart';

/// Key under which the snoozed items are stored (see `SettingsRepository`).
/// The value is JSON: `{"<itemId>": "2026-11-06"}`, each date being the last
/// day the item stays out of the alerts.
const String kAlertSnoozesSettingKey = 'alerts.snoozed';

/// Items left out of the alerts for a day ("Snooze 1 day" on a notification).
///
/// Snoozing on a day hides the item from the alerts of the next day; it
/// comes back the day after. Pure Dart.
final class AlertSnoozes {
  const AlertSnoozes([this.hiddenThrough = const <String, DateTime>{}]);

  /// Reads the snoozes from stored text, ignoring anything unreadable.
  factory AlertSnoozes.fromMap(Map<String, String> values) {
    final String? text = values[kAlertSnoozesSettingKey];
    if (text == null || text.isEmpty) {
      return const AlertSnoozes();
    }
    try {
      final Object? decoded = jsonDecode(text);
      if (decoded is! Map<String, dynamic>) {
        return const AlertSnoozes();
      }
      final Map<String, DateTime> result = <String, DateTime>{};
      for (final MapEntry<String, dynamic> e in decoded.entries) {
        final Object? v = e.value;
        final DateTime? day = v is String ? parseIsoDate(v) : null;
        if (day != null) {
          result[e.key] = day;
        }
      }
      return AlertSnoozes(result);
    } on FormatException {
      return const AlertSnoozes();
    }
  }

  /// Item id to the last day it stays out of the alerts.
  final Map<String, DateTime> hiddenThrough;

  bool get isEmpty => hiddenThrough.isEmpty;

  /// Whether the alerts for calendar day [day] leave [itemId] out.
  bool hides(String itemId, DateTime day) {
    final DateTime? last = hiddenThrough[itemId];
    return last != null && !dateOnly(day).isAfter(last);
  }

  /// Snoozes [itemIds] on [today]: out of the alerts through tomorrow. Snoozes
  /// that have run out are dropped.
  AlertSnoozes snooze(Iterable<String> itemIds, {required DateTime today}) {
    final DateTime day = dateOnly(today);
    final DateTime through = addDays(day, 1);
    final Map<String, DateTime> next = <String, DateTime>{
      for (final MapEntry<String, DateTime> e in hiddenThrough.entries)
        if (!e.value.isBefore(day)) e.key: e.value,
    };
    for (final String id in itemIds) {
      next[id] = through;
    }
    return AlertSnoozes(next);
  }

  /// The text form stored by the settings repository.
  Map<String, String> toMap() {
    return <String, String>{
      kAlertSnoozesSettingKey: jsonEncode(<String, String>{
        for (final MapEntry<String, DateTime> e in hiddenThrough.entries)
          e.key: formatIsoDate(e.value),
      }),
    };
  }

  @override
  bool operator ==(Object other) {
    if (other is! AlertSnoozes ||
        other.hiddenThrough.length != hiddenThrough.length) {
      return false;
    }
    for (final MapEntry<String, DateTime> e in hiddenThrough.entries) {
      if (other.hiddenThrough[e.key] != e.value) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode {
    final List<String> keys = hiddenThrough.keys.toList()..sort();
    return Object.hashAll(<Object>[
      for (final String key in keys) ...<Object>[key, hiddenThrough[key]!],
    ]);
  }
}
