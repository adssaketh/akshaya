import 'shopping_entities.dart';
import 'shopping_enums.dart';
import 'shopping_view.dart';

/// Plain-text version of a list for WhatsApp and similar apps.
abstract final class ShoppingShare {
  /// The entries still to buy, by category, with the list name in bold
  /// (`*Weekly*` renders bold in WhatsApp). Returns an empty string when there
  /// is nothing to buy.
  static String build({
    required String listName,
    required ShoppingListView view,
  }) {
    if (view.sections.isEmpty) {
      return '';
    }
    final StringBuffer out = StringBuffer('*$listName*');
    for (final ShoppingSection section in view.sections) {
      out
        ..writeln()
        ..writeln()
        ..write('*${section.title}*');
      for (final ShoppingEntry e in section.entries) {
        out
          ..writeln()
          ..write('• ${e.name} — ${e.quantityLabel}');
        if (e.priority == ShoppingPriority.high) {
          out.write(' (urgent)');
        }
        final String? note = e.notes;
        if (note != null && note.trim().isNotEmpty) {
          out.write(' · ${note.trim()}');
        }
      }
    }
    return out.toString();
  }
}
