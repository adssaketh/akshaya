import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../util/date_only.dart';

/// Source of the current time. Tests override it with a fixed instant.
final Provider<DateTime Function()> clockProvider =
    Provider<DateTime Function()>((Ref ref) => DateTime.now);

/// Today's calendar date. Status and expiry labels depend on it, so the app
/// calls [TodayNotifier.refresh] whenever it returns to the foreground to pick
/// up a new day.
final NotifierProvider<TodayNotifier, DateTime> todayProvider =
    NotifierProvider<TodayNotifier, DateTime>(TodayNotifier.new);

class TodayNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => dateOnly(ref.read(clockProvider)());

  /// Moves to the current date if the day has changed.
  void refresh() {
    final DateTime now = dateOnly(ref.read(clockProvider)());
    if (now != state) {
      state = now;
    }
  }
}
