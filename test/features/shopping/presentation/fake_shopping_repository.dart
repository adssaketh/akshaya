import 'dart:async';

import 'package:akshaya/core/share/share_service.dart';
import 'package:akshaya/features/shopping/domain/shopping_entities.dart';
import 'package:akshaya/features/shopping/domain/shopping_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../domain/shopping_test_data.dart';

/// In-memory repository for widget tests. Streams re-emit on every change, so
/// screens update the way they do with the database. Methods the tests do not
/// use throw via [Fake].
class FakeShoppingRepository extends Fake implements ShoppingRepository {
  FakeShoppingRepository({
    List<ShoppingEntry> entries = const <ShoppingEntry>[],
    List<ShoppingList>? lists,
  })  : _entries = List<ShoppingEntry>.of(entries),
        _lists = lists ??
            const <ShoppingList>[
              ShoppingList(id: kDefaultListId, name: 'Weekly', sortOrder: 0),
            ];

  final List<ShoppingEntry> _entries;
  final List<ShoppingList> _lists;
  final StreamController<void> _changes = StreamController<void>.broadcast();

  final List<ShoppingEntryDraft> addedDrafts = <ShoppingEntryDraft>[];
  final List<({String id, bool checked})> checkedCalls =
      <({String id, bool checked})>[];
  final List<String> deletedIds = <String>[];
  final List<String> undeletedIds = <String>[];
  final List<({String listId, List<CheckoutLine> lines, String? store})>
      checkoutCalls =
      <({String listId, List<CheckoutLine> lines, String? store})>[];

  void _emit() => _changes.add(null);

  @override
  Stream<List<ShoppingList>> watchLists() =>
      Stream<List<ShoppingList>>.value(List<ShoppingList>.of(_lists));

  @override
  Stream<List<ShoppingEntry>> watchEntries() async* {
    yield List<ShoppingEntry>.of(_entries);
    yield* _changes.stream.map((_) => List<ShoppingEntry>.of(_entries));
  }

  @override
  Future<ShoppingEntry> addEntry(ShoppingEntryDraft draft) async {
    addedDrafts.add(draft);
    final ShoppingEntry entry = makeEntry(
      id: 'new-${addedDrafts.length}',
      listId: draft.listId,
      itemId: draft.itemId,
      name: draft.name,
      quantity: draft.quantity,
      unit: draft.unit,
      reason: draft.addedReason,
      priority: draft.priority,
      notes: draft.notes,
      recurrence: draft.recurrence,
    );
    _entries.add(entry);
    _emit();
    return entry;
  }

  @override
  Future<int> addEntries(List<ShoppingEntryDraft> drafts) async {
    for (final ShoppingEntryDraft d in drafts) {
      await addEntry(d);
    }
    return drafts.length;
  }

  @override
  Future<void> setChecked(String entryId, {required bool checked}) async {
    checkedCalls.add((id: entryId, checked: checked));
    final int i = _entries.indexWhere((ShoppingEntry e) => e.id == entryId);
    if (i >= 0) {
      _entries[i] = _entries[i].copyWith(isChecked: checked);
      _emit();
    }
  }

  @override
  Future<void> deleteEntry(String entryId) async {
    deletedIds.add(entryId);
    _entries.removeWhere((ShoppingEntry e) => e.id == entryId);
    _emit();
  }

  @override
  Future<void> undoDeleteEntry(String entryId) async {
    undeletedIds.add(entryId);
  }

  @override
  Future<CheckoutResult> completeShopping({
    required String listId,
    required List<CheckoutLine> lines,
    String? store,
  }) async {
    checkoutCalls.add((listId: listId, lines: lines, store: store));
    return CheckoutResult(
      batchIds: <String>[for (final CheckoutLine l in lines) 'batch-${l.entryId}'],
      previousEntries: const <ShoppingEntry>[],
      createdItemIds: const <String>[],
    );
  }
}

/// Records what would have been shared.
class FakeShareService implements ShareService {
  final List<({String text, String? subject})> shared =
      <({String text, String? subject})>[];

  @override
  Future<void> shareText(String text, {String? subject}) async {
    shared.add((text: text, subject: subject));
  }
}
