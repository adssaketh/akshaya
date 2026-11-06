import 'dart:async';

import 'package:akshaya/core/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/diagnostics/diag.dart';
import '../alerts/domain/alert_plan.dart';
import '../alerts/presentation/first_run_prompt.dart';
import '../alerts/presentation/providers.dart';
import '../commands/domain/command_models.dart';
import '../commands/presentation/command_flow.dart';
import '../count/presentation/count_flow.dart';
import '../home/presentation/home_screen.dart';
import '../pantry/presentation/pantry_actions.dart';
import '../pantry/presentation/pantry_screen.dart';
import '../planner/presentation/meal_planner_screen.dart';
import '../pantry/presentation/providers.dart';
import '../recipes/presentation/recipes_screen.dart';
import '../settings/domain/app_settings.dart';
import '../settings/presentation/providers.dart';
import '../settings/settings_screen.dart';
import '../travel/presentation/travel_screen.dart';
import '../widgets/domain/widget_gateway.dart';
import '../widgets/presentation/widget_providers.dart';
import '../shopping/presentation/shopping_screen.dart';

/// Bottom navigation: Home, Pantry, Shopping, Recipes, Settings.
/// Home is the dashboard; the other four tabs are the feature screens.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  static const int _pantryTab = 1;
  static const int _shoppingTab = 2;
  static const int _recipesTab = 3;
  static const List<String> _tabNames = <String>[
    'Home',
    'Pantry',
    'Shopping',
    'Recipes',
    'Settings',
  ];
  int _index = 0;

  /// The glass look for the nav bar, or null when the bar is solid.
  static NavBarGlass? _glass(AppSettings s) {
    if (s.barStyle != BarStyle.glass) {
      return null;
    }
    return NavBarGlass(
      opacity: s.glassAlpha / 100,
      blurSigma: s.glassBlur.sigma,
      edge: s.glassEdge,
    );
  }

  @override
  void initState() {
    super.initState();
    // Alerts tapped while the app is running.
    ref.listenManual<AlertTarget?>(alertTargetProvider, (previous, next) {
      if (next != null) {
        _openAlertTarget(next);
      }
    });
    // Widget buttons and app shortcuts (Voice, Scan, Add, Shopping).
    ref.listenManual<QuickLaunch?>(quickLaunchProvider, (previous, next) {
      if (next != null) {
        _openQuickLaunch(next);
      }
    });
    // Providers cannot be changed while the first frame builds, so anything
    // pending from start-up (an alert that launched the app) waits for it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final AlertTarget? pending = ref.read(alertTargetProvider);
      final QuickLaunch? launch = ref.read(quickLaunchProvider);
      if (launch != null) {
        _openQuickLaunch(launch);
      } else if (pending != null) {
        _openAlertTarget(pending);
      } else {
        unawaited(askForNotificationsOnFirstRun(context, ref));
      }
    });
  }

  /// Shows the screen an alert is about: Pantry filtered to the alert's
  /// status, or the Shopping tab with its restock suggestions.
  void _openAlertTarget(AlertTarget target) {
    if (!mounted) {
      return;
    }
    // Back to the tabs if a form or detail screen is open.
    Navigator.of(context).popUntil((Route<dynamic> route) => route.isFirst);
    final PantryQueryNotifier query = ref.read(pantryQueryProvider.notifier);
    switch (target) {
      case AlertTarget.pantryExpired:
        query
          ..clearFilters()
          ..setStatus(StatusKind.expired);
        setState(() => _index = _pantryTab);
      case AlertTarget.pantryExpiring:
        query
          ..clearFilters()
          ..setStatus(StatusKind.expiring);
        setState(() => _index = _pantryTab);
      case AlertTarget.shoppingSuggestions:
      case AlertTarget.householdShopping:
        setState(() => _index = _shoppingTab);
      case AlertTarget.householdPantry:
        query.clearFilters();
        setState(() => _index = _pantryTab);
      case AlertTarget.countMode:
        setState(() => _index = _pantryTab);
        unawaited(openCountMode(context));
      case AlertTarget.mealPlan:
        unawaited(openMealPlanner(context));
      case AlertTarget.recipes:
        setState(() => _index = _recipesTab);
      case AlertTarget.trip:
        unawaited(
          openTravelMode(
            context,
            onShowRecipes: () => setState(() => _index = _recipesTab),
          ),
        );
    }
    ref.read(alertTargetProvider.notifier).clear();
  }

  /// Opens what a widget button or app shortcut asked for.
  void _openQuickLaunch(QuickLaunch target) {
    if (!mounted) {
      return;
    }
    // Back to the tabs if a form or detail screen is open.
    Navigator.of(context).popUntil((Route<dynamic> route) => route.isFirst);
    switch (target) {
      case QuickLaunch.voice:
        unawaited(
          runCommandFlow(
            context,
            ref,
            commandContext: CommandContext.general,
          ),
        );
      case QuickLaunch.scan:
        unawaited(openScanToAdd(context, ref));
      case QuickLaunch.add:
        openAddItem(context);
      case QuickLaunch.shopping:
        setState(() => _index = _shoppingTab);
      case QuickLaunch.useFirst:
        ref.read(pantryQueryProvider.notifier).clearFilters();
        setState(() => _index = 0);
    }
    ref.read(quickLaunchProvider.notifier).clear();
  }

  /// Opens the Pantry tab, filtered to [status] (or unfiltered when null).
  void _showPantry(StatusKind? status) {
    final PantryQueryNotifier query = ref.read(pantryQueryProvider.notifier)
      ..clearFilters();
    if (status != null) {
      query.setStatus(status);
    }
    setState(() => _index = _pantryTab);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // The tabs run behind the floating bar, so nothing is cut off in a
      // straight line above it.
      extendBody: true,
      body: _EdgeBody(
        settings: ref.watch(appSettingsProvider),
        child: IndexedStack(
        index: _index,
        children: <Widget>[
          TabPane(
            active: _index == 0,
            child: HomeScreen(
              onShowPantry: _showPantry,
              onShowShopping: () => setState(() => _index = _shoppingTab),
              onShowRecipes: () => setState(() => _index = _recipesTab),
            ),
          ),
          TabPane(active: _index == 1, child: const PantryScreen()),
          TabPane(active: _index == 2, child: const ShoppingScreen()),
          TabPane(active: _index == 3, child: const RecipesScreen()),
          TabPane(active: _index == 4, child: const SettingsScreen()),
        ],
        ),
      ),
      bottomNavigationBar: AkshayaNavBar(
        glass: _glass(ref.watch(appSettingsProvider)),
        selectedIndex: _index,
        onSelected: (int i) {
          Diag.info('nav', 'Tab ${_tabNames[i]}');
          setState(() => _index = i);
        },
        destinations: const <AkshayaNavDestination>[
          AkshayaNavDestination(
            icon: Icons.home_outlined,
            selectedIcon: Icons.home_rounded,
            label: 'Home',
          ),
          AkshayaNavDestination(
            icon: Icons.inventory_2_outlined,
            selectedIcon: Icons.inventory_2_rounded,
            label: 'Pantry',
          ),
          AkshayaNavDestination(
            icon: Icons.shopping_basket_outlined,
            selectedIcon: Icons.shopping_basket_rounded,
            label: 'Shopping',
          ),
          AkshayaNavDestination(
            icon: Icons.soup_kitchen_outlined,
            selectedIcon: Icons.soup_kitchen_rounded,
            label: 'Recipes',
          ),
          AkshayaNavDestination(
            icon: Icons.settings_outlined,
            selectedIcon: Icons.settings_rounded,
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

/// Fades (or blurs) the page where it slides under the floating bar.
class _EdgeBody extends StatelessWidget {
  const _EdgeBody({required this.settings, required this.child});

  final AppSettings settings;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ScrollEdgeEffect(
      kind: settings.edgeEffect.kind,
      // With extendBody the body's bottom padding is the bar's full height.
      barHeight: MediaQuery.paddingOf(context).bottom,
      glass: settings.barStyle == BarStyle.glass,
      fadeExtra: settings.edgeFade.extra,
      blurSigma: settings.edgeBlur.sigma,
      child: child,
    );
  }
}
