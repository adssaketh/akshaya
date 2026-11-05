import 'package:akshaya/features/guide/domain/guide_content.dart';
import 'package:akshaya/features/guide/domain/guide_models.dart';
import 'package:akshaya/features/guide/domain/guide_search.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final GuideSearch search = GuideSearch(kGuideTopics);

  List<String> ids(String query) =>
      <String>[for (final GuideTopic t in search.search(query)) t.id];

  group('stemming and tokens', () {
    test('expiring, expires and expired meet', () {
      final String stem = guideStem('expiring');
      expect(guideStem('expires'), stem);
      expect(guideStem('expired'), stem);
      expect(guideStem('expire'), stem);
    });

    test('scanning meets scan, recipes meets recipe, wasted meets waste', () {
      expect(guideStem('scanning'), guideStem('scan'));
      expect(guideStem('recipes'), guideStem('recipe'));
      expect(guideStem('wasted'), guideStem('waste'));
    });

    test('guideTokens lower-cases and drops punctuation', () {
      expect(guideTokens('Hello,  World!'), <String>['hello', 'world']);
      expect(guideTokens('  '), isEmpty);
    });
  });

  group('search', () {
    test('an empty query returns every topic in guide order', () {
      expect(ids(''), <String>[for (final GuideTopic t in kGuideTopics) t.id]);
      expect(ids('   ').length, kGuideTopics.length);
    });

    test('barcode finds the scan page first', () {
      expect(ids('barcode').first, 'scan-barcode');
      expect(ids('scanning'), contains('scan-barcode'));
    });

    test('mic finds the voice page first', () {
      expect(ids('mic').first, 'voice-command');
    });

    test('whatsapp finds the share page first', () {
      expect(ids('whatsapp').first, 'share-list');
    });

    test('a question is searched by its meaningful words', () {
      expect(ids('how do I share my list').first, 'share-list');
    });

    test('language words find both the names and the voice pages', () {
      final List<String> found = ids('telugu');
      expect(found, contains('other-names'));
      expect(found, contains('voice-command'));
    });

    test('freeze finds the freezing rules', () {
      expect(ids('freeze').first, 'freeze-rules');
    });

    test('dark mode finds the appearance page', () {
      expect(ids('dark mode'), contains('appearance'));
    });

    test('expiry words find the alert and status pages', () {
      final List<String> found = ids('expiring');
      expect(found, contains('daily-alert'));
      expect(found, contains('status-chips'));
    });

    test('expiry finds the pages about expiring food', () {
      final List<String> found = ids('expiry');
      expect(found, contains('daily-alert'));
      expect(found, contains('status-chips'));
      expect(found, contains('food-rescue'));
    });

    test('a word nobody uses finds nothing', () {
      expect(ids('xyzzyqq'), isEmpty);
    });

    test('when no topic has every word, topics with some words are shown', () {
      final List<String> found = ids('barcode xyzzyqq');
      expect(found, contains('scan-barcode'));
    });

    test('filler words alone do not crash', () {
      expect(() => search.search('how to'), returnsNormally);
    });

    test('searching is not case sensitive', () {
      expect(ids('BARCODE'), ids('barcode'));
    });
  });
}
