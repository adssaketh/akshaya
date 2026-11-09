import 'package:akshaya/core/design/design.dart';
import 'package:akshaya/core/time/clock.dart';
import 'package:akshaya/features/pantry/domain/entities.dart';
import 'package:akshaya/features/pantry/domain/failures.dart';
import 'package:akshaya/features/pantry/presentation/providers.dart';
import 'package:akshaya/features/pantry/presentation/recycle_bin_screen.dart';
import 'package:akshaya/features/settings/presentation/providers.dart';
import 'package:akshaya/features/settings/presentation/swipe_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../settings/fake_settings_repository.dart';
import '../domain/test_data.dart';
import 'fake_repository.dart';

final DateTime now = DateTime(2026, 11, 9, 18);

DeletedItem gone(
  String id,
  String name, {
  Duration ago = const Duration(hours: 3),
  int batches = 2,
}) => DeletedItem(
  item: makeItem(id: id, name: name),
  deletedAt: now.subtract(ago),
  batchCount: batches,
);

Widget host(
  FakePantryRepository repo,
  Widget home, {
  FakeSettingsRepository? settings,
}) {
  return ProviderScope(
    overrides: [
      pantryRepositoryProvider.overrideWithValue(repo),
      settingsRepositoryProvider.overrideWithValue(
        settings ?? FakeSettingsRepository(),
      ),
      clockProvider.overrideWithValue(() => now),
    ],
    child: MaterialApp(theme: AkshayaTheme.light(), home: home),
  );
}

void main() {
  void bigScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  group('the wording of a deletion', () {
    test('how long ago', () {
      String ago(Duration d) => deletedAgo(now.subtract(d), now);
      expect(ago(Duration.zero), 'just now');
      expect(ago(const Duration(seconds: 40)), 'just now');
      expect(ago(const Duration(minutes: 5)), '5 min ago');
      expect(ago(const Duration(minutes: 59)), '59 min ago');
      expect(ago(const Duration(hours: 3)), '3 h ago');
      expect(ago(const Duration(hours: 23)), '23 h ago');
      expect(ago(const Duration(hours: 30)), 'yesterday');
      expect(ago(const Duration(days: 6)), '6 days ago');
    });

    test('days left in the bin', () {
      int left(int days) =>
          binDaysLeft(now.subtract(Duration(days: days)), now);
      expect(left(0), 30);
      expect(left(10), 20);
      expect(left(29), 1);
      expect(left(30), 1, reason: 'never shows 0 while it is still listed');
    });
  });

  group('the bin screen', () {
    testWidgets('empty: says so', (tester) async {
      bigScreen(tester);
      await tester.pumpWidget(
        host(FakePantryRepository(), const RecycleBinScreen()),
      );
      await tester.pumpAndSettle();
      expect(find.text('Nothing deleted lately'), findsOneWidget);
      expect(find.text('Restore'), findsNothing);
    });

    testWidgets('lists each deleted item with when and how much', (
      tester,
    ) async {
      bigScreen(tester);
      final FakePantryRepository repo = FakePantryRepository()
        ..binItems = <DeletedItem>[
          gone('i1', 'Basmati Rice'),
          gone('i2', 'Milk', ago: const Duration(days: 2), batches: 1),
          gone('i3', 'Salt', ago: const Duration(minutes: 4), batches: 0),
        ];
      await tester.pumpWidget(host(repo, const RecycleBinScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Basmati Rice'), findsOneWidget);
      expect(find.text('Deleted 3 h ago · 2 batches'), findsOneWidget);
      expect(find.text('Deleted 2 days ago · 1 batch'), findsOneWidget);
      expect(find.text('Deleted 4 min ago · no stock left'), findsOneWidget);
      expect(find.text('Restore'), findsNWidgets(3));
      expect(find.textContaining('30 days'), findsWidgets);
    });

    testWidgets('Restore brings the item back and says so', (tester) async {
      bigScreen(tester);
      final FakePantryRepository repo = FakePantryRepository()
        ..binItems = <DeletedItem>[gone('i1', 'Basmati Rice')];
      await tester.pumpWidget(host(repo, const RecycleBinScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Restore'));
      await tester.pumpAndSettle();
      expect(repo.restoredIds, <String>['i1']);
      expect(find.text('Restored Basmati Rice'), findsOneWidget);
    });

    testWidgets('a name that is taken again is explained, not lost', (
      tester,
    ) async {
      bigScreen(tester);
      final FakePantryRepository repo = FakePantryRepository()
        ..binItems = <DeletedItem>[gone('i1', 'Basmati Rice')]
        ..restoreError = DuplicateItemFailure(
          existingItemId: 'x',
          name: 'Basmati Rice',
        );
      await tester.pumpWidget(host(repo, const RecycleBinScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Restore'));
      await tester.pumpAndSettle();
      expect(find.textContaining('already in your pantry'), findsOneWidget);
      expect(repo.restoredIds, isEmpty);
      expect(
        find.text('Basmati Rice'),
        findsOneWidget,
        reason: 'it is still in the bin',
      );
    });
  });

  group('the swipe options in Settings', () {
    Widget section(FakeSettingsRepository s, FakePantryRepository r) => host(
      r,
      const Scaffold(body: SingleChildScrollView(child: SwipeSection())),
      settings: s,
    );

    testWidgets('tab swiping starts on, item swipes start off', (tester) async {
      bigScreen(tester);
      await tester.pumpWidget(
        section(FakeSettingsRepository(), FakePantryRepository()),
      );
      await tester.pumpAndSettle();
      final List<SwitchListTile> tiles = tester
          .widgetList<SwitchListTile>(find.byType(SwitchListTile))
          .toList();
      expect(tiles, hasLength(2));
      expect(tiles[0].value, isTrue, reason: 'swipe to change tab');
      expect(tiles[1].value, isFalse, reason: 'swipe an item to use/delete');
    });

    testWidgets('the switches save and the screen follows', (tester) async {
      bigScreen(tester);
      final FakeSettingsRepository settings = FakeSettingsRepository();
      await tester.pumpWidget(section(settings, FakePantryRepository()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Swipe to change tab'));
      await tester.pumpAndSettle();
      expect(settings.values[kSwipeTabsKey], 'false');
      await tester.tap(find.text('Swipe an item to use or delete it'));
      await tester.pumpAndSettle();
      expect(settings.values[kSwipeItemsKey], 'true');
      final List<SwitchListTile> tiles = tester
          .widgetList<SwitchListTile>(find.byType(SwitchListTile))
          .toList();
      expect(tiles[0].value, isFalse);
      expect(tiles[1].value, isTrue);
    });

    testWidgets('it explains why item swipes are off', (tester) async {
      bigScreen(tester);
      await tester.pumpWidget(
        section(FakeSettingsRepository(), FakePantryRepository()),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('never touches your food'), findsOneWidget);
    });

    testWidgets('Recently deleted opens the bin', (tester) async {
      bigScreen(tester);
      final FakePantryRepository repo = FakePantryRepository()
        ..binItems = <DeletedItem>[gone('i1', 'Basmati Rice')];
      await tester.pumpWidget(section(FakeSettingsRepository(), repo));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Recently deleted'));
      await tester.pumpAndSettle();
      expect(find.byType(RecycleBinScreen), findsOneWidget);
      expect(find.text('Basmati Rice'), findsOneWidget);
    });
  });
}
