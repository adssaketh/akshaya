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

  test('every collection is in the schema once', () {
    expect(SyncSchema.collections, <String>[
      'categories',
      'items',
      'shoppingLists',
      'batches',
      'entries',
      'logs',
    ]);
    for (final String collection in SyncSchema.collections) {
      expect(SyncSchema.byCollection(collection), isNotNull);
    }
  });
}
