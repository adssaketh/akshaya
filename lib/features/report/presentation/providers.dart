import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/report_models.dart';

/// Which window the Home report card shows.
final NotifierProvider<ReportPeriodNotifier, ReportPeriod>
    reportPeriodProvider =
    NotifierProvider<ReportPeriodNotifier, ReportPeriod>(
  ReportPeriodNotifier.new,
);

class ReportPeriodNotifier extends Notifier<ReportPeriod> {
  @override
  ReportPeriod build() => ReportPeriod.today;

  void select(ReportPeriod period) => state = period;
}
