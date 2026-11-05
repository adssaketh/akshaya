import 'package:akshaya/core/design/design.dart';
import 'package:akshaya/features/sync/data/sync_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('wallpaper theme changes brand colours but keeps status meaning', () {
    final ThemeData themed = AkshayaTheme.fromSystemScheme(
      ColorScheme.fromSeed(seedColor: Colors.blue),
    );
    final AkshayaColors colors = themed.extension<AkshayaColors>()!;
    expect(colors.primary, isNot(AkshayaColors.light.primary));
    expect(colors.expired.foreground, AkshayaColors.light.expired.foreground);
    expect(colors.fresh.background, AkshayaColors.light.fresh.background);
  });

  test('wallpaper primary is exactly the system primary', () {
    final ColorScheme system = ColorScheme.fromSeed(seedColor: Colors.blue);
    final AkshayaColors colors =
        AkshayaTheme.fromSystemScheme(system).extension<AkshayaColors>()!;
    expect(colors.primary, system.primary);
  });

  test('dark wallpaper theme is dark', () {
    final ThemeData themed = AkshayaTheme.fromSystemScheme(
      ColorScheme.fromSeed(
        seedColor: Colors.indigo,
        brightness: Brightness.dark,
      ),
    );
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
