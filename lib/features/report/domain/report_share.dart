import 'report_models.dart';

String _grouped(int value) {
  return value.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (Match _) => ',',
  );
}

/// A short plain-text summary for sharing (WhatsApp, Messages, ...).
String buildShareText(ConsumptionReport report) {
  final StringBuffer b = StringBuffer()
    ..writeln(
      'Food report: ${report.period.label.toLowerCase()} '
      '(for ${report.people} ${report.people == 1 ? 'person' : 'people'})',
    );
  if (report.isEmpty) {
    b.writeln('Nothing was marked as used in this period.');
    return b.toString().trimRight();
  }
  final double? kcal = report.kcalPerPersonPerDay;
  if (kcal != null) {
    b.writeln(
      'About ${_grouped((kcal / 10).round() * 10)} kcal per person '
      'a day (estimate)',
    );
  }
  final NutrientAverages? n = report.nutrients;
  if (n != null) {
    b.writeln(
      'Protein ${n.protein.round()} g, fibre ${n.fibre.round()} g, '
      'fat ${n.fat.round()} g per person a day',
    );
  }
  switch (report.verdict) {
    case BalanceVerdict.balanced:
      b.writeln('Balance: balanced');
    case BalanceVerdict.partly:
      b.writeln('Balance: partly balanced');
    case BalanceVerdict.notBalanced:
      b.writeln('Balance: not balanced yet');
    case BalanceVerdict.notEnoughData:
      b.writeln('Balance: too little logged to judge');
  }
  if (report.missing.isNotEmpty) {
    b.writeln(
      'Missing: ${<String>[for (final PlateGroup g in report.missing) g.label.toLowerCase()].join(', ')}',
    );
  }
  final List<String> top = <String>[
    for (final ConsumedLine l in report.lines.take(5)) l.name,
  ];
  if (top.isNotEmpty) {
    b.writeln('Most used: ${top.join(', ')}');
  }
  for (final String tip in report.tips.take(3)) {
    b.writeln('- $tip');
  }
  b.write('Estimates from what was marked as used in Akshaya Patra.');
  return b.toString();
}
