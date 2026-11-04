/// One change another household member made, as far as an alert needs.
final class RemoteChange {
  const RemoteChange({
    required this.collection,
    required this.userId,
    required this.removed,
    this.listName,
  });

  /// `entries` (shopping list entries) or `batches` (stock added).
  final String collection;

  /// Who made the change.
  final String userId;

  /// True when the document was deleted rather than added.
  final bool removed;

  /// For entries: the name of the list they are on.
  final String? listName;
}

/// Alert lines for a household's changes, such as
/// "Priya added 3 items to Weekly list". English only.
abstract final class ChangeDigest {
  /// Lines about the shopping lists (entries added or removed).
  static List<String> shoppingLines(
    List<RemoteChange> changes,
    Map<String, String> names,
  ) {
    return _lines(
      changes.where((RemoteChange c) => c.collection == 'entries').toList(),
      names,
      (String who, int n, bool removed, String? list) {
        final String place = list ?? 'the shopping list';
        return removed
            ? '$who removed ${_items(n)} from $place'
            : '$who added ${_items(n)} to $place';
      },
    );
  }

  /// Lines about the pantry (stock added).
  static List<String> pantryLines(
    List<RemoteChange> changes,
    Map<String, String> names,
  ) {
    return _lines(
      changes.where((RemoteChange c) => c.collection == 'batches').toList(),
      names,
      (String who, int n, bool removed, String? list) {
        return removed
            ? '$who removed stock of ${_items(n)}'
            : '$who added stock of ${_items(n)}';
      },
    );
  }

  static List<String> _lines(
    List<RemoteChange> changes,
    Map<String, String> names,
    String Function(String who, int count, bool removed, String? list) render,
  ) {
    // Keep first-seen order so the text is stable.
    final Map<String, int> counts = <String, int>{};
    final Map<String, RemoteChange> first = <String, RemoteChange>{};
    for (final RemoteChange change in changes) {
      final String key =
          '${change.userId}|${change.removed}|${change.listName ?? ''}';
      counts[key] = (counts[key] ?? 0) + 1;
      first.putIfAbsent(key, () => change);
    }
    final List<String> lines = <String>[];
    for (final MapEntry<String, int> entry in counts.entries) {
      final RemoteChange change = first[entry.key]!;
      final String who = names[change.userId] ?? 'Someone';
      lines.add(render(who, entry.value, change.removed, change.listName));
    }
    return lines;
  }

  static String _items(int n) => n == 1 ? '1 item' : '$n items';
}
