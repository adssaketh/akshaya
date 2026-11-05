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

  /// Length of one cycle in days (a month counts as 30); 0 when it does not
  /// repeat. Used to compare a built-in repeat with a custom number of days.
  int get approxDays {
    switch (this) {
      case Recurrence.none:
        return 0;
      case Recurrence.daily:
        return 1;
      case Recurrence.weekly:
        return 7;
      case Recurrence.monthly:
        return 30;
    }
  }

  /// The built-in repeat that is closest to "every [days] days". An entry with
  /// a custom number of days stores this one too, so older app versions in the
  /// same household still read a sensible repeat.
  static Recurrence nearestTo(int days) {
    if (days <= 3) {
      return Recurrence.daily;
    }
    if (days <= 18) {
      return Recurrence.weekly;
    }
    return Recurrence.monthly;
  }

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
