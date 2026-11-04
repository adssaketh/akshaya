import 'dart:async';

import 'package:akshaya/core/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../alerts/domain/alert_plan.dart';
import '../alerts/presentation/first_run_prompt.dart';
import '../alerts/presentation/providers.dart';
import '../pantry/presentation/pantry_screen.dart';
import '../pantry/presentation/providers.dart';
import '../settings/settings_screen.dart';
import '../shopping/presentation/shopping_screen.dart';

/// Bottom navigation: Home, Pantry, Shopping, Recipes, Settings.
/// Pantry, Shopping and Settings are live; Home and Recipes are placeholders.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  static const int _pantryTab = 1;
  static const int _shoppingTab = 2;
  int _index = _pantryTab;

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
        setState(() => _index = _shoppingTab);
    }
    ref.read(alertTargetProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const <Widget>[
          _Placeholder(
            icon: Icons.home_rounded,
            title: 'Home',
            body: 'Your dashboard arrives in a later phase.',
          ),
          PantryScreen(),
          ShoppingScreen(),
          _Placeholder(
            icon: Icons.soup_kitchen_rounded,
            title: 'Recipes',
            body: 'Recipe ideas for expiring food arrive in Phase 7.',
          ),
          SettingsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (int i) => setState(() => _index = i),
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2_rounded),
            label: 'Pantry',
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_basket_outlined),
            selectedIcon: Icon(Icons.shopping_basket_rounded),
            label: 'Shopping',
          ),
          NavigationDestination(
            icon: Icon(Icons.soup_kitchen_outlined),
            selectedIcon: Icon(Icons.soup_kitchen_rounded),
            label: 'Recipes',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: <Widget>[
          const AkshayaHeader(),
          Expanded(child: EmptyState(icon: icon, title: title, body: body)),
        ],
      ),
    );
  }
}
