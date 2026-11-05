import 'package:akshaya/features/pantry/data/database/app_database.dart';
import 'package:akshaya/features/pantry/data/drift_pantry_repository.dart';
import 'package:akshaya/features/pantry/domain/default_categories.dart';
import 'package:akshaya/features/pantry/domain/entities.dart';
import 'package:akshaya/features/pantry/domain/failures.dart';
import 'package:akshaya/features/pantry/domain/unit.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late DriftPantryRepository repo;
  int counter = 0;

  setUp(() {
    counter = 0;
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftPantryRepository(
      db,
      clock: () => DateTime(2026, 11, 4, 10),
      idGenerator: () => 'id-${counter++}',
    );
  });

  tearDown(() => db.close());

  Future<List<Category>> categories() => repo.watchCategories().first;

  test('adds a category at the end of the list', () async {
    await repo.addCategory(name: '  Pooja items ', iconKey: 'other');
    final List<Category> list = await categories();
    expect(list.last.name, 'Pooja items');
    expect(list.length, kDefaultCategories.length + 1);
  });

  test('refuses an empty or duplicate name', () async {
    await expectLater(
      repo.addCategory(name: '  ', iconKey: 'other'),
      throwsA(isA<InvalidInputFailure>()),
    );
    await expectLater(
      repo.addCategory(name: 'dairy', iconKey: 'dairy'),
      throwsA(isA<InvalidInputFailure>()),
    );
  });

  test('renames and changes the icon', () async {
    await repo.updateCategory(id: 'cat_snacks', name: 'Tiffin', iconKey: 'bakery');
    final Category c =
        (await categories()).firstWhere((Category c) => c.id == 'cat_snacks');
    expect(c.name, 'Tiffin');
    expect(c.iconKey, 'bakery');
  });

  test('deletes an empty category but not one with items or the default',
      () async {
    await repo.addItem(
      const ItemDraft(
        name: 'Rice',
        categoryId: 'cat_grains',
        defaultUnit: Unit.kg,
      ),
    );
    await expectLater(
      repo.deleteCategory('cat_grains'),
      throwsA(isA<InvalidInputFailure>()),
    );
    await expectLater(
      repo.deleteCategory(kDefaultCategoryId),
      throwsA(isA<InvalidInputFailure>()),
    );
    await repo.deleteCategory('cat_snacks');
    expect(
      (await categories()).any((Category c) => c.id == 'cat_snacks'),
      isFalse,
    );
  });
}
