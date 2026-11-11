import 'package:akshaya/features/sync/domain/sync_documents.dart';
import 'package:akshaya/features/sync/domain/sync_schema.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final Map<String, Object?> entryRow = <String, Object?>{
    'id': 'e1',
    'household_id': null,
    'created_at': 100,
    'updated_at': 200,
    'updated_by': null,
    'is_deleted': 0,
    'list_id': 'l1',
    'item_id': null,
    'name': 'Rice',
    'quantity': 2.5,
    'unit': 'kg',
    'is_checked': 1,
    'added_reason': 'manual',
    'priority': 'normal',
    'notes': null,
    'recurrence': 'none',
    'due_on': null,
    'repeat_every_days': 10,
    'sync_status': 'pending',
  };

  test('toRemote makes booleans, stamps the household and author', () {
    final Map<String, Object?> doc = SyncDocuments.toRemote(
      SyncSchema.entries,
      entryRow,
      householdId: 'h1',
      userId: 'u1',
    );
    expect(doc['isChecked'], true);
    expect(doc['isDeleted'], false);
    expect(doc['householdId'], 'h1');
    expect(doc['updatedBy'], 'u1');
    expect(doc['quantity'], 2.5);
    expect(doc.containsKey('syncStatus'), isFalse);
    expect(doc.containsKey('syncedAt'), isFalse);
  });

  test('toLocal reverses toRemote', () {
    final Map<String, Object?> doc = SyncDocuments.toRemote(
      SyncSchema.entries,
      entryRow,
      householdId: 'h1',
      userId: 'u1',
    );
    final Map<String, Object?> row = SyncDocuments.toLocal(
      SyncSchema.entries,
      doc,
    );
    expect(row['is_checked'], 1);
    expect(row['is_deleted'], 0);
    expect(row['name'], 'Rice');
    expect(row['quantity'], 2.5);
    expect(row['updated_by'], 'u1');
  });

  test('the custom repeat interval travels and may be missing', () {
    final Map<String, Object?> doc = SyncDocuments.toRemote(
      SyncSchema.entries,
      entryRow,
      householdId: 'h1',
      userId: 'u1',
    );
    expect(doc['repeatEveryDays'], 10);
    expect(
      SyncDocuments.toLocal(SyncSchema.entries, doc)['repeat_every_days'],
      10,
    );
    // An older build never writes the field.
    doc.remove('repeatEveryDays');
    expect(
      SyncDocuments.toLocal(SyncSchema.entries, doc)['repeat_every_days'],
      isNull,
    );
  });

  test('toLocal rejects a document missing a required field', () {
    final Map<String, Object?> doc = SyncDocuments.toRemote(
      SyncSchema.entries,
      entryRow,
      householdId: 'h1',
      userId: 'u1',
    )..remove('name');
    expect(
      () => SyncDocuments.toLocal(SyncSchema.entries, doc),
      throwsFormatException,
    );
  });

  test('items carry their aliases and barcodes', () {
    final Map<String, Object?> doc = SyncDocuments.toRemote(
      SyncSchema.items,
      <String, Object?>{
        'id': 'i1',
        'created_at': 1,
        'updated_at': 2,
        'is_deleted': 0,
        'name': 'Rice',
        'category_id': 'c1',
        'default_unit': 'kg',
        'is_essential': 0,
        'default_storage_location': 'pantry',
      },
      householdId: 'h1',
      userId: 'u1',
      aliases: <String>['biyyam'],
      barcodes: <String>['8901234567890'],
    );
    expect(SyncDocuments.aliasesOf(doc), <String>['biyyam']);
    expect(SyncDocuments.barcodesOf(doc), <String>['8901234567890']);
  });

  group('Phase 9 columns', () {
    final Map<String, Object?> itemRow = <String, Object?>{
      'id': 'i1',
      'created_at': 1,
      'updated_at': 2,
      'is_deleted': 0,
      'name': 'Sambar',
      'category_id': 'c1',
      'default_unit': 'portion',
      'is_essential': 0,
      'default_storage_location': 'fridge',
      'kind': 'cooked',
      'shelf_life_days': 3,
    };

    test('kind and shelf life travel with the item', () {
      final Map<String, Object?> doc = SyncDocuments.toRemote(
        SyncSchema.items,
        itemRow,
        householdId: 'h1',
        userId: 'u1',
      );
      expect(doc['kind'], 'cooked');
      expect(doc['shelfLifeDays'], 3);
      final Map<String, Object?> row =
          SyncDocuments.toLocal(SyncSchema.items, doc);
      expect(row['kind'], 'cooked');
      expect(row['shelf_life_days'], 3);
    });

    test('a document from an older app still loads', () {
      final Map<String, Object?> doc = SyncDocuments.toRemote(
        SyncSchema.items,
        itemRow,
        householdId: 'h1',
        userId: 'u1',
      )
        ..remove('kind')
        ..remove('shelfLifeDays');
      final Map<String, Object?> row =
          SyncDocuments.toLocal(SyncSchema.items, doc);
      expect(row['kind'], isNull);
      expect(row['shelf_life_days'], isNull);
    });
  });

  test('a meal plan row travels as a document and back', () {
    final Map<String, Object?> row = <String, Object?>{
      'id': 'm1',
      'household_id': null,
      'created_at': 100,
      'updated_at': 200,
      'updated_by': null,
      'is_deleted': 0,
      'plan_date': '2026-11-06',
      'slot': 'dinner',
      'title': 'Rajma Masala',
      'recipe_json': '{"title":"Rajma Masala"}',
      'leftover_item_id': null,
      'is_cooked': 1,
      'prep_json': '[{"text":"Soak Rajma","daysBefore":1,"minutes":1200}]',
      'sync_status': 'pending',
    };
    final Map<String, Object?> doc = SyncDocuments.toRemote(
      SyncSchema.mealPlan,
      row,
      householdId: 'h1',
      userId: 'u1',
    );
    expect(doc['planDate'], '2026-11-06');
    expect(doc['isCooked'], true);
    expect(doc['prepJson'], contains('Soak Rajma'));
    expect(doc.containsKey('syncStatus'), isFalse);
    final Map<String, Object?> back =
        SyncDocuments.toLocal(SyncSchema.mealPlan, doc);
    expect(back['plan_date'], '2026-11-06');
    expect(back['is_cooked'], 1);
    expect(back['recipe_json'], '{"title":"Rajma Masala"}');
    expect(SyncSchema.byCollection('mealPlan')!.table, 'meal_plan_entries');
  });

  test('every collection is in the schema once', () {
    expect(SyncSchema.collections, <String>[
      'categories',
      'items',
      'shoppingLists',
      'batches',
      'entries',
      'logs',
      'recipes',
      'mealPlan',
      'trips',
      'takeaways',
    ]);
    for (final String collection in SyncSchema.collections) {
      expect(SyncSchema.byCollection(collection), isNotNull);
    }
  });
}
