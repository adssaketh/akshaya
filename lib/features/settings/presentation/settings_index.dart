import 'package:flutter/widgets.dart';

/// One block of the Settings tab, with the words people might search for.
final class SettingsEntry {
  const SettingsEntry({
    required this.id,
    required this.title,
    required this.keywords,
    required this.builder,
  });

  final String id;
  final String title;

  /// Lower-case words that should find this block (setting names, synonyms).
  final String keywords;
  final WidgetBuilder builder;

  /// True when every word typed appears in the title or the keywords.
  bool matches(List<String> words) {
    final String haystack = '${title.toLowerCase()} $keywords';
    for (final String word in words) {
      if (!haystack.contains(word)) {
        return false;
      }
    }
    return true;
  }
}

/// The blocks that match [query] (all of them when it is empty). Words are
/// matched anywhere in a block's title or keywords, in any order.
List<SettingsEntry> filterSettingsEntries(
  List<SettingsEntry> entries,
  String query,
) {
  final List<String> words = query
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((String w) => w.isNotEmpty)
      .toList();
  if (words.isEmpty) {
    return entries;
  }
  return <SettingsEntry>[
    for (final SettingsEntry e in entries)
      if (e.matches(words)) e,
  ];
}
