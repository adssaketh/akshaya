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
import 'theme_choice_picker.dart';

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
          child: ThemeChoicePicker(
            selected: settings.theme,
            onChanged: (AppThemeChoice v) =>
                _write(ref, AppSettingKeys.theme, v.key),
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
        _BarStyleBlock(
          settings: settings,
          onWrite: (String k, String v) => _write(ref, k, v),
        ),
        _EdgeEffectBlock(
          settings: settings,
          onWrite: (String k, String v) => _write(ref, k, v),
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

/// "Bar style": solid or glass navigation bar, and the glass controls.
class _BarStyleBlock extends StatelessWidget {
  const _BarStyleBlock({required this.settings, required this.onWrite});

  final AppSettings settings;
  final Future<void> Function(String key, String value) onWrite;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = context.akText;
    final AkshayaColors colors = context.akColors;
    final bool glass = settings.barStyle == BarStyle.glass;
    final int transparency = 100 - settings.glassAlpha;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Bar style', style: text.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'How the bottom navigation bar looks',
            style: text.bodySmall?.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            children: <Widget>[
              for (final BarStyle s in BarStyle.values)
                ChoiceChip(
                  label: Text(s.label),
                  selected: settings.barStyle == s,
                  onSelected: (_) => onWrite(AppSettingKeys.barStyle, s.key),
                ),
            ],
          ),
          if (glass) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Material(
              color: colors.surface,
              borderRadius: AppRadius.cardBorder,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            'Glass transparency',
                            style: text.titleSmall,
                          ),
                        ),
                        Text('$transparency%', style: text.labelLarge),
                      ],
                    ),
                    Slider(
                      value: transparency.toDouble(),
                      min: (100 - kGlassAlphaMax).toDouble(),
                      max: (100 - kGlassAlphaMin).toDouble(),
                      semanticFormatterCallback: (double v) =>
                          '${v.round()} percent transparent',
                      onChanged: (double v) => onWrite(
                        AppSettingKeys.glassAlpha,
                        '${100 - v.round()}',
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text(
                          'Frosted',
                          style: text.bodySmall
                              ?.copyWith(color: colors.textSecondary),
                        ),
                        Text(
                          'Clear',
                          style: text.bodySmall
                              ?.copyWith(color: colors.textSecondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text('Glass blur', style: text.titleSmall),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      children: <Widget>[
                        for (final GlassBlur b in GlassBlur.values)
                          ChoiceChip(
                            label: Text(b.label),
                            selected: settings.glassBlur == b,
                            onSelected: (_) =>
                                onWrite(AppSettingKeys.glassBlur, b.key),
                          ),
                      ],
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Glass edge'),
                      subtitle: const Text('A thin light rim around the bar'),
                      value: settings.glassEdge,
                      onChanged: (bool v) =>
                          onWrite(AppSettingKeys.glassEdge, '$v'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// "Scroll edge effect": what happens to the page under the bottom bar.
class _EdgeEffectBlock extends StatelessWidget {
  const _EdgeEffectBlock({required this.settings, required this.onWrite});

  final AppSettings settings;
  final Future<void> Function(String key, String value) onWrite;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = context.akText;
    final AkshayaColors colors = context.akColors;
    final TextStyle? hint =
        text.bodySmall?.copyWith(color: colors.textSecondary);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Scroll edge effect', style: text.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'What happens to the page as it slides under the bottom bar. '
            'Fade is clean and light; Fade + blur adds a soft blur.',
            style: hint,
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            children: <Widget>[
              for (final EdgeEffect e in EdgeEffect.values)
                ChoiceChip(
                  label: Text(e.label),
                  selected: settings.edgeEffect == e,
                  onSelected: (_) => onWrite(AppSettingKeys.edgeEffect, e.key),
                ),
            ],
          ),
          if (settings.edgeEffect == EdgeEffect.blur) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Text('Blur strength', style: text.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              children: <Widget>[
                for (final EdgeBlur b in EdgeBlur.values)
                  ChoiceChip(
                    label: Text(b.label),
                    selected: settings.edgeBlur == b,
                    onSelected: (_) => onWrite(AppSettingKeys.edgeBlur, b.key),
                  ),
              ],
            ),
          ],
          if (settings.edgeEffect != EdgeEffect.off) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Text('Fade height', style: text.titleSmall),
            const SizedBox(height: AppSpacing.xs),
            Text('How far above the bar the page starts to fade.', style: hint),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              children: <Widget>[
                for (final EdgeFade f in EdgeFade.values)
                  ChoiceChip(
                    label: Text(f.label),
                    selected: settings.edgeFade == f,
                    onSelected: (_) => onWrite(AppSettingKeys.edgeFade, f.key),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
