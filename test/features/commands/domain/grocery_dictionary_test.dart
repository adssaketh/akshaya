import 'package:akshaya/features/commands/domain/grocery_dictionary.dart';
import 'package:akshaya/features/commands/domain/text_normalizer.dart';
import 'package:akshaya/features/pantry/domain/default_categories.dart';
import 'package:flutter_test/flutter_test.dart';

import 'command_test_support.dart';

void main() {
  final GroceryDictionary dictionary = loadDictionary();

  test('is big enough and every entry is complete', () {
    expect(dictionary.entries.length, greaterThanOrEqualTo(100));
    final int forms = dictionary.entries
        .fold<int>(0, (int sum, DictionaryEntry e) => sum + e.forms.length);
    expect(forms, greaterThanOrEqualTo(300));
    for (final DictionaryEntry e in dictionary.entries) {
      expect(e.name.trim(), isNotEmpty);
      expect(e.forms, isNotEmpty, reason: e.name);
    }
  });

  test('every category exists', () {
    final Set<String> ids = <String>{
      for (final DefaultCategory c in kDefaultCategories) c.id,
    };
    for (final DictionaryEntry e in dictionary.entries) {
      expect(ids, contains(e.categoryId), reason: e.name);
    }
  });

  test('no word means two different products', () {
    final Map<String, String> owner = <String, String>{};
    for (final DictionaryEntry e in dictionary.entries) {
      for (final String form in <String>[e.name, ...e.forms]) {
        final String key = phraseTokens(form).join(' ');
        final String? existing = owner[key];
        expect(
          existing == null || existing == e.name,
          isTrue,
          reason: '"$form" is used by both $existing and ${e.name}',
        );
        owner[key] = e.name;
      }
    }
  });

  test('spec words are present in all three languages', () {
    final Map<String, String> expected = <String, String>{
      'ullipaya': 'Onion',
      'pyaaz': 'Onion',
      'kandi pappu': 'Toor Dal',
      'toor dal': 'Toor Dal',
      'arhar': 'Toor Dal',
      'ravva': 'Semolina (Rava)',
      'suji': 'Semolina (Rava)',
      'rava': 'Semolina (Rava)',
      'pallilu': 'Peanuts',
      'moongphali': 'Peanuts',
      'perugu': 'Curd',
      'dahi': 'Curd',
      'biyyam': 'Rice',
      'chawal': 'Rice',
      'బియ్యం': 'Rice',
      'चावल': 'Rice',
    };
    final lexicon = buildParser().lexicon;
    expected.forEach((String word, String english) {
      expect(lexicon.lookupPhrase(word)?.name, english, reason: word);
    });
  });

  test('a broken file gives an empty dictionary, not a crash', () {
    expect(GroceryDictionary.fromJson('{"items": 3}').entries, isEmpty);
    expect(
      GroceryDictionary.fromJson('{"items":[{"en":"X"},7]}').entries,
      isEmpty,
    );
  });
}
