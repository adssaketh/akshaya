#!/usr/bin/env python3
"""Generates the offline dictionary and the parser word tables.

Run from anywhere:  python3 tool/offline_words/generate.py
Needs:              pip install regex

Reads  tool/offline_words/dictionary_source.txt and tables.py
Writes assets/dictionary/grocery_dictionary.json
       lib/features/commands/domain/parser_words.dart
"""
import json
import os
from dataclasses import dataclass

from tables import NUMBER_WORDS, UNIT_WORDS, INTENT_WORDS, SEPARATOR_WORDS, STOP_WORDS

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
JSON_OUT = os.path.join(ROOT, 'assets', 'dictionary', 'grocery_dictionary.json')
DART_OUT = os.path.join(ROOT, 'lib', 'features', 'commands', 'domain', 'parser_words.dart')


@dataclass
class DictEntry:
    en: str
    category: str
    unit: str
    forms: list


def load_dictionary(path):
    entries = []
    for line in open(path, encoding='utf-8'):
        line = line.strip()
        if not line or line.startswith('#'):
            continue
        en, cat, unit, forms = [p.strip() for p in line.split('|')]
        entries.append(DictEntry(en, cat, unit, [f.strip() for f in forms.split(',') if f.strip()]))
    return entries


# ---- JSON asset
entries = load_dictionary(os.path.join(HERE, 'dictionary_source.txt'))
lines = ['{',
         '  "version": 1,',
         '  "note": "Offline grocery dictionary: English name, default category id, usual unit, and the words people use for it in English, Telugu and Hindi (native script and romanised). Add new words here; see tool/offline_words/README.md.",',
         '  "items": [']
for i, e in enumerate(entries):
    forms = []
    seen = set()
    for f in e.forms:
        if f not in seen:
            seen.add(f); forms.append(f)
    obj = {'en': e.en, 'category': e.category, 'unit': e.unit, 'forms': forms}
    lines.append('    ' + json.dumps(obj, ensure_ascii=False) + (',' if i < len(entries) - 1 else ''))
lines += ['  ]', '}', '']
open(JSON_OUT, 'w', encoding='utf-8').write('\n'.join(lines))
json.load(open(JSON_OUT, encoding='utf-8'))

# ---- Dart tables
def q(s):
    assert "'" not in s and '$' not in s and '\\' not in s, s
    return "'" + s + "'"

unit_enum = {'kg': 'Unit.kg', 'g': 'Unit.g', 'l': 'Unit.l', 'ml': 'Unit.ml', 'packet': 'Unit.packet',
             'dozen': 'Unit.dozen', 'pcs': 'Unit.pcs', 'bunch': 'Unit.bunch'}
out = []
out.append("""// GENERATED from tool/offline_words (see PROGRESS.md). Words are already
// normalised with `normalizeText` (lower case, no nukta, ASCII digits), so
// they can be looked up directly. Edit the generator, not this file.

import '../../pantry/domain/unit.dart';

/// What a word in a spoken or typed command means, apart from items, numbers
/// and units.
enum IntentWord {
  /// "add", "put", "veyyi", "daalo": add something (where is decided by the
  /// other words and the screen).
  add,

  /// "need", "kavali", "chahiye": something to buy, so the shopping list.
  need,

  /// "bought", "konnanu", "kharida": something that is now in the pantry.
  bought,

  /// "used", "vaadesanu", "istemal": some was taken from the pantry.
  use,

  /// "finished", "ayipoyindi", "khatam": none is left.
  finished,

  /// "remove", "teeseyyi", "hatao": take it off the shopping list.
  remove,

  /// "expiring", "expired": asks what is about to go off.
  queryExpiring,

  /// "how much", "kitna", "entha": asks how much is left.
  queryStock,

  /// "list", "shopping": names the shopping list.
  list,
}
""")
out.append("/// Number words in English, Telugu and Hindi (script and romanised).\nconst Map<String, double> kNumberWords = <String, double>{")
for k, v in NUMBER_WORDS.items():
    out.append(f"  {q(k)}: {float(v)!r},")
out.append("};\n")
out.append("/// Unit words.\nconst Map<String, Unit> kUnitWords = <String, Unit>{")
for k, v in UNIT_WORDS.items():
    out.append(f"  {q(k)}: {unit_enum[v]},")
out.append("};\n")
out.append("/// Intent words.\nconst Map<String, IntentWord> kIntentWords = <String, IntentWord>{")
for k, v in INTENT_WORDS.items():
    out.append(f"  {q(k)}: IntentWord.{v},")
out.append("};\n")
out.append("/// Words that join two items or two commands (\"and\", \"aur\", \"mariyu\").\nconst Set<String> kSeparatorWords = <String>{")
for k in sorted(SEPARATOR_WORDS):
    out.append(f"  {q(k)},")
out.append("};\n")
out.append("/// Filler words that carry no meaning for the parser.\nconst Set<String> kStopWords = <String>{")
for k in sorted(STOP_WORDS):
    out.append(f"  {q(k)},")
out.append("};\n")
open(DART_OUT, 'w', encoding='utf-8').write('\n'.join(out))
print('items', len(entries), 'number', len(NUMBER_WORDS), 'unit', len(UNIT_WORDS), 'intent', len(INTENT_WORDS), 'stop', len(STOP_WORDS))
