import 'package:akshaya/features/pantry/domain/entities.dart';
import 'package:akshaya/features/pantry/domain/stock_logic.dart';
import 'package:akshaya/features/pantry/domain/unit.dart';
import 'package:akshaya/features/report/domain/report_bundle.dart';
import 'package:akshaya/features/report/domain/report_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../presentation/report_test_data.dart';

ReportBundle _bundle(List<ConsumptionEntry> history) {
  return buildReportBundle(
    period: ReportPeriod.week,
    today: reportToday,
    history: history,
    itemsById: <String, Item>{
      for (final ItemStock s in reportStocks) s.item.id: s.item,
    },
    people: 2,
    vegetarian: true,
    stocks: reportStocks,
  );
}

void main() {
  group('an item that was removed from the app', () {
    test('no longer counts towards the report or the streak', () {
      final ReportBundle b = _bundle(<ConsumptionEntry>[
        reportUsed('removed-item', 500, Unit.g),
      ]);
      expect(b.report.isEmpty, isTrue);
      expect(b.streak, 0);
    });

    test('a day still counts when other food was used that day', () {
      final ReportBundle b = _bundle(<ConsumptionEntry>[
        reportUsed('removed-item', 500, Unit.g),
        reportUsed('rice', 300, Unit.g),
      ]);
      expect(b.streak, 1);
    });
  });
}
