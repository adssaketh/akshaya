import '../../../core/util/quantity.dart';
import 'recipe_models.dart';
import 'recipe_pantry.dart';

/// A short code for "this pantry and these preferences". When it is the same
/// as the code stored with the last ideas, nothing the AI would look at has
/// changed, so it is not asked again.
///
/// The pantry part is the cookable items with their quantity, unit and
/// expiry date (not the date today, so an unchanged pantry keeps its code from
/// one day to the next; something that expires overnight drops out of the
/// list and so changes it).
abstract final class RecipeFingerprint {
  static String compute(List<PantryLine> lines, RecipePreferences prefs) {
    final List<String> parts = <String>[
      for (final PantryLine line in RecipePantry.stocked(lines))
        '${line.name.toLowerCase()}|${formatNumber(line.usable)}|'
            '${line.unit.symbol}|${_date(line.expiry)}',
    ];
    parts.sort();
    final List<String> avoid = <String>[
      for (final String a in prefs.avoid) a.toLowerCase(),
    ];
    avoid.sort();
    parts.add(
      'prefs|${prefs.diet.key}|${prefs.cuisine.key}|${prefs.maxMinutes}|'
      '${prefs.people}|${avoid.join(',')}',
    );
    return _hash(parts.join('\n'));
  }

  static String _date(DateTime? d) {
    if (d == null) {
      return '';
    }
    final String m = d.month.toString().padLeft(2, '0');
    final String day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  /// Two 32-bit FNV-1a style hashes with different multipliers, written as 16
  /// hex digits. Plenty for telling two pantries apart.
  static String _hash(String text) {
    int a = 0x811C9DC5;
    int b = 0x01234567;
    for (final int unit in text.codeUnits) {
      a = ((a ^ unit) * 0x01000193) & 0xFFFFFFFF;
      b = ((b ^ unit) * 0x2545F491) & 0xFFFFFFFF;
    }
    return a.toRadixString(16).padLeft(8, '0') +
        b.toRadixString(16).padLeft(8, '0');
  }
}
