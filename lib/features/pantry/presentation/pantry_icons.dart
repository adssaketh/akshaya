import 'package:flutter/material.dart';

import '../domain/storage_location.dart';

/// Icon for a category's `iconKey`. Unknown keys fall back to a generic icon.
IconData categoryIcon(String? iconKey) {
  switch (iconKey) {
    case 'vegetables':
      return Icons.eco_rounded;
    case 'fruits':
      return Icons.apple_rounded;
    case 'dairy':
      return Icons.local_drink_rounded;
    case 'grains':
      return Icons.grain_rounded;
    case 'dals':
      return Icons.blur_on_rounded;
    case 'spices':
      return Icons.local_fire_department_rounded;
    case 'oils':
      return Icons.opacity_rounded;
    case 'snacks':
      return Icons.fastfood_rounded;
    case 'beverages':
      return Icons.coffee_rounded;
    case 'bakery':
      return Icons.bakery_dining_rounded;
    case 'frozen':
      return Icons.ac_unit_rounded;
    case 'meat':
      return Icons.set_meal_rounded;
    case 'cleaning':
      return Icons.cleaning_services_rounded;
    case 'personal_care':
      return Icons.spa_rounded;
    default:
      return Icons.category_rounded;
  }
}

/// Icon for a storage location.
IconData locationIcon(StorageLocation location) {
  switch (location) {
    case StorageLocation.fridge:
      return Icons.kitchen_rounded;
    case StorageLocation.freezer:
      return Icons.ac_unit_rounded;
    case StorageLocation.pantry:
      return Icons.inventory_2_rounded;
    case StorageLocation.other:
      return Icons.category_rounded;
  }
}
