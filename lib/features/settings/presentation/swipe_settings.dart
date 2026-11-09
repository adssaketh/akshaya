import 'package:akshaya/core/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../pantry/presentation/recycle_bin_screen.dart';
import 'providers.dart';

/// Settings keys of the swipe options.
const String kSwipeTabsKey = 'nav.swipe_tabs';
const String kSwipeItemsKey = 'swipe.item_actions';

/// Swiping sideways changes the tab. On unless switched off.
final Provider<bool> swipeTabsProvider = Provider<bool>((Ref ref) {
  final Map<String, String> stored =
      ref.watch(settingsMapProvider).value ?? const <String, String>{};
  return stored[kSwipeTabsKey] != 'false';
});

/// Swiping an item right to use it and left to delete it. OFF unless switched
/// on: a swipe meant to change the tab must never touch food, and a row that
/// listens for sideways drags would also take them from the tab swipe.
final Provider<bool> swipeItemActionsProvider = Provider<bool>((Ref ref) {
  final Map<String, String> stored =
      ref.watch(settingsMapProvider).value ?? const <String, String>{};
  return stored[kSwipeItemsKey] == 'true';
});

/// Swipe options and the way to the recycle bin.
class SwipeSection extends ConsumerWidget {
  const SwipeSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool tabs = ref.watch(swipeTabsProvider);
    final bool items = ref.watch(swipeItemActionsProvider);
    void save(String key, bool value) {
      ref.read(settingsRepositoryProvider).writeAll(<String, String>{
        key: value.toString(),
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            0,
          ),
          child: SectionHeader(title: 'Swiping and deleted items'),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.swipe_rounded),
          title: const Text('Swipe to change tab'),
          subtitle: const Text(
            'Swipe sideways to move between Home, Pantry, Shopping, Recipes '
            'and Settings.',
          ),
          value: tabs,
          onChanged: (bool v) => save(kSwipeTabsKey, v),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.delete_sweep_outlined),
          title: const Text('Swipe an item to use or delete it'),
          subtitle: const Text(
            'Off by default, so swiping over your groceries changes tab and '
            'never touches your food. When on: swipe right to use, left to '
            'delete. You can always use or delete from an item\'s menu '
            '(press and hold).',
          ),
          value: items,
          onChanged: (bool v) => save(kSwipeItemsKey, v),
        ),
        ListTile(
          leading: const Icon(Icons.restore_from_trash_rounded),
          title: const Text('Recently deleted'),
          subtitle: const Text(
            'Bring back groceries you deleted in the last 30 days',
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => openRecycleBin(context),
        ),
      ],
    );
  }
}
