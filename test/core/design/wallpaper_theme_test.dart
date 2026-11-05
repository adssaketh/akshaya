import 'package:akshaya/core/design/design.dart';
import 'package:akshaya/features/sync/data/sync_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('wallpaper theme changes brand colours but keeps status meaning', () {
    final ThemeData themed = AkshayaTheme.lightFromSeed(Colors.teal);
    final AkshayaColors colors = themed.extension<AkshayaColors>()!;
    expect(colors.primary, isNot(AkshayaColors.light.primary));
    expect(colors.expired.foreground, AkshayaColors.light.expired.foreground);
    expect(colors.fresh.background, AkshayaColors.light.fresh.background);
  });

  test('dark wallpaper theme is dark', () {
    final ThemeData themed = AkshayaTheme.darkFromSeed(Colors.indigo);
    expect(themed.brightness, Brightness.dark);
  });

  test('refused collections are named in plain words', () {
    expect(refusedCollectionsMessage(<String>{}), isNull);
    final String message =
        refusedCollectionsMessage(<String>{'mealPlan', 'trips'})!;
    expect(message, contains('meal plan'));
    expect(message, contains('trips'));
  });
}
