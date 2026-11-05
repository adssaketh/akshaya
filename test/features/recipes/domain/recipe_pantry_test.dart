import 'package:akshaya/features/pantry/domain/entities.dart';
import 'package:akshaya/features/pantry/domain/unit.dart';
import 'package:akshaya/features/recipes/domain/recipe_fingerprint.dart';
import 'package:akshaya/features/recipes/domain/recipe_models.dart';
import 'package:akshaya/features/recipes/domain/recipe_pantry.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../pantry/domain/test_data.dart';
import 'recipe_test_support.dart';

void main() {
  test('soonest expiry first; expired and empty stock do not count', () {
    final List<PantryLine> lines = linesFor(<ItemWithBatches>[
      stocked('rice', 'Rice'),
      stocked('milk', 'Milk', unit: Unit.L, expiry: DateTime(2026, 11, 6)),
      stocked('curd', 'Curd', expiry: DateTime(2026, 11, 5)),
      stocked('old', 'Old Bread', expiry: DateTime(2026, 11, 1)),
      ItemWithBatches(
        item: makeItem(id: 'gone', name: 'Sugar'),
        batches: <StockBatch>[makeBatch(id: 'bg', itemId: 'gone', remaining: 0)],
      ),
    ]);
    expect(
      RecipePantry.stocked(lines).map((PantryLine l) => l.name).toList(),
      <String>['Curd', 'Milk', 'Rice'],
    );
    expect(lines.first.daysLeft, 1);
  });

  test('expiringDays lists only items inside the warning window', () {
    final List<PantryLine> lines = linesFor(<ItemWithBatches>[
      stocked('rice', 'Rice'),
      stocked('milk', 'Milk', unit: Unit.L, expiry: DateTime(2026, 11, 6)),
      stocked('ghee', 'Ghee', expiry: DateTime(2027, 3, 1)),
    ]);
    expect(
      RecipePantry.expiringDays(lines, warningDays: 3),
      <String, int>{'milk': 2},
    );
  });

  test('forPrompt is limited', () {
    final List<PantryLine> lines = linesFor(<ItemWithBatches>[
      for (int i = 0; i < 80; i++) stocked('i$i', 'Item $i'),
    ]);
    expect(RecipePantry.forPrompt(lines).length, RecipePantry.maxPromptLines);
  });

  group('fingerprint', () {
    const RecipePreferences prefs = RecipePreferences();

    test('same pantry and preferences give the same code, in any order', () {
      final List<ItemWithBatches> a = <ItemWithBatches>[
        stocked('rice', 'Rice'),
        stocked('dal', 'Toor Dal'),
      ];
      final String one = RecipeFingerprint.compute(linesFor(a), prefs);
      final String two = RecipeFingerprint.compute(
        linesFor(a.reversed.toList()),
        prefs,
      );
      expect(one, two);
      expect(one.length, 16);
    });

    test('changed quantity, expiry or preferences change the code', () {
      final String base = RecipeFingerprint.compute(
        linesFor(<ItemWithBatches>[stocked('rice', 'Rice')]),
        prefs,
      );
      expect(
        RecipeFingerprint.compute(
          linesFor(<ItemWithBatches>[stocked('rice', 'Rice', qty: 2)]),
          prefs,
        ),
        isNot(base),
      );
      expect(
        RecipeFingerprint.compute(
          linesFor(<ItemWithBatches>[
            stocked('rice', 'Rice', expiry: DateTime(2026, 12, 1)),
          ]),
          prefs,
        ),
        isNot(base),
      );
      expect(
        RecipeFingerprint.compute(
          linesFor(<ItemWithBatches>[stocked('rice', 'Rice')]),
          prefs.copyWith(avoid: <String>['peanuts']),
        ),
        isNot(base),
      );
    });
  });
}
