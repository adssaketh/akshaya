import 'dart:io';

import 'package:akshaya/features/guide/domain/guide_content.dart';
import 'package:akshaya/features/guide/domain/guide_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('guide content', () {
    test('every topic has an unique id and the required text', () {
      final Set<String> ids = <String>{};
      for (final GuideTopic topic in kGuideTopics) {
        expect(ids.add(topic.id), isTrue, reason: 'duplicate id ${topic.id}');
        expect(topic.title.trim(), isNotEmpty, reason: topic.id);
        expect(topic.summary.trim(), isNotEmpty, reason: topic.id);
        expect(topic.whereToFind.trim(), isNotEmpty, reason: topic.id);
        expect(topic.steps, isNotEmpty, reason: topic.id);
        for (final String step in topic.steps) {
          expect(step.trim(), isNotEmpty, reason: topic.id);
        }
      }
    });

    test('related links point at other topics that exist', () {
      for (final GuideTopic topic in kGuideTopics) {
        for (final String id in topic.related) {
          expect(guideTopicById(id), isNotNull,
              reason: '${topic.id} links to missing "$id"');
          expect(id, isNot(topic.id), reason: '${topic.id} links to itself');
        }
      }
    });

    test('every area has at least one topic', () {
      for (final GuideArea area in GuideArea.values) {
        expect(
          kGuideTopics.where((GuideTopic t) => t.area == area),
          isNotEmpty,
          reason: area.title,
        );
      }
    });

    test('every picture is used by at least one topic', () {
      final Set<GuidePreview> used = <GuidePreview>{
        for (final GuideTopic t in kGuideTopics) t.preview,
      };
      for (final GuidePreview preview in GuidePreview.values) {
        expect(used, contains(preview), reason: preview.name);
      }
    });

    test('guideTopicById finds a topic and returns null for unknown ids', () {
      expect(guideTopicById('tabs')?.title, 'The five tabs');
      expect(guideTopicById('no-such-topic'), isNull);
    });

    test('button and screen names in the guide still exist in the app', () {
      // If someone renames one of these in the app, this test fails as a
      // reminder to update the guide.
      const List<String> labels = <String>[
        'Add item',
        'Scan barcode',
        'Done shopping',
        'Share as text',
        'Count mode',
        'Meal plan',
        'Plan my week',
        'Generate shopping list',
        'I cooked this',
        'Add missing',
        'Mark wasted',
        'Freezing rules',
        'Travel mode',
        'Sign in to share with your household',
        'Save a backup',
        'Restore from a backup',
        'Load sample data',
        'Daily alert',
        'Quiet hours',
        'Use AI for hard-to-read commands',
        'What should I buy?',
        'Food rescue',
        'Get recipe ideas',
        'Suggested for you',
        'Cook something',
        'Give away',
        'Add stock',
        'Mark as wasted',
        'Already opened',
        'Essential item',
        'Repeats later',
        'Create household',
        'Sync now',
        'Leave household',
        'New code',
        'Use all',
        'Add all',
        'Keep mine',
        'Add to list',
        'Snooze',
        'Show recipes',
        'Voice add',
        'Understand',
        'Confirm',
        'Change words',
        'Matches',
        'Save preferences',
        'Back home checklist',
        'Wallpaper colours',
        'App lock',
        'Meal prep reminders',
        'Household changes',
        'Remind me on day',
        'Monthly count reminder',
        'Export pantry as CSV',
        'Invite someone',
        'Money saved',
        'Offer Freeze',
        'Add trip',
        'Clear this week',
        'Prep reminders',
        'Ask again anyway',
        'Type the barcode',
      ];
      final StringBuffer source = StringBuffer();
      for (final FileSystemEntity entity
          in Directory('lib').listSync(recursive: true)) {
        if (entity is File &&
            entity.path.endsWith('.dart') &&
            !entity.path.replaceAll(r'\', '/').contains('features/guide/')) {
          source.write(entity.readAsStringSync());
        }
      }
      final String all = source.toString();
      final List<String> missing = <String>[
        for (final String label in labels)
          if (!all.contains(label)) label,
      ];
      expect(missing, isEmpty, reason: 'renamed in the app? $missing');
    });
  });
}
