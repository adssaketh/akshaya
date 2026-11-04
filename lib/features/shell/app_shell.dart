import 'package:akshaya/core/design/design.dart';
import 'package:flutter/material.dart';

import '../pantry/presentation/pantry_screen.dart';
import '../settings/settings_screen.dart';
import '../shopping/presentation/shopping_screen.dart';

/// Bottom navigation: Home, Pantry, Shopping, Recipes, Settings.
/// Pantry, Shopping and Settings are live; Home and Recipes are placeholders.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static const int _pantryTab = 1;
  int _index = _pantryTab;

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
