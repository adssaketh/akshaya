import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/util/date_only.dart';
import '../../pantry/data/database/app_database.dart';
import '../domain/food_estimate.dart';
import '../domain/takeaway_models.dart';
import '../domain/takeaway_repository.dart';
import '../../../core/util/distinct_rows.dart';

/// [TakeawayRepository] backed by the local Drift database.
///
/// Like the other repositories, every write marks the row `pending` for sync
/// (a database trigger does this for edits) and deletes are soft.
class DriftTakeawayRepository implements TakeawayRepository {
  DriftTakeawayRepository(
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

  TakeawayMeal? _meal(TakeawayRow row) {
    if (row.name.trim().isEmpty ||
        !row.portions.isFinite ||
        row.portions <= 0) {
      // Damaged data (for example from a bad import) is skipped, never shown
      // half-broken.
      return null;
    }
    return TakeawayMeal(
      id: row.id,
      name: row.name,
      meal: MealSlot.fromName(row.meal),
      portions: row.portions,
      eatenOn: dateOnly(row.eatenOn),
      price: row.price,
      estimate: FoodEstimate.decode(row.estimateJson),
    );
  }

  @override
  Stream<List<TakeawayMeal>> watchAll() {
    final SimpleSelectStatement<$TakeawayMealsTable, TakeawayRow> query =
        _db.select(_db.takeawayMeals)..where((t) => t.isDeleted.equals(false));
    return query.watch().distinctRows().map((List<TakeawayRow> rows) {
      final List<TakeawayMeal> out = <TakeawayMeal>[];
      for (final TakeawayRow row in rows) {
        final TakeawayMeal? meal = _meal(row);
        if (meal != null) {
          out.add(meal);
        }
      }
      out.sort((TakeawayMeal a, TakeawayMeal b) {
        final int byDay = b.eatenOn.compareTo(a.eatenOn);
        if (byDay != 0) {
          return byDay;
        }
        return b.meal.index.compareTo(a.meal.index);
      });
      return out;
    });
  }

  @override
  Future<List<TakeawayMeal>> readAll() => watchAll().first;

  @override
  Future<TakeawayMeal> add(TakeawayDraft draft) async {
    final String problem = validateTakeaway(
          name: draft.name,
          portions: draft.portions,
          price: draft.price,
        ) ??
        '';
    if (problem.isNotEmpty) {
      throw ArgumentError(problem);
    }
    final DateTime now = _clock();
    final String id = _newId();
    final DateTime day = dateOnly(draft.eatenOn);
    await _db.into(_db.takeawayMeals).insert(
          TakeawayMealsCompanion.insert(
            id: id,
            createdAt: now,
            updatedAt: now,
            updatedBy: Value<String?>(_userId),
            name: draft.name.trim(),
            meal: Value<String>(draft.meal.name),
            portions: Value<double>(draft.portions),
            eatenOn: day,
            price: Value<double?>(draft.price),
            estimateJson: Value<String?>(draft.estimate?.encode()),
          ),
        );
    return TakeawayMeal(
      id: id,
      name: draft.name.trim(),
      meal: draft.meal,
      portions: draft.portions,
      eatenOn: day,
      price: draft.price,
      estimate: draft.estimate,
    );
  }

  @override
  Future<void> update(TakeawayMeal meal) async {
    final String problem = validateTakeaway(
          name: meal.name,
          portions: meal.portions,
          price: meal.price,
        ) ??
        '';
    if (problem.isNotEmpty) {
      throw ArgumentError(problem);
    }
    await (_db.update(_db.takeawayMeals)..where((t) => t.id.equals(meal.id)))
        .write(
      TakeawayMealsCompanion(
        name: Value<String>(meal.name.trim()),
        meal: Value<String>(meal.meal.name),
        portions: Value<double>(meal.portions),
        eatenOn: Value<DateTime>(dateOnly(meal.eatenOn)),
        price: Value<double?>(meal.price),
        estimateJson: Value<String?>(meal.estimate?.encode()),
        isDeleted: const Value<bool>(false),
        updatedAt: Value<DateTime>(_clock()),
        updatedBy: Value<String?>(_userId),
      ),
    );
  }

  @override
  Future<void> setEstimate(String id, FoodEstimate estimate) async {
    await (_db.update(_db.takeawayMeals)..where((t) => t.id.equals(id))).write(
      TakeawayMealsCompanion(
        estimateJson: Value<String?>(estimate.encode()),
        updatedAt: Value<DateTime>(_clock()),
        updatedBy: Value<String?>(_userId),
      ),
    );
  }

  @override
  Future<void> delete(String id) => _setDeleted(id, deleted: true);

  @override
  Future<void> undoDelete(String id) => _setDeleted(id, deleted: false);

  Future<void> _setDeleted(String id, {required bool deleted}) async {
    await (_db.update(_db.takeawayMeals)..where((t) => t.id.equals(id))).write(
      TakeawayMealsCompanion(
        isDeleted: Value<bool>(deleted),
        updatedAt: Value<DateTime>(_clock()),
        updatedBy: Value<String?>(_userId),
      ),
    );
  }
}
