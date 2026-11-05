import 'guide_models.dart';

/// Words people type that the guide writes differently. Each key expands to
/// the listed words when searching, so "mic" finds the voice pages and
/// "throw" finds the wasted-food pages.
const Map<String, List<String>> kGuideSynonyms = <String, List<String>>{
  'mic': <String>['voice', 'speak', 'microphone'],
  'microphone': <String>['voice', 'speak'],
  'speak': <String>['voice'],
  'say': <String>['voice'],
  'talk': <String>['voice'],
  'telugu': <String>['voice', 'other', 'names'],
  'hindi': <String>['voice', 'other', 'names'],
  'language': <String>['voice', 'names'],
  'expiry': <String>['expire', 'expiring'],
  'expiration': <String>['expire', 'expiring'],
  'date': <String>['expire', 'expiring'],
  'notification': <String>['alert'],
  'notify': <String>['alert'],
  'reminder': <String>['alert', 'prep'],
  'remind': <String>['alert'],
  'delete': <String>['remove'],
  'throw': <String>['waste', 'wasted'],
  'bin': <String>['waste', 'wasted'],
  'rot': <String>['waste', 'expired'],
  'spoil': <String>['waste', 'expired'],
  'barcode': <String>['scan'],
  'camera': <String>['scan'],
  'qr': <String>['household', 'join', 'scan'],
  'family': <String>['household'],
  'share': <String>['household', 'sync', 'whatsapp'],
  'friends': <String>['household'],
  'money': <String>['price', 'spending', 'cost'],
  'cost': <String>['price', 'spending'],
  'spend': <String>['spending'],
  'budget': <String>['spending'],
  'fridge': <String>['location', 'stored'],
  'dabba': <String>['container'],
  'box': <String>['container'],
  'leftover': <String>['cooked'],
  'leftovers': <String>['cooked'],
  'dark': <String>['theme', 'appearance'],
  'light': <String>['theme', 'appearance'],
  'colour': <String>['theme', 'appearance', 'status'],
  'color': <String>['theme', 'appearance', 'status'],
  'password': <String>['lock', 'sign'],
  'fingerprint': <String>['lock'],
  'login': <String>['sign'],
  'account': <String>['sign'],
  'export': <String>['backup', 'csv'],
  'restore': <String>['backup'],
  'save': <String>['backup'],
  'holiday': <String>['trip', 'travel'],
  'vacation': <String>['trip', 'travel'],
  'away': <String>['trip', 'travel'],
  'meal': <String>['plan', 'recipe'],
  'cook': <String>['recipe', 'cooked'],
  'low': <String>['stock'],
  'finish': <String>['finished'],
  'inventory': <String>['pantry', 'count'],
  'stocktake': <String>['count'],
  'check': <String>['count'],
};

/// Words that carry no meaning in a search ("how do I add ...").
const Set<String> _stopWords = <String>{
  'a',
  'an',
  'the',
  'i',
  'me',
  'my',
  'we',
  'to',
  'do',
  'does',
  'how',
  'what',
  'where',
  'when',
  'can',
  'is',
  'it',
  'in',
  'on',
  'of',
  'for',
  'and',
  'or',
  'with',
  'use',
  'from',
};

/// Lower-case words of [text]: letters and digits only.
List<String> guideTokens(String text) {
  final String cleaned = text
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9¼½]+'), ' ')
      .trim();
  if (cleaned.isEmpty) {
    return const <String>[];
  }
  return cleaned.split(' ');
}

/// A very light stem so "expiring", "expires" and "expired" meet.
String guideStem(String word) {
  String w = word;
  bool cutSuffix = false;
  if (w.length > 5 && w.endsWith('ing')) {
    w = w.substring(0, w.length - 3);
    cutSuffix = true;
  } else if (w.length > 4 && w.endsWith('ed')) {
    w = w.substring(0, w.length - 2);
    cutSuffix = true;
  }
  // "scanning" -> "scann" -> "scan".
  if (cutSuffix &&
      w.length > 3 &&
      w[w.length - 1] == w[w.length - 2] &&
      !w.endsWith('ss') &&
      !w.endsWith('ll')) {
    w = w.substring(0, w.length - 1);
  }
  if (!cutSuffix) {
    if (w.length > 3 && w.endsWith('es')) {
      w = w.substring(0, w.length - 2);
    } else if (w.length > 3 && w.endsWith('s') && !w.endsWith('ss')) {
      w = w.substring(0, w.length - 1);
    }
  }
  // "expire" and "expir" (from expiring) should meet.
  if (w.length > 3 && w.endsWith('e')) {
    w = w.substring(0, w.length - 1);
  }
  return w;
}

/// Keyword search over the guide. Pure and synchronous: it is fast enough to
/// run on every key press.
class GuideSearch {
  GuideSearch(this.topics) : _index = <String, _Indexed>{} {
    for (final GuideTopic topic in topics) {
      _index[topic.id] = _Indexed(topic);
    }
  }

  final List<GuideTopic> topics;
  final Map<String, _Indexed> _index;

  /// Topics matching [query], best first. An empty query returns everything
  /// in guide order. Every word must match somewhere; if no topic matches all
  /// the words, topics matching any word are returned instead.
  List<GuideTopic> search(String query) {
    final List<String> words = <String>[
      for (final String t in guideTokens(query))
        if (!_stopWords.contains(t)) t,
    ];
    if (guideTokens(query).isEmpty) {
      return List<GuideTopic>.of(topics);
    }
    if (words.isEmpty) {
      // Only filler words were typed ("how to"): treat them as real words.
      words.addAll(guideTokens(query));
    }

    final List<List<String>> alternatives = <List<String>>[
      for (final String w in words)
        <String>[
          guideStem(w),
          for (final String s in kGuideSynonyms[w] ?? const <String>[])
            guideStem(s),
        ],
    ];

    final List<_Scored> all = <_Scored>[];
    final List<_Scored> any = <_Scored>[];
    for (int order = 0; order < topics.length; order++) {
      final GuideTopic topic = topics[order];
      final _Indexed doc = _index[topic.id]!;
      int total = 0;
      int matched = 0;
      for (final List<String> alts in alternatives) {
        int best = 0;
        for (int a = 0; a < alts.length; a++) {
          int score = doc.score(alts[a]);
          // A synonym counts for a little less than the word itself.
          if (a > 0) {
            score = (score * 0.7).round();
          }
          if (score > best) {
            best = score;
          }
        }
        if (best > 0) {
          matched++;
          total += best;
        }
      }
      if (matched == 0) {
        continue;
      }
      final _Scored scored = _Scored(topic, total, order);
      any.add(scored);
      if (matched == alternatives.length) {
        all.add(scored);
      }
    }

    final List<_Scored> chosen = all.isNotEmpty ? all : any;
    chosen.sort((_Scored a, _Scored b) {
      final int byScore = b.score.compareTo(a.score);
      return byScore != 0 ? byScore : a.order.compareTo(b.order);
    });
    return <GuideTopic>[for (final _Scored s in chosen) s.topic];
  }
}

class _Scored {
  const _Scored(this.topic, this.score, this.order);

  final GuideTopic topic;
  final int score;
  final int order;
}

/// The searchable words of one topic, grouped by how much they count.
class _Indexed {
  _Indexed(GuideTopic topic)
      : title = _stems(topic.title),
        keywords = _stems(topic.keywords.join(' ')),
        area = _stems('${topic.area.title} ${topic.whereToFind}'),
        body = _stems(
          '${topic.summary} ${topic.steps.join(' ')} ${topic.tips.join(' ')}',
        );

  final Set<String> title;
  final Set<String> keywords;
  final Set<String> area;
  final Set<String> body;

  static Set<String> _stems(String text) => <String>{
        for (final String t in guideTokens(text)) guideStem(t),
      };

  /// How well one (already stemmed) search word matches this topic.
  int score(String word) {
    int best = 0;
    best = _max(best, _field(title, word, exact: 10, prefix: 6));
    best = _max(best, _field(keywords, word, exact: 8, prefix: 5));
    best = _max(best, _field(area, word, exact: 4, prefix: 2));
    best = _max(best, _field(body, word, exact: 3, prefix: 1));
    return best;
  }

  static int _max(int a, int b) => a > b ? a : b;

  static int _field(
    Set<String> words,
    String word, {
    required int exact,
    required int prefix,
  }) {
    if (words.contains(word)) {
      return exact;
    }
    // Prefix matching only for words of two letters or more, so a single
    // typed letter does not match everything.
    if (word.length >= 2) {
      for (final String candidate in words) {
        if (candidate.startsWith(word)) {
          return prefix;
        }
      }
    }
    return 0;
  }
}
