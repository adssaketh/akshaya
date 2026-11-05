import 'dart:async';

import 'package:akshaya/core/design/design.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

class AkshayaApp extends ConsumerStatefulWidget {
  const AkshayaApp({super.key});

  @override
  ConsumerState<AkshayaApp> createState() => _AkshayaAppState();
}

class _AkshayaAppState extends ConsumerState<AkshayaApp> {
  late final AppLifecycleListener _lifecycle;

  // Built once: rebuilding two full ThemeData objects on every app rebuild is
  // wasted work.
  final ThemeData _lightTheme = AkshayaTheme.light();
  final ThemeData _darkTheme = AkshayaTheme.dark();

  // Wallpaper themes, rebuilt only when the wallpaper colour changes.
  Color? _wallpaperSeed;
  ThemeData? _wallpaperLight;
  ThemeData? _wallpaperDark;

  void _updateWallpaper(Color seed) {
    if (_wallpaperSeed == seed) {
      return;
    }
    _wallpaperSeed = seed;
    _wallpaperLight = AkshayaTheme.lightFromSeed(seed);
    _wallpaperDark = AkshayaTheme.darkFromSeed(seed);
  }

  @override
  void initState() {
    super.initState();
    // Starts keeping the scheduled alerts and the background check in step
    // with the app.
    ref.read(alertCoordinatorProvider);
    // Starts household sync once someone is signed in to a household.
    ref.read(syncCoordinatorProvider);
    // Adds each trip's back-home essentials to the shopping list when due.
    ref.read(backHomeCoordinatorProvider);
    // Keeps the home screen widgets and app shortcuts up to date.
    ref.read(widgetCoordinatorProvider);
    _lifecycle = AppLifecycleListener(
      onPause: () {
        // Live listeners cost reads; they stop while the app is hidden.
        unawaited(ref.read(syncEngineProvider).pauseListening());
      },
      onResume: () {
        unawaited(ref.read(syncEngineProvider).resumeListening());
        // A new day may have started while the app was in the background.
        ref.read(todayProvider.notifier).refresh();
        // Notifications may have been switched on or off in system settings.
        ref.invalidate(notificationsAllowedProvider);
        // A notification button may have changed the pantry from a background
        // task with its own database connection; re-run the watched queries.
        final AppDatabase db = ref.read(appDatabaseProvider);
        db.markTablesUpdated(db.allTables);
      },
    );
  }

  @override
  void dispose() {
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
      builder: (ColorScheme? lightDynamic, ColorScheme? _) {
        // Only phones that expose wallpaper colours (Android 12+) get them.
        final bool wallpaper = settings.wallpaperTheme && lightDynamic != null;
        if (wallpaper) {
          _updateWallpaper(lightDynamic.primary);
        }
        return MaterialApp(
          title: 'Akshaya Patra',
          debugShowCheckedModeBanner: false,
          theme: wallpaper ? _wallpaperLight! : _lightTheme,
          darkTheme: wallpaper ? _wallpaperDark! : _darkTheme,
          themeMode: _mode(settings.theme),
          builder: (BuildContext context, Widget? child) =>
              AppLockGate(child: child ?? const SizedBox.shrink()),
          home: const AppShell(),
        );
      },
    );
  }
}
