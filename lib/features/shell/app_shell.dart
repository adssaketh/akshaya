import 'dart:async';

import 'package:akshaya/core/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../alerts/domain/alert_plan.dart';
import '../alerts/presentation/first_run_prompt.dart';
import '../alerts/presentation/providers.dart';
import '../home/presentation/home_screen.dart';
import '../pantry/presentation/pantry_screen.dart';
import '../pantry/presentation/providers.dart';
import '../recipes/presentation/recipes_screen.dart';
import '../settings/settings_screen.dart';
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
  int _index = 0;

  @override
  void initState() {
    super.initState();
    // Alerts tapped while the app is running.
    ref.listenManual<AlertTarget?>(alertTargetProvider, (previous, next) {
      if (next != null) {
        _openAlertTarget(next);
      }
    });
    // Providers cannot be changed while the first frame builds, so anything
    // pending from start-up (an alert that launched the app) waits for it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final AlertTarget? pending = ref.read(alertTargetProvider);
      if (pending != null) {
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
    }
    ref.read(alertTargetProvider.notifier).clear();
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
      body: IndexedStack(
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
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (int i) => setState(() => _index = i),
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: PopIn(child: Icon(Icons.home_rounded)),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: PopIn(child: Icon(Icons.inventory_2_rounded)),
            label: 'Pantry',
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_basket_outlined),
            selectedIcon: PopIn(child: Icon(Icons.shopping_basket_rounded)),
            label: 'Shopping',
          ),
          NavigationDestination(
            icon: Icon(Icons.soup_kitchen_outlined),
            selectedIcon: PopIn(child: Icon(Icons.soup_kitchen_rounded)),
            label: 'Recipes',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: PopIn(child: Icon(Icons.settings_rounded)),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
