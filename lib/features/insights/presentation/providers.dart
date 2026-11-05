import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/clock.dart';
import '../../pantry/domain/entities.dart';
import '../../pantry/presentation/providers.dart';
import '../domain/insights.dart';

/// Every use, waste and expiry entry (newest first).
final StreamProvider<List<ConsumptionEntry>> allHistoryProvider =
    StreamProvider<List<ConsumptionEntry>>((Ref ref) {
  return ref.watch(pantryRepositoryProvider).watchAllHistory();
});

/// The month Insights is showing.
final NotifierProvider<InsightsMonthNotifier, DateTime> insightsMonthProvider =
    NotifierProvider<InsightsMonthNotifier, DateTime>(
  InsightsMonthNotifier.new,
);

class InsightsMonthNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => monthOf(ref.read(todayProvider));

  void previous() => state = addMonths(state, -1);

  /// Never moves past the current month.
  void next() {
    final DateTime current = monthOf(ref.read(todayProvider));
    final DateTime target = addMonths(state, 1);
    if (!target.isAfter(current)) {
      state = target;
    }
  }
}
