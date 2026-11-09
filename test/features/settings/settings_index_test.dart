import 'package:akshaya/features/settings/presentation/settings_index.dart';
import 'package:akshaya/features/settings/settings_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

List<String> _ids(List<SettingsEntry> entries) =>
    <String>[for (final SettingsEntry e in entries) e.id];

void main() {
  final List<SettingsEntry> all = buildSettingsEntries();

  test('an empty search shows every block, in order', () {
    expect(_ids(filterSettingsEntries(all, '')), _ids(all));
    expect(_ids(filterSettingsEntries(all, '   ')), _ids(all));
    expect(
      _ids(all),
      <String>[
        'guide',
        'general',
        'alerts',
        'device',
        'count',
        'freezing',
        'travel',
        'ai',
        'sync',
        'backup',
        'diagnostics',
      ],
    );
  });

  test('block ids are unique', () {
    expect(_ids(all).toSet().length, all.length);
  });

  test('words find the block that holds the setting', () {
    expect(_ids(filterSettingsEntries(all, 'currency')), <String>['general']);
    expect(_ids(filterSettingsEntries(all, 'Quiet Hours')), <String>['alerts']);
    expect(_ids(filterSettingsEntries(all, 'csv')), <String>['backup']);
    expect(_ids(filterSettingsEntries(all, 'gemini')), <String>['ai']);
    expect(_ids(filterSettingsEntries(all, 'trip')), <String>['travel']);
  });

  test('every word must match, in any order', () {
    expect(_ids(filterSettingsEntries(all, 'time alert')), <String>['alerts']);
    expect(filterSettingsEntries(all, 'currency quiet'), isEmpty);
  });

  test('nothing matches nonsense', () {
    expect(filterSettingsEntries(all, 'zzzzz'), isEmpty);
  });

  test('the Sync button search brings up only Household & sync', () {
    expect(
      _ids(filterSettingsEntries(all, kHouseholdSearch)),
      <String>['sync'],
    );
  });

  test('a block can be built without a context-dependent crash on filter', () {
    // Filtering only reads titles and keywords; builders run lazily.
    final SettingsEntry e = SettingsEntry(
      id: 'x',
      title: 'Thing',
      keywords: 'alpha beta',
      builder: (BuildContext _) => const SizedBox.shrink(),
    );
    expect(filterSettingsEntries(<SettingsEntry>[e], 'beta'), hasLength(1));
    expect(filterSettingsEntries(<SettingsEntry>[e], 'gamma'), isEmpty);
  });
}
