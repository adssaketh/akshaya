import 'package:akshaya/features/pantry/domain/default_categories.dart';
import 'package:akshaya/features/pantry/domain/entities.dart';
import 'package:akshaya/features/pantry/domain/suggested_categories.dart';
import 'package:akshaya/features/pantry/presentation/pantry_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

List<Category> _defaults() => <Category>[
      for (final (int i, DefaultCategory d) in kDefaultCategories.indexed)
        Category(id: d.id, name: d.name, iconKey: d.iconKey, sortOrder: i),
    ];

void main() {
  test('every suggestion uses an icon the picker knows', () {
    for (final SuggestedCategory s in kSuggestedCategories) {
      expect(
        kCategoryIconKeys,
        contains(s.iconKey),
        reason: '${s.name} uses unknown icon ${s.iconKey}',
      );
    }
  });

  test('icon keys and suggestion names are unique', () {
    expect(kCategoryIconKeys.toSet().length, kCategoryIconKeys.length);
    final List<String> names = <String>[
      for (final SuggestedCategory s in kSuggestedCategories)
        s.name.toLowerCase(),
    ];
    expect(names.toSet().length, names.length);
  });

  test('every default category icon still resolves to its own icon', () {
    for (final DefaultCategory d in kDefaultCategories) {
      if (d.iconKey == 'other') {
        continue;
      }
      expect(
        categoryIcon(d.iconKey),
        isNot(Icons.category_rounded),
        reason: '${d.name} lost its icon',
      );
    }
    expect(categoryIcon('something_new'), Icons.category_rounded);
    expect(categoryIcon(null), Icons.category_rounded);
  });

  test('suggestions offer eggs and dry fruits to a fresh install', () {
    final List<String> names = <String>[
      for (final SuggestedCategory s in missingSuggestions(_defaults())) s.name,
    ];
    expect(names, containsAll(<String>['Eggs', 'Dry Fruits & Nuts']));
    expect(names, hasLength(kSuggestedCategories.length));
  });

  test('a category that already exists is not suggested again', () {
    final List<Category> existing = <Category>[
      ..._defaults(),
      const Category(
        id: 'c1',
        name: 'dry fruits and nuts',
        iconKey: 'dry_fruits',
        sortOrder: 20,
      ),
      const Category(id: 'c2', name: 'EGGS', iconKey: 'eggs', sortOrder: 21),
    ];
    final List<String> names = <String>[
      for (final SuggestedCategory s in missingSuggestions(existing)) s.name,
    ];
    expect(names, isNot(contains('Dry Fruits & Nuts')));
    expect(names, isNot(contains('Eggs')));
    expect(names, contains('Pet Care'));
  });
}
