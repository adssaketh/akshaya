import 'package:akshaya/features/commands/domain/text_normalizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeText', () {
    test('lower-cases and folds Devanagari and Telugu digits', () {
      expect(normalizeText('RICE'), 'rice');
      expect(normalizeText('२ ౨'), '2 2');
    });

    test('ignores the nukta, so both spellings of a word match', () {
      expect(normalizeText('प्याज़'), normalizeText('प्याज'));
      expect(normalizeText('ज़'), 'ज');
    });

    test('drops zero-width joiners', () {
      expect(normalizeText('a‍b‌c'), 'abc');
    });
  });

  group('tokenize', () {
    test('splits words, numbers, fractions and separators', () {
      expect(
        tokenize('Add 1.5 kg rice, 1/2 L milk & ½ dozen eggs'),
        <String>['add', '1.5', 'kg', 'rice', ',', '1/2', 'l', 'milk', '&', '½', 'dozen', 'eggs'],
      );
    });

    test('keeps Telugu and Hindi words whole, vowel signs included', () {
      expect(tokenize('రెండు కిలోలు బియ్యం'), <String>['రెండు', 'కిలోలు', 'బియ్యం']);
      expect(tokenize('दो किलो चावल।'), <String>['दो', 'किलो', 'चावल', '।']);
    });

    test('phraseTokens drops separators', () {
      expect(phraseTokens('kandi pappu, toor'), <String>['kandi', 'pappu', 'toor']);
    });
  });

  group('phoneticKey', () {
    test('spelling variants of one word meet', () {
      expect(phoneticKey('biyyam'), phoneticKey('biyam'));
      expect(phoneticKey('biyyamu'), phoneticKey('biyyam'));
      expect(phoneticKey('khatam'), phoneticKey('katam'));
      expect(phoneticKey('zeera'), phoneticKey('jeera'));
      expect(phoneticKey('wheat'), phoneticKey('vheat'));
    });

    test('short words keep their final u', () {
      expect(phoneticKey('guddu'), isNot(phoneticKey('gud')));
    });
  });

  test('titleCase capitalises each word', () {
    expect(titleCase('toor dal'), 'Toor Dal');
    expect(titleCase('xyzzy'), 'Xyzzy');
  });
}
