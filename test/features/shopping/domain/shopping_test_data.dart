import 'package:akshaya/features/pantry/domain/default_categories.dart';
import 'package:akshaya/features/pantry/domain/entities.dart';
import 'package:akshaya/features/pantry/domain/unit.dart';
import 'package:akshaya/features/shopping/domain/shopping_entities.dart';
import 'package:akshaya/features/shopping/domain/shopping_enums.dart';

import '../../pantry/domain/test_data.dart';

ShoppingEntry makeEntry({
  String id = 'e1',
  String listId = kDefaultListId,
  String? itemId,
  String name = 'Rice',
  double quantity = 1,
  Unit unit = Unit.kg,
  bool checked = false,
  AddedReason reason = AddedReason.manual,
  ShoppingPriority priority = ShoppingPriority.normal,
  String? notes,
  Recurrence recurrence = Recurrence.none,
  DateTime? dueOn,
  int? repeatEveryDays,
}) {
  return ShoppingEntry(
    id: id,
    listId: listId,
    itemId: itemId,
    name: name,
    quantity: quantity,
    unit: unit,
    isChecked: checked,
    addedReason: reason,
    priority: priority,
    notes: notes,
    recurrence: recurrence,
    dueOn: dueOn,
    repeatEveryDays: repeatEveryDays,
    createdAt: kToday,
    updatedAt: kToday,
  );
}

final List<Category> testCategories = <Category>[
  for (int i = 0; i < kDefaultCategories.length; i++)
    Category(
      id: kDefaultCategories[i].id,
      name: kDefaultCategories[i].name,
      iconKey: kDefaultCategories[i].iconKey,
      sortOrder: i,
    ),
];
