import 'package:akshaya/core/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/feedback.dart';
import '../../insights/presentation/insights_screen.dart';
import '../../lock/app_lock.dart';
import '../../pantry/domain/unit.dart';
import '../../recipes/domain/recipe_models.dart';
import '../../recipes/presentation/preferences_sheet.dart';
import '../../recipes/presentation/providers.dart';
import '../domain/app_settings.dart';
import 'categories_screen.dart';
import 'providers.dart';

/// Appearance, currency, default unit, diet preferences, categories, app
/// lock and the Insights shortcut.
class GeneralSection extends ConsumerWidget {
  const GeneralSection({super.key});

  Future<void> _write(WidgetRef ref, String key, String value) {
    return ref
        .read(settingsRepositoryProvider)
        .writeAll(<String, String>{key: value});
  }

  Future<void> _toggleLock(
    BuildContext context,
    WidgetRef ref,
    bool enable,
  ) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    if (!enable) {
      await _write(ref, AppSettingKeys.appLock, 'false');
      return;
    }
    final AppAuthenticator auth = ref.read(appAuthenticatorProvider);
    if (!await auth.isAvailable()) {
      showMessage(messenger, appLockUnavailableMessage());
      return;
    }
    // Prove it works before turning it on, so nobody gets locked out.
    if (await auth.authenticate('Turn on app lock')) {
      await _write(ref, AppSettingKeys.appLock, 'true');
    }
  }

  Future<void> _editPreferences(BuildContext context, WidgetRef ref) async {
    final RecipePreferences? updated = await showRecipePreferencesSheet(
      context,
      ref.read(recipePreferencesProvider),
    );
    if (updated == null) {
      return;
    }
    await ref.read(recipesControllerProvider.notifier).savePreferences(updated);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppSettings settings = ref.watch(appSettingsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.xs,
          ),
          child: SectionHeader(title: 'General'),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: SegmentedButton<AppThemeChoice>(
            segments: <ButtonSegment<AppThemeChoice>>[
              for (final AppThemeChoice c in AppThemeChoice.values)
                ButtonSegment<AppThemeChoice>(value: c, label: Text(c.label)),
            ],
            selected: <AppThemeChoice>{settings.theme},
            showSelectedIcon: false,
            onSelectionChanged: (Set<AppThemeChoice> v) =>
                _write(ref, AppSettingKeys.theme, v.first.key),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        ListTile(
          leading: const Icon(Icons.currency_rupee_rounded),
          title: const Text('Currency'),
          trailing: DropdownButton<String>(
            value: settings.currencySymbol,
            underline: const SizedBox.shrink(),
            items: <DropdownMenuItem<String>>[
              for (final String s in kCurrencyChoices)
                DropdownMenuItem<String>(value: s, child: Text(s)),
            ],
            onChanged: (String? v) {
              if (v != null) {
                _write(ref, AppSettingKeys.currency, v);
              }
            },
          ),
        ),
        ListTile(
          leading: const Icon(Icons.straighten_rounded),
          title: const Text('Default unit'),
          subtitle: const Text('Used when adding a new item'),
          trailing: DropdownButton<Unit>(
            value: settings.defaultUnit,
            underline: const SizedBox.shrink(),
            items: <DropdownMenuItem<Unit>>[
              for (final Unit u in Unit.values)
                DropdownMenuItem<Unit>(value: u, child: Text(u.symbol)),
            ],
            onChanged: (Unit? v) {
              if (v != null) {
                _write(ref, AppSettingKeys.defaultUnit, v.symbol);
              }
            },
          ),
        ),
        ListTile(
          leading: const Icon(Icons.restaurant_menu_rounded),
          title: const Text('Diet and recipe preferences'),
          subtitle: const Text('Veg, cuisine, allergies, cooking time'),
          onTap: () => _editPreferences(context, ref),
        ),
        ListTile(
          leading: const Icon(Icons.category_outlined),
          title: const Text('Categories'),
          subtitle: const Text('Rename, change icons, add your own'),
          onTap: () => Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (BuildContext _) => const CategoriesScreen(),
            ),
          ),
        ),
        const ListTile(
          leading: Icon(Icons.kitchen_outlined),
          title: Text('Storage locations'),
          subtitle: Text('Fridge, Freezer, Pantry and Other (fixed)'),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.animation_rounded),
          title: const Text('Animations'),
          subtitle: const Text('Transitions and motion throughout the app'),
          value: settings.animations,
          onChanged: (bool v) => _write(ref, AppSettingKeys.animations, '$v'),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.wallpaper_rounded),
          title: const Text('Wallpaper colours'),
          subtitle: const Text(
            'Match your wallpaper (Material 3 Expressive, Android 12+)',
          ),
          value: settings.wallpaperTheme,
          onChanged: (bool v) =>
              _write(ref, AppSettingKeys.wallpaperTheme, '$v'),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.fingerprint_rounded),
          title: const Text('App lock'),
          subtitle: const Text('Ask for fingerprint, face or screen lock'),
          value: settings.appLock,
          onChanged: (bool v) => _toggleLock(context, ref, v),
        ),
        ListTile(
          leading: const Icon(Icons.insights_rounded),
          title: const Text('Insights'),
          subtitle: const Text('Spending, waste and how fast things run out'),
          onTap: () => Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (BuildContext _) => const InsightsScreen(),
            ),
          ),
        ),
      ],
    );
  }
}
