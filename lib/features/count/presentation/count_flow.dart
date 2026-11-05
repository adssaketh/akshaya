import 'package:flutter/material.dart';

import '../../pantry/domain/entities.dart';
import '../../pantry/domain/stock_count.dart';
import 'count_start_screen.dart';

/// Opens Count mode's start screen (where to count, and any count to resume).
Future<void> openCountMode(BuildContext context) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (BuildContext routeContext) => const CountStartScreen(),
    ),
  );
}

/// "Fridge", "Dals & Pulses" or "Everything".
String countScopeLabel(CountScope scope, Map<String, Category> categories) {
  switch (scope.kind) {
    case CountScopeKind.all:
      return 'Everything';
    case CountScopeKind.location:
      return scope.location!.label;
    case CountScopeKind.category:
      return categories[scope.categoryId]?.name ?? 'Category';
  }
}
