import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import 'package:quick_actions/quick_actions.dart';

import '../../../core/diagnostics/diag.dart';
import '../../../core/time/clock.dart';
import '../../rescue/domain/food_rescue.dart';
import '../../rescue/presentation/providers.dart';
import '../../shopping/domain/shopping_entities.dart';
import '../../shopping/presentation/providers.dart';
import '../../travel/presentation/trip_providers.dart';
import '../data/home_widget_gateway.dart';
import '../data/widget_background.dart';
import '../domain/widget_gateway.dart';
import '../domain/widget_snapshot.dart';

/// The home screen widgets. Tests override it with a fake.
final Provider<WidgetGateway> widgetGatewayProvider =
    Provider<WidgetGateway>((Ref ref) => const HomeWidgetGateway());

/// The place a tapped widget button or app shortcut wants to open. The app
/// shell opens it and then clears it.
final NotifierProvider<QuickLaunchNotifier, QuickLaunch?>
    quickLaunchProvider =
    NotifierProvider<QuickLaunchNotifier, QuickLaunch?>(
  QuickLaunchNotifier.new,
);

class QuickLaunchNotifier extends Notifier<QuickLaunch?> {
  @override
  QuickLaunch? build() => null;

  void open(QuickLaunch target) => state = target;

  void clear() => state = null;
}

/// Keeps the home screen widgets and the long-press app shortcuts in step
/// with the app. Read once at start-up.
///
/// The widgets are redrawn (after a short pause, so a burst of edits counts
/// once) whenever Food rescue, the shopping list or a trip changes, and taps
/// on widget buttons and shortcuts are handed to [quickLaunchProvider].
final Provider<void> widgetCoordinatorProvider = Provider<void>((Ref ref) {
  final WidgetGateway gateway = ref.watch(widgetGatewayProvider);
  Timer? pause;
  bool disposed = false;
  WidgetSnapshot? last;

  Future<void> publish() async {
    if (disposed) {
      return;
    }
    final List<RescueEntry> rescue = ref.read(foodRescueProvider);
    final List<ShoppingEntry> entries =
        ref.read(shoppingEntriesProvider).value ?? const <ShoppingEntry>[];
    final WidgetSnapshot snapshot = WidgetSnapshots.build(
      rescue: rescue,
      entries: entries,
      today: ref.read(todayProvider),
      pausedUntil: ref.read(recurringResumeProvider),
    );
    if (snapshot == last) {
      return;
    }
    last = snapshot;
    await gateway.publish(snapshot);
  }

  void schedule() {
    pause?.cancel();
    pause = Timer(const Duration(seconds: 1), () => unawaited(publish()));
  }

  ref.listen<List<RescueEntry>>(
    foodRescueProvider,
    (List<RescueEntry>? previous, List<RescueEntry> next) => schedule(),
  );
  ref.listen<AsyncValue<List<ShoppingEntry>>>(
    shoppingEntriesProvider,
    (AsyncValue<List<ShoppingEntry>>? previous,
            AsyncValue<List<ShoppingEntry>> next) =>
        schedule(),
  );
  ref.listen<DateTime?>(
    recurringResumeProvider,
    (DateTime? previous, DateTime? next) => schedule(),
  );
  schedule();

  unawaited(registerWidgetBackgroundCallback());
  StreamSubscription<Uri?>? clicks;
  try {
    unawaited(
      HomeWidget.initiallyLaunchedFromHomeWidget().then((Uri? uri) {
        final QuickLaunch? target = QuickLaunch.fromUri(uri);
        if (target != null && !disposed) {
          ref.read(quickLaunchProvider.notifier).open(target);
        }
      }).catchError((Object error, StackTrace stack) {
        Diag.error('widgets', 'Widget launch check failed', error: error, stack: stack);
      }),
    );
    clicks = HomeWidget.widgetClicked.listen((Uri? uri) {
      final QuickLaunch? target = QuickLaunch.fromUri(uri);
      if (target != null) {
        ref.read(quickLaunchProvider.notifier).open(target);
      }
    });
  } on Object catch (error, stack) {
    Diag.warn('widgets', 'Widget clicks unavailable', error: error, stack: stack);
  }

  // Long-press shortcuts on the app icon.
  try {
    const QuickActions actions = QuickActions();
    unawaited(
      actions.initialize((String type) {
        final QuickLaunch? target = QuickLaunch.fromKey(type);
        if (target != null) {
          ref.read(quickLaunchProvider.notifier).open(target);
        }
      }),
    );
    unawaited(
      actions.setShortcutItems(const <ShortcutItem>[
        ShortcutItem(
          type: 'voice',
          localizedTitle: 'Voice add',
          icon: 'ic_shortcut_voice',
        ),
        ShortcutItem(
          type: 'scan',
          localizedTitle: 'Scan barcode',
          icon: 'ic_shortcut_scan',
        ),
        ShortcutItem(
          type: 'shopping',
          localizedTitle: 'Shopping list',
          icon: 'ic_shortcut_shopping',
        ),
      ]),
    );
  } on Object catch (error, stack) {
    Diag.warn('widgets', 'App shortcuts unavailable', error: error, stack: stack);
  }

  ref.onDispose(() {
    disposed = true;
    pause?.cancel();
    unawaited(clicks?.cancel());
  });
});
