import 'package:akshaya/features/pantry/domain/entities.dart';
import 'package:akshaya/features/pantry/domain/storage_location.dart';
import 'package:akshaya/features/rescue/domain/freeze_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../pantry/domain/test_data.dart';

void main() {
  group('FreezeSettings', () {
    test('uses built-in days until changed', () {
      const FreezeSettings s = FreezeSettings();
      expect(s.daysFor('cat_grains'), 180);
      expect(s.daysFor('cat_oils'), isNull);
      expect(s.daysFor('custom_cat'), FreezeDefaults.unknownCategoryDays);
    });

    test('overrides, off and reset', () {
      FreezeSettings s = const FreezeSettings().withDays('cat_dairy', 10);
      expect(s.daysFor('cat_dairy'), 10);
      expect(s.isCustom('cat_dairy'), isTrue);
      s = s.withDays('cat_dairy', null);
      expect(s.daysFor('cat_dairy'), isNull);
      s = s.reset('cat_dairy');
      expect(s.daysFor('cat_dairy'), 60);
      expect(s.withDays('cat_dairy', 99999).daysFor('cat_dairy'), kMaxFreezeDays);
    });

    test('round-trips through the stored map', () {
      final FreezeSettings s = const FreezeSettings()
          .withDays('cat_dairy', 10)
          .withDays('cat_oils', 20);
      expect(FreezeSettings.fromMap(s.toMap()), s);
      expect(
        FreezeSettings.fromMap(<String, String>{kFreezeDaysSettingKey: 'x'}),
        const FreezeSettings(),
      );
    });
  });

  group('Freezer', () {
    final DateTime today = DateTime(2026, 11, 4);

    test('moves to the freezer and extends the date', () {
      final FreezePlan plan = Freezer.plan(
        item: makeItem(categoryId: 'cat_grains'),
        batch: makeBatch(
          expiry: DateTime(2026, 11, 6),
          opened: DateTime(2026, 11, 1),
          within: 5,
        ),
        settings: const FreezeSettings(),
        today: today,
      )!;
      expect(plan.frozen.storageLocation, StorageLocation.freezer);
      expect(plan.frozen.expiryDate, DateTime(2027, 5, 3));
      expect(plan.frozen.useWithinDaysAfterOpening, isNull);
      expect(plan.days, 180);
    });

    test('keeps a later printed date', () {
      final FreezePlan plan = Freezer.plan(
        item: makeItem(categoryId: 'cat_dairy'),
        batch: makeBatch(expiry: DateTime(2028, 1, 1)),
        settings: const FreezeSettings(),
        today: today,
      )!;
      expect(plan.frozen.expiryDate, DateTime(2028, 1, 1));
    });

    test('refuses expired, already frozen, empty and unfreezable', () {
      bool can(Item item, StockBatch batch) => Freezer.canFreeze(
            item: item,
            batch: batch,
            settings: const FreezeSettings(),
            today: today,
          );
      final Item item = makeItem(categoryId: 'cat_grains');
      expect(can(item, makeBatch(expiry: DateTime(2026, 11, 3))), isFalse);
      expect(
        can(item, makeBatch(location: StorageLocation.freezer)),
        isFalse,
      );
      expect(can(item, makeBatch(remaining: 0)), isFalse);
      expect(
        can(makeItem(categoryId: 'cat_oils'), makeBatch()),
        isFalse,
      );
      expect(can(item, makeBatch(expiry: DateTime(2026, 11, 4))), isTrue);
    });
  });
}
