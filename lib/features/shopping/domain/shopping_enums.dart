import '../../../core/util/date_only.dart';

/// How often a shopping entry comes back after it has been bought. The enum
/// [name] is stored in the database, so never rename a value without a
/// migration.
enum Recurrence {
  none('Does not repeat'),
  daily('Every day'),
  weekly('Every week'),
  monthly('Every month');

  const Recurrence(this.label);

  final String label;

  bool get repeats => this != Recurrence.none;

  /// The date an entry bought on [from] is due again. Monthly clamps to the
  /// last day of a shorter month (31 Jan becomes 28 Feb).
  DateTime nextDue(DateTime from) {
    switch (this) {
      case Recurrence.none:
        return dateOnly(from);
      case Recurrence.daily:
        return addDays(from, 1);
      case Recurrence.weekly:
        return addDays(from, 7);
      case Recurrence.monthly:
        return addMonths(from, 1);
    }
  }
}

/// Why an entry is on the list. The enum [name] is stored in the database.
enum AddedReason {
  manual('Added by you'),
  voice('Added by voice'),
  lowStock('Low stock'),
  expired('Expired'),
  recurring('Repeats'),
  recipe('For a recipe');

  const AddedReason(this.label);

  final String label;
}

/// How soon an entry is needed. The enum [name] is stored in the database.
enum ShoppingPriority {
  normal('Normal'),
  high('Urgent');

  const ShoppingPriority(this.label);

  final String label;
}
