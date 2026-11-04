import 'package:akshaya/features/sync/domain/change_digest.dart';
import 'package:flutter_test/flutter_test.dart';

RemoteChange entry(String user, {bool removed = false, String? list}) =>
    RemoteChange(
      collection: 'entries',
      userId: user,
      removed: removed,
      listName: list,
    );

void main() {
  const Map<String, String> names = <String, String>{'p': 'Priya'};

  test('groups additions per person and list', () {
    final List<String> lines = ChangeDigest.shoppingLines(
      <RemoteChange>[
        entry('p', list: 'Weekly'),
        entry('p', list: 'Weekly'),
        entry('p', list: 'Weekly'),
      ],
      names,
    );
    expect(lines, <String>['Priya added 3 items to Weekly']);
  });

  test('says 1 item and uses a fallback for unknown people and lists', () {
    final List<String> lines = ChangeDigest.shoppingLines(
      <RemoteChange>[entry('x')],
      names,
    );
    expect(lines, <String>['Someone added 1 item to the shopping list']);
  });

  test('reports removals separately', () {
    final List<String> lines = ChangeDigest.shoppingLines(
      <RemoteChange>[
        entry('p', list: 'Weekly'),
        entry('p', removed: true, list: 'Weekly'),
      ],
      names,
    );
    expect(lines, <String>[
      'Priya added 1 item to Weekly',
      'Priya removed 1 item from Weekly',
    ]);
  });

  test('pantry lines only look at batches', () {
    final List<String> lines = ChangeDigest.pantryLines(
      <RemoteChange>[
        entry('p'),
        const RemoteChange(collection: 'batches', userId: 'p', removed: false),
      ],
      names,
    );
    expect(lines, <String>['Priya added stock of 1 item']);
  });
}
