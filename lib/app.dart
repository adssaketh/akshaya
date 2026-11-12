import 'dart:async';

import 'package:akshaya/core/design/design.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/diagnostics/diag.dart';
import 'core/diagnostics/error_handlers.dart';
import 'core/diagnostics/frame_stats.dart';
import 'core/time/clock.dart';
import 'core/util/money.dart';
import 'features/alerts/presentation/providers.dart';
import 'features/lock/app_lock.dart';
import 'features/pantry/data/database/app_database.dart';
import 'features/pantry/presentation/providers.dart' show appDatabaseProvider;
import 'features/settings/domain/app_settings.dart';
import 'features/settings/presentation/providers.dart';
import 'features/shell/app_shell.dart';
import 'features/sync/presentation/providers.dart';
import 'features/travel/presentation/back_home_coordinator.dart';
import 'features/widgets/presentation/widget_providers.dart';
import 'features/orders/presentation/providers.dart';

class AkshayaApp extends ConsumerStatefulWidget {
  const AkshayaApp({super.key});

  @override
  ConsumerState<AkshayaApp> createState() => _AkshayaAppState();
}

class _AkshayaAppState extends ConsumerState<AkshayaApp> {
  late final AppLifecycleListener _lifecycle;

  /// How long after the first frame household sync starts.
  static const Duration _syncStartDelay = Duration(milliseconds: 1500);

  /// How long after a resume sync catches up.
  static const Duration _syncResumeDelay = Duration(milliseconds: 700);

  Timer? _syncStart;
  Timer? _syncResume;

  // Built once: rebuilding two full ThemeData objects on every app rebuild is
  // wasted work.
  final ThemeData _lightTheme = AkshayaTheme.light();
  final ThemeData _darkTheme = AkshayaTheme.dark();

  // Notes which pages and sheets open, for the diagnostics log.
  final DiagNavigatorObserver _navigationLog = DiagNavigatorObserver();

  // Wallpaper themes, rebuilt only when the wallpaper palette changes.
  ColorScheme? _wallpaperLightScheme;
  ColorScheme? _wallpaperDarkScheme;
  ThemeData? _wallpaperLight;
  ThemeData? _wallpaperDark;

  void _updateWallpaper(ColorScheme light, ColorScheme dark) {
    if (_wallpaperLightScheme == light && _wallpaperDarkScheme == dark) {
      return;
    }
    _wallpaperLightScheme = light;
    _wallpaperDarkScheme = dark;
    _wallpaperLight = AkshayaTheme.fromSystemScheme(light);
    _wallpaperDark = AkshayaTheme.fromSystemScheme(dark);
  }

  @override
  void initState() {
    super.initState();
    // Starts keeping the scheduled alerts and the background check in step
    // with the app.
    ref.read(alertCoordinatorProvider);
    // Starts household sync once someone is signed in to a household. Not
    // straight away: sync loads Firebase, App Check, Remote Config and
    // Firestore and goes to the network, which made the first screen and its
    // entrance animations stutter. It starts once the first screen has been
    // drawn and has had a moment to settle.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncStart = Timer(_syncStartDelay, () {
        if (mounted) {
          ref.read(syncCoordinatorProvider);
        }
      });
    });
    // Learns the database's change counter now, so the first resume can tell
    // whether a background task changed anything.
    unawaited(ref.read(appDatabaseProvider).changedElsewhere());
    // Adds each trip's back-home essentials to the shopping list when due.
    ref.read(backHomeCoordinatorProvider);
    // Keeps the home screen widgets and app shortcuts up to date.
    ref.read(widgetCoordinatorProvider);
    // Collects order screenshots shared from the quick-commerce apps.
    ref.read(shareCoordinatorProvider);
    _lifecycle = AppLifecycleListener(
      onPause: () {
        Diag.info('app', 'Paused');
        FrameStats.flush('While open');
        _syncResume?.cancel();
        // Live listeners cost reads; they stop while the app is hidden.
        unawaited(ref.read(syncEngineProvider).pauseListening());
      },
      onResume: () {
        Diag.info('app', 'Resumed');
        // Catching up with the cloud waits until the app is back on screen,
        // so it does not compete with the return animation.
        _syncResume?.cancel();
        _syncResume = Timer(_syncResumeDelay, () {
          unawaited(ref.read(syncEngineProvider).resumeListening());
        });
        // A new day may have started while the app was in the background.
        ref.read(todayProvider.notifier).refresh();
        // Notifications may have been switched on or off in system settings.
        ref.invalidate(notificationsAllowedProvider);
        unawaited(_reloadIfChangedElsewhere());
      },
    );
  }

  /// A notification button may have changed the pantry from a background task
  /// with its own database connection. Only then are the watched queries run
  /// again; doing it on every resume rebuilt every screen each time the app
  /// came back.
  Future<void> _reloadIfChangedElsewhere() async {
    final AppDatabase db = ref.read(appDatabaseProvider);
    if (await db.changedElsewhere() && mounted) {
      db.markTablesUpdated(db.allTables);
    }
  }

  @override
  void dispose() {
    _syncStart?.cancel();
    _syncResume?.cancel();
    _lifecycle.dispose();
    super.dispose();
  }

  static ThemeMode _mode(AppThemeChoice choice) {
    switch (choice) {
      case AppThemeChoice.system:
        return ThemeMode.system;
      case AppThemeChoice.light:
        return ThemeMode.light;
      case AppThemeChoice.dark:
        return ThemeMode.dark;
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppSettings settings = ref.watch(appSettingsProvider);
    // Prices everywhere use the chosen symbol.
    currentCurrencySymbol = settings.currencySymbol;
    // Motion everywhere follows the Settings switch.
    AppMotion.userEnabled = settings.animations;
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        // Only phones that expose wallpaper colours (Android 12+) get them.
        final bool wallpaper = settings.wallpaperTheme &&
            lightDynamic != null &&
            darkDynamic != null;
        if (wallpaper) {
          _updateWallpaper(lightDynamic, darkDynamic);
        }
        return MaterialApp(
          title: 'Akshaya Patra',
          debugShowCheckedModeBanner: false,
          theme: wallpaper ? _wallpaperLight! : _lightTheme,
          darkTheme: wallpaper ? _wallpaperDark! : _darkTheme,
          themeMode: _mode(settings.theme),
          navigatorObservers: <NavigatorObserver>[_navigationLog],
          builder: (BuildContext context, Widget? child) =>
              AppLockGate(child: child ?? const SizedBox.shrink()),
          home: const AppShell(),
        );
      },
    );
  }
}
