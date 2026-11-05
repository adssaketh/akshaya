import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/util/date_only.dart';
import '../../pantry/data/database/app_database.dart';
import '../../recipes/domain/recipe_models.dart';
import '../domain/meal_plan_models.dart';
import '../domain/meal_plan_repository.dart';
import '../domain/meal_slot.dart';

/// [MealPlanRepository] backed by the local Drift database.
///
/// Like the other repositories, every write marks the row `pending` for sync
/// (a database trigger does this for edits) and deletes are soft.
///
/// The plan is small (a few meals a day), so days are filtered in Dart rather
/// than in SQL.
class DriftMealPlanRepository implements MealPlanRepository {
  DriftMealPlanRepository(
    this._db, {
    DateTime Function()? clock,
    String Function()? idGenerator,
    String? currentUserId,
  })  : _clock = clock ?? DateTime.now,
        _newId = idGenerator ?? _uuidV4,
        _userId = currentUserId;

  final AppDatabase _db;
  final DateTime Function() _clock;
  final String Function() _newId;
  final String? _userId;

  static String _uuidV4() => const Uuid().v4();

  MealPlanEntry? _entry(MealPlanRow row) {
    final MealSlot? slot = MealSlot.fromKey(row.slot);
    if (slot == null || row.title.trim().isEmpty) {
      // Unknown or damaged data is skipped, never shown half-broken.
      return null;
    }
    return MealPlanEntry(
      id: row.id,
      date: row.planDate,
      slot: slot,
      title: row.title,
      recipe: MealPlanEntry.decodeRecipe(row.recipeJson),
      leftoverItemId: row.leftoverItemId,
      isCooked: row.isCooked,
      prep: PrepReminder.decodeList(row.prepJson),
    );
  }

  Stream<List<MealPlanEntry>> _watchLive() {
    final SimpleSelectStatement<$MealPlanEntriesTable, MealPlanRow> query =
        _db.select(_db.mealPlanEntries)..where((t) => t.isDeleted.equals(false));
    return query.watch().map((List<MealPlanRow> rows) {
      final List<MealPlanEntry> out = <MealPlanEntry>[];
      for (final MealPlanRow row in rows) {
        final MealPlanEntry? entry = _entry(row);
        if (entry != null) {
          out.add(entry);
        }
      }
      out.sort(_byDayAndSlot);
      return out;
    });
  }

  static int _byDayAndSlot(MealPlanEntry a, MealPlanEntry b) {
    final int byDay = a.date.compareTo(b.date);
    return byDay != 0 ? byDay : a.slot.index.compareTo(b.slot.index);
  }

  @override
  Stream<List<MealPlanEntry>> watchBetween(DateTime from, DateTime to) {
    final DateTime start = dateOnly(from);
    final DateTime end = dateOnly(to);
    return _watchLive().map(
      (List<MealPlanEntry> all) => <MealPlanEntry>[
        for (final MealPlanEntry e in all)
          if (!e.date.isBefore(start) && !e.date.isAfter(end)) e,
      ],
    );
  }

  @override
  Stream<List<MealPlanEntry>> watchFrom(DateTime from) {
    final DateTime start = dateOnly(from);
    return _watchLive().map(
      (List<MealPlanEntry> all) => <MealPlanEntry>[
        for (final MealPlanEntry e in all)
          if (!e.date.isBefore(start)) e,
      ],
    );
  }

  @override
  Future<List<MealPlanEntry>> readFrom(DateTime from) => watchFrom(from).first;

  @override
  Future<MealPlanEntry> put(MealPlanDraft draft) {
    return _db.transaction<MealPlanEntry>(() => _put(draft));
  }

  @override
  Future<List<MealPlanEntry>> putAll(List<MealPlanDraft> drafts) {
    return _db.transaction<List<MealPlanEntry>>(() async {
      final List<MealPlanEntry> out = <MealPlanEntry>[];
      for (final MealPlanDraft draft in drafts) {
        out.add(await _put(draft));
      }
      return out;
    });
  }

  Future<MealPlanEntry> _put(MealPlanDraft draft) async {
    final DateTime day = dateOnly(draft.date);
    final List<MealPlanRow> rows = await (_db.select(_db.mealPlanEntries)
          ..where((t) => t.isDeleted.equals(false)))
        .get();
    MealPlanRow? same;
    for (final MealPlanRow row in rows) {
      if (row.slot == draft.slot.key && dateOnly(row.planDate) == day) {
        same = row;
        break;
      }
    }
    final DateTime now = _clock();
    if (same != null) {
      final MealPlanEntry replaced = MealPlanEntry(
        id: same.id,
        date: day,
        slot: draft.slot,
        title: draft.title,
        recipe: draft.recipe,
        leftoverItemId: draft.leftoverItemId,
        prep: draft.prep,
      );
      await _write(replaced, now);
      return replaced;
    }
    final String id = _newId();
    await _db.into(_db.mealPlanEntries).insert(
          MealPlanEntriesCompanion.insert(
            id: id,
            createdAt: now,
            updatedAt: now,
            updatedBy: Value<String?>(_userId),
            planDate: day,
            slot: draft.slot.key,
            title: draft.title,
            recipeJson: Value<String?>(_recipeJson(draft.recipe)),
            leftoverItemId: Value<String?>(draft.leftoverItemId),
            prepJson: Value<String?>(PrepReminder.encodeList(draft.prep)),
          ),
        );
    return MealPlanEntry(
      id: id,
      date: day,
      slot: draft.slot,
      title: draft.title,
      recipe: draft.recipe,
      leftoverItemId: draft.leftoverItemId,
      prep: draft.prep,
    );
  }

  @override
  Future<void> update(MealPlanEntry entry) => _write(entry, _clock());

  Future<void> _write(MealPlanEntry entry, DateTime now) async {
    await (_db.update(_db.mealPlanEntries)..where((t) => t.id.equals(entry.id)))
        .write(
      MealPlanEntriesCompanion(
        planDate: Value<DateTime>(dateOnly(entry.date)),
        slot: Value<String>(entry.slot.key),
        title: Value<String>(entry.title),
        recipeJson: Value<String?>(_recipeJson(entry.recipe)),
        leftoverItemId: Value<String?>(entry.leftoverItemId),
        isCooked: Value<bool>(entry.isCooked),
        prepJson: Value<String?>(PrepReminder.encodeList(entry.prep)),
        isDeleted: const Value<bool>(false),
        updatedAt: Value<DateTime>(now),
        updatedBy: Value<String?>(_userId),
      ),
    );
  }

  static String? _recipeJson(Recipe? recipe) {
    return recipe == null ? null : MealPlanEntry.encodeRecipe(recipe);
  }

  @override
  Future<void> delete(String id) => _setDeleted(<String>[id], deleted: true);

  @override
  Future<void> undoDelete(String id) =>
      _setDeleted(<String>[id], deleted: false);

  @override
  Future<void> deleteMany(List<String> ids) =>
      _setDeleted(ids, deleted: true);

  @override
  Future<void> undoDeleteMany(List<String> ids) =>
      _setDeleted(ids, deleted: false);

  Future<void> _setDeleted(List<String> ids, {required bool deleted}) async {
    if (ids.isEmpty) {
      return;
    }
    final DateTime now = _clock();
    await _db.transaction(() async {
      for (final String id in ids) {
        await (_db.update(_db.mealPlanEntries)..where((t) => t.id.equals(id)))
            .write(
          MealPlanEntriesCompanion(
            isDeleted: Value<bool>(deleted),
            updatedAt: Value<DateTime>(now),
            updatedBy: Value<String?>(_userId),
          ),
        );
      }
    });
  }
}
