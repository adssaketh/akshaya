import 'package:akshaya/core/design/design.dart';
import 'package:flutter/material.dart';

import '../domain/guide_models.dart';

/// A short description of each illustration, read aloud by screen readers.
extension GuidePreviewCaption on GuidePreview {
  String get caption => switch (this) {
        GuidePreview.tabs => 'The bottom bar with five tabs',
        GuidePreview.statusChips => 'The five status chips',
        GuidePreview.summaryTiles => 'Summary tiles on Home',
        GuidePreview.quickActions => 'Four quick action buttons',
        GuidePreview.undoSnackbar => 'An Undo message at the bottom',
        GuidePreview.pantryList => 'Search box and pantry rows',
        GuidePreview.addItemForm => 'The Add item form',
        GuidePreview.lowStockFields => 'Low-stock level and Essential item',
        GuidePreview.openedFields => 'The Already opened fields',
        GuidePreview.itemDetail => 'An item page with its batches',
        GuidePreview.useSheet => 'The Use sheet with quick amounts',
        GuidePreview.otherNames => 'The Other names field',
        GuidePreview.barcodeScan => 'The barcode scanner frame',
        GuidePreview.cookedFood => 'A cooked food item',
        GuidePreview.shoppingList => 'A shopping list with a basket',
        GuidePreview.suggestions => 'Suggested for you',
        GuidePreview.repeatEntry => 'A repeating shopping entry',
        GuidePreview.doneShopping => 'The Done shopping screen',
        GuidePreview.shareText => 'A shopping list shared as text',
        GuidePreview.commandCard => 'The voice confirmation card',
        GuidePreview.voiceExamples => 'Examples of spoken commands',
        GuidePreview.settingsAi => 'The AI and voice settings',
        GuidePreview.alertNotification => 'A daily alert with buttons',
        GuidePreview.settingsAlerts => 'The Alerts settings',
        GuidePreview.prepNotification => 'A prep reminder notification',
        GuidePreview.recipeIdeas => 'The Recipes tab with ideas',
        GuidePreview.recipeDetail => 'A recipe with In pantry labels',
        GuidePreview.preferencesSheet => 'The recipe preferences sheet',
        GuidePreview.mealPlan => 'The weekly meal plan',
        GuidePreview.foodRescue => 'Food rescue with its action buttons',
        GuidePreview.settingsFreeze => 'The Freezing rules settings',
        GuidePreview.wasteReasons => 'The waste reason choices',
        GuidePreview.insights => 'The Insights screen',
        GuidePreview.countCard => 'A Count mode card',
        GuidePreview.settingsCount => 'The Count mode settings',
        GuidePreview.runsOut => 'Pantry rows with a runs-out forecast',
        GuidePreview.whatToBuy => 'The What should I buy? screen',
        GuidePreview.signIn => 'The sign-in option in Settings',
        GuidePreview.household => 'The invite code, QR and members',
        GuidePreview.syncStatus => 'The sync status and Sync now',
        GuidePreview.tripBanner => 'A trip banner and risky food',
        GuidePreview.homeWidget => 'Two home screen widgets',
        GuidePreview.appShortcuts => 'The app icon shortcut menu',
        GuidePreview.themeCards => 'The appearance cards',
        GuidePreview.settingsGeneral => 'The General settings',
        GuidePreview.settingsCategories => 'The Categories settings',
        GuidePreview.settingsLock => 'The App lock setting',
        GuidePreview.settingsBackup => 'The Backup and export settings',
        GuidePreview.settingsSample => 'The Load sample data setting',
      };
}

/// A small, non-interactive picture of one feature, drawn with the app's own
/// design widgets and colours so it matches the real screens, follows light
/// and dark mode and scales with the system font size.
class GuidePreviewView extends StatelessWidget {
  const GuidePreviewView({super.key, required this.preview});

  final GuidePreview preview;

  @override
  Widget build(BuildContext context) {
    final AkshayaColors colors = context.akColors;
    return Semantics(
      container: true,
      image: true,
      label: 'Example picture: ${preview.caption}',
      child: ExcludeSemantics(
        child: IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.background,
              borderRadius: AppRadius.cardBorder,
              border: Border.all(
                color: colors.outline,
                width: AppSizes.borderWidth,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: _body(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    return switch (preview) {
      GuidePreview.tabs => _tabs(context),
      GuidePreview.statusChips => _statusChips(),
      GuidePreview.summaryTiles => _summaryTiles(),
      GuidePreview.quickActions => _quickActions(context),
      GuidePreview.undoSnackbar => _undoSnackbar(context),
      GuidePreview.pantryList => _pantryList(context),
      GuidePreview.addItemForm => _addItemForm(),
      GuidePreview.lowStockFields => _lowStockFields(context),
      GuidePreview.openedFields => _openedFields(context),
      GuidePreview.itemDetail => _itemDetail(context),
      GuidePreview.useSheet => _useSheet(context),
      GuidePreview.otherNames => _otherNames(),
      GuidePreview.barcodeScan => _barcodeScan(context),
      GuidePreview.cookedFood => _cookedFood(),
      GuidePreview.shoppingList => _shoppingList(context),
      GuidePreview.suggestions => _suggestions(context),
      GuidePreview.repeatEntry => _repeatEntry(context),
      GuidePreview.doneShopping => _doneShopping(context),
      GuidePreview.shareText => _shareText(context),
      GuidePreview.commandCard => _commandCard(context),
      GuidePreview.voiceExamples => _voiceExamples(context),
      GuidePreview.settingsAi => _settingsAi(context),
      GuidePreview.alertNotification => _notification(
          context,
          title: 'Expiring soon',
          body: 'Curd: tomorrow\nPaneer: in 2 days',
          actions: const <String>['Used it', 'Snooze', 'Show recipes'],
        ),
      GuidePreview.settingsAlerts => _settingsAlerts(context),
      GuidePreview.prepNotification => _notification(
          context,
          title: 'Soak rajma tonight',
          body: 'For Rajma masala tomorrow',
          actions: const <String>[],
        ),
      GuidePreview.recipeIdeas => _recipeIdeas(context),
      GuidePreview.recipeDetail => _recipeDetail(context),
      GuidePreview.preferencesSheet => _preferencesSheet(context),
      GuidePreview.mealPlan => _mealPlan(context),
      GuidePreview.foodRescue => _foodRescue(context),
      GuidePreview.settingsFreeze => _settingsFreeze(context),
      GuidePreview.wasteReasons => _wasteReasons(context),
      GuidePreview.insights => _insights(context),
      GuidePreview.countCard => _countCard(context),
      GuidePreview.settingsCount => _settingsCount(context),
      GuidePreview.runsOut => _runsOut(context),
      GuidePreview.whatToBuy => _whatToBuy(context),
      GuidePreview.signIn => _signIn(context),
      GuidePreview.household => _household(context),
      GuidePreview.syncStatus => _syncStatus(context),
      GuidePreview.tripBanner => _tripBanner(context),
      GuidePreview.homeWidget => _homeWidget(context),
      GuidePreview.appShortcuts => _appShortcuts(context),
      GuidePreview.themeCards => _themeCards(context),
      GuidePreview.settingsGeneral => _settingsGeneral(context),
      GuidePreview.settingsCategories => _settingsCategories(context),
      GuidePreview.settingsLock => _settingsLock(context),
      GuidePreview.settingsBackup => _settingsBackup(context),
      GuidePreview.settingsSample => _settingsSample(context),
    };
  }
}

// ---------------------------------------------------------------- Building
// blocks. Colours and sizes come from the design tokens only.

const SizedBox _gap = SizedBox(height: AppSpacing.md);
const SizedBox _gapSm = SizedBox(height: AppSpacing.sm);
const SizedBox _gapW = SizedBox(width: AppSpacing.sm);

/// Pill used for chips: expiry shortcuts, filters, action buttons.
class _Pill extends StatelessWidget {
  const _Pill(this.text, {this.selected = false, this.icon});

  final String text;
  final bool selected;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final AkshayaColors colors = context.akColors;
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: selected ? colors.surfaceAlt : colors.surface,
        shape: StadiumBorder(
          side: BorderSide(
            color: selected ? colors.primary : colors.outline,
            width: AppSizes.borderWidth,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, size: AppSizes.iconSm, color: colors.primary),
              const SizedBox(width: AppSpacing.xs),
            ],
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.akText.labelMedium!.copyWith(
                  color: selected ? colors.primary : colors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A button drawn the way the app's buttons look.
class _Btn extends StatelessWidget {
  const _Btn(this.label, {this.icon, this.filled = true});

  final String label;
  final IconData? icon;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final AkshayaColors colors = context.akColors;
    final Color foreground = filled ? colors.onPrimary : colors.textPrimary;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppSizes.touchTarget),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: filled ? colors.primary : colors.surfaceAlt,
          borderRadius: AppRadius.controlBorder,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, size: AppSizes.iconMd, color: foreground),
                const SizedBox(width: AppSpacing.sm),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.akText.labelLarge!.copyWith(
                    color: foreground,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A text field drawn with its label and a value.
class _Field extends StatelessWidget {
  const _Field(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final AkshayaColors colors = context.akColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadius.controlBorder,
        border: Border.all(color: colors.outline, width: AppSizes.borderWidth),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.akText.labelSmall!.copyWith(
                color: colors.textSecondary,
              ),
            ),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.akText.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}

/// A rounded surface card.
class _Card extends StatelessWidget {
  const _Card({required this.child, this.tint = false});

  final Widget child;
  final bool tint;

  @override
  Widget build(BuildContext context) {
    final AkshayaColors colors = context.akColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tint ? colors.surfaceAlt : colors.surface,
        borderRadius: AppRadius.cardBorder,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: SizedBox(width: double.infinity, child: child),
      ),
    );
  }
}

/// Section title inside a picture.
class _Title extends StatelessWidget {
  const _Title(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: context.akText.titleMedium);
  }
}

/// Small grey caption inside a picture.
class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: context.akText.bodySmall!.copyWith(
        color: context.akColors.textSecondary,
      ),
    );
  }
}

/// A row in a Settings list: round icon, title, optional subtitle and an
/// optional trailing widget (switch, value).
class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final AkshayaColors colors = context.akColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: <Widget>[
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surfaceAlt,
              shape: BoxShape.circle,
            ),
            child: SizedBox(
              width: AppSizes.avatar,
              height: AppSizes.avatar,
              child: Icon(icon, size: AppSizes.iconMd, color: colors.primary),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.akText.bodyLarge,
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.akText.bodySmall!.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          if (trailing != null) ...<Widget>[_gapW, trailing!],
        ],
      ),
    );
  }
}

Widget _switch({bool on = true}) => Switch(value: on, onChanged: (bool _) {});

Widget _chevron(BuildContext context) => Icon(
      Icons.chevron_right_rounded,
      color: context.akColors.textSecondary,
    );

Widget _valueText(BuildContext context, String text) => Text(
      text,
      style: context.akText.labelLarge!.copyWith(
        color: context.akColors.textSecondary,
      ),
    );

Widget _settingsCard(List<Widget> rows) => _Card(
      child: Column(mainAxisSize: MainAxisSize.min, children: rows),
    );

// ------------------------------------------------------------------ Start

Widget _tabs(BuildContext context) {
  final AkshayaColors colors = context.akColors;
  const List<(IconData, String)> items = <(IconData, String)>[
    (Icons.home_rounded, 'Home'),
    (Icons.inventory_2_rounded, 'Pantry'),
    (Icons.shopping_basket_rounded, 'Shopping'),
    (Icons.soup_kitchen_rounded, 'Recipes'),
    (Icons.settings_rounded, 'Settings'),
  ];
  return Row(
    children: <Widget>[
      for (int i = 0; i < items.length; i++)
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              DecoratedBox(
                decoration: ShapeDecoration(
                  color: i == 0 ? colors.surfaceAlt : null,
                  shape: const StadiumBorder(),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                  child: Icon(
                    items[i].$1,
                    size: AppSizes.iconLg,
                    color: i == 0 ? colors.primary : colors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                items[i].$2,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.akText.labelSmall!.copyWith(
                  color: i == 0 ? colors.textPrimary : colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
    ],
  );
}

Widget _statusChips() => Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: <Widget>[
        for (final StatusKind kind in StatusKind.values) StatusChip(kind: kind),
      ],
    );

Widget _summaryTiles() => LayoutBuilder(
      builder: (BuildContext context, BoxConstraints box) {
        final double width = (box.maxWidth - AppSpacing.md) / 2;
        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: <Widget>[
            SizedBox(
              width: width,
              child: const SummaryTile(
                kind: StatusKind.expiring,
                count: 3,
                label: 'Expiring soon',
              ),
            ),
            SizedBox(
              width: width,
              child: const SummaryTile(
                kind: StatusKind.expired,
                count: 1,
                label: 'Expired',
              ),
            ),
            SizedBox(
              width: width,
              child: const SummaryTile(
                kind: StatusKind.lowStock,
                count: 2,
                label: 'Low or out of stock',
              ),
            ),
            SizedBox(
              width: width,
              child: const SummaryTile(
                kind: StatusKind.fresh,
                count: 24,
                label: 'Items in pantry',
                icon: Icons.inventory_2_rounded,
              ),
            ),
          ],
        );
      },
    );

Widget _quickActions(BuildContext context) {
  final AkshayaColors colors = context.akColors;
  const List<(IconData, String)> items = <(IconData, String)>[
    (Icons.mic_rounded, 'Voice'),
    (Icons.qr_code_scanner_rounded, 'Scan'),
    (Icons.add_rounded, 'Add item'),
    (Icons.shopping_basket_rounded, 'Shopping'),
  ];
  return Row(
    children: <Widget>[
      for (int i = 0; i < items.length; i++) ...<Widget>[
        if (i > 0) _gapW,
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: AppRadius.cardBorder,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(items[i].$1, size: AppSizes.iconLg, color: colors.primary),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    items[i].$2,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.akText.labelSmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ],
  );
}

Widget _undoSnackbar(BuildContext context) {
  final ColorScheme scheme = Theme.of(context).colorScheme;
  return DecoratedBox(
    decoration: BoxDecoration(
      color: scheme.inverseSurface,
      borderRadius: AppRadius.controlBorder,
    ),
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              'Used 1 kg of Rice',
              style: context.akText.bodyMedium!.copyWith(
                color: scheme.onInverseSurface,
              ),
            ),
          ),
          Text(
            'Undo',
            style: context.akText.labelLarge!.copyWith(
              color: scheme.inversePrimary,
            ),
          ),
        ],
      ),
    ),
  );
}

// ----------------------------------------------------------------- Pantry

Widget _pantryList(BuildContext context) {
  final AkshayaColors colors = context.akColors;
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: AppRadius.controlBorder,
          border: Border.all(
            color: colors.outline,
            width: AppSizes.borderWidth,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: <Widget>[
              Icon(Icons.search_rounded, color: colors.textSecondary),
              _gapW,
              Expanded(
                child: Text(
                  'Search items, brands or other names',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.akText.bodyMedium!.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      _gapSm,
      const Align(
        alignment: Alignment.centerLeft,
        child: Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            _Pill('All', selected: true),
            _Pill('Expiring soon'),
            _Pill('Low stock'),
          ],
        ),
      ),
      _gapSm,
      const ItemCard(
        name: 'Rice',
        subtitle: 'Pantry · 4 kg left',
        icon: Icons.rice_bowl_rounded,
        status: StatusKind.fresh,
      ),
      _gapSm,
      const ItemCard(
        name: 'Curd',
        subtitle: 'Fridge · 1 packet left',
        icon: Icons.local_drink_rounded,
        status: StatusKind.expiring,
        statusLabel: 'In 2 days',
      ),
    ],
  );
}

Widget _expiryPills({String? selected}) => Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: <Widget>[
        for (final String label in const <String>[
          '+3 days',
          '+1 week',
          '+1 month',
          '+6 months',
        ])
          _Pill(label, selected: label == selected),
      ],
    );

Widget _addItemForm() => Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const _Field('Item name', 'Toor Dal'),
        _gapSm,
        const Row(
          children: <Widget>[
            Expanded(child: _Field('Quantity left', '2')),
            _gapW,
            Expanded(child: _Field('Unit', 'kg')),
          ],
        ),
        _gapSm,
        const _Field('Expires on (optional)', '6 May'),
        _gapSm,
        Align(
          alignment: Alignment.centerLeft,
          child: _expiryPills(selected: '+6 months'),
        ),
      ],
    );

Widget _lowStockFields(BuildContext context) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const _Field('Low-stock level (optional)', '1 kg'),
        const _Note('Warn when the amount left is at or below this'),
        _gap,
        _settingsCard(<Widget>[
          _SettingRow(
            icon: Icons.priority_high_rounded,
            title: 'Essential item',
            subtitle: 'Always keep in stock',
            trailing: _switch(),
          ),
        ]),
      ],
    );

Widget _openedFields(BuildContext context) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _settingsCard(<Widget>[
          _SettingRow(
            icon: Icons.inventory_rounded,
            title: 'Already opened',
            subtitle: 'Opened items can spoil sooner',
            trailing: _switch(),
          ),
        ]),
        _gapSm,
        const Row(
          children: <Widget>[
            Expanded(child: _Field('Opened on', 'Today')),
            _gapW,
            Expanded(child: _Field('Use within (days)', '3')),
          ],
        ),
        _gapSm,
        const _Note('The app uses the earlier of the two dates.'),
      ],
    );

Widget _itemDetail(BuildContext context) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Toor Dal', style: context.akText.titleLarge),
        _gapSm,
        const Row(
          children: <Widget>[
            Expanded(child: _Btn('Use', icon: Icons.remove_rounded)),
            _gapW,
            Expanded(
              child: _Btn('Add stock', icon: Icons.add_rounded, filled: false),
            ),
          ],
        ),
        _gap,
        const _Title('Batches'),
        _gapSm,
        const _BatchRow('Bought 1 Nov', '2 kg left', StatusKind.fresh, null),
        _gapSm,
        const _BatchRow(
          'Bought 20 Oct',
          '500 g left',
          StatusKind.expiring,
          'In 2 days',
        ),
      ],
    );

class _BatchRow extends StatelessWidget {
  const _BatchRow(this.title, this.subtitle, this.kind, this.label);

  final String title;
  final String subtitle;
  final StatusKind kind;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: context.akText.titleSmall),
                _Note(subtitle),
              ],
            ),
          ),
          StatusChip(kind: kind, label: label),
        ],
      ),
    );
  }
}

Widget _useSheet(BuildContext context) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            _Pill('¼'),
            _Pill('½'),
            _Pill('1', selected: true),
          ],
        ),
        _gapSm,
        const Row(
          children: <Widget>[
            Expanded(child: _Field('Amount', '1')),
            _gapW,
            Expanded(child: _Field('Unit', 'kg')),
          ],
        ),
        _gapSm,
        const _Field('Reason', 'Used'),
        _gap,
        Row(
          children: <Widget>[
            Flexible(
              child: Text(
                'Use all',
                style: context.akText.labelLarge!.copyWith(
                  color: context.akColors.primary,
                ),
              ),
            ),
            _gapW,
            const Flexible(child: _Btn('Use')),
          ],
        ),
      ],
    );

Widget _otherNames() => const Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _Field('Other names (Telugu, Hindi, ...)', 'biyyam, chawal'),
        _gapSm,
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            _Pill('బియ్యం'),
            _Pill('biyyam'),
            _Pill('चावल'),
            _Pill('chawal'),
          ],
        ),
        _gapSm,
        _Note('Searching any of these now finds Rice.'),
      ],
    );

Widget _barcodeScan(BuildContext context) {
  final AkshayaColors colors = context.akColors;
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      SizedBox(
        height: AppSizes.scanFrameHeight,
        width: double.infinity,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surfaceAlt,
            borderRadius: AppRadius.controlBorder,
            border: Border.all(
              color: colors.primary,
              width: AppSizes.scanFrameBorder,
            ),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.qr_code_scanner_rounded,
                  size: AppSizes.iconXl,
                  color: colors.primary,
                ),
                _gapSm,
                Text(
                  'Hold the barcode inside the frame',
                  textAlign: TextAlign.center,
                  style: context.akText.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ),
      _gapSm,
      const Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        alignment: WrapAlignment.center,
        children: <Widget>[
          _Pill('Torch', icon: Icons.flashlight_on_rounded),
          _Pill('Type the barcode', icon: Icons.keyboard_rounded),
        ],
      ),
    ],
  );
}

Widget _cookedFood() => const Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            _Pill('Stocked'),
            _Pill('Cooked', selected: true),
            _Pill('Homemade'),
          ],
        ),
        _gapSm,
        ItemCard(
          name: 'Sambar',
          subtitle: 'Cooked · Fridge · 3 portions left · steel dabba',
          icon: Icons.soup_kitchen_rounded,
          status: StatusKind.expiring,
          statusLabel: 'Use by tomorrow',
        ),
      ],
    );

// --------------------------------------------------------------- Shopping

Widget _shoppingList(BuildContext context) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const _Title('Vegetables (2)'),
        _gapSm,
        ChecklistCard(
          title: 'Tomato',
          subtitle: '1 kg',
          checked: false,
          onChanged: (bool _) {},
        ),
        _gapSm,
        ChecklistCard(
          title: 'Onion',
          subtitle: '2 kg · Urgent',
          checked: false,
          onChanged: (bool _) {},
        ),
        _gap,
        const _Title('In basket (1)'),
        _gapSm,
        ChecklistCard(
          title: 'Curd',
          subtitle: '1 packet',
          checked: true,
          onChanged: (bool _) {},
        ),
        _gap,
        const Align(
          alignment: Alignment.centerRight,
          child: _Btn('Done shopping (1)', icon: Icons.check_rounded),
        ),
      ],
    );

Widget _suggestions(BuildContext context) => const Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _Title('Suggested for you (2)'),
        _gapSm,
        _SuggestionRow('Tomato', 'Out of stock · buy 1 kg'),
        _gapSm,
        _SuggestionRow('Onion', 'Low stock · buy 2 kg'),
        _gapSm,
        Align(
          alignment: Alignment.centerLeft,
          child: _Btn('Add all', filled: false),
        ),
      ],
    );

class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow(this.name, this.reason);

  final String name;
  final String reason;

  @override
  Widget build(BuildContext context) {
    final AkshayaColors colors = context.akColors;
    return _Card(
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(name, style: context.akText.titleSmall),
                _Note(reason),
              ],
            ),
          ),
          Icon(Icons.add_circle_rounded, color: colors.primary),
          _gapW,
          Icon(Icons.close_rounded, color: colors.textSecondary),
        ],
      ),
    );
  }
}

Widget _repeatEntry(BuildContext context) => const Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _Field('Repeat', 'Every week'),
        _Note('Comes back on the list after you buy it'),
        _gap,
        _Title('Repeats later (1)'),
        _gapSm,
        ChecklistCard(
          title: 'Milk',
          subtitle: 'Back on 13 Nov',
          checked: false,
        ),
        _gap,
        _Card(
          tint: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('You buy Atta about every 14 days.'),
              _gapSm,
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: <Widget>[
                  _Btn('Use every 14 days'),
                  _Btn('Keep mine', filled: false),
                ],
              ),
            ],
          ),
        ),
      ],
    );

Widget _doneShopping(BuildContext context) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const _Field('Store (optional)', 'DMart'),
        _gapSm,
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Atta · 5 kg', style: context.akText.titleSmall),
              _gapSm,
              _expiryPills(selected: '+6 months'),
              _gapSm,
              const _Field('Price paid (optional)', '1,250'),
            ],
          ),
        ),
        _gap,
        const Align(
          alignment: Alignment.centerRight,
          child: _Btn('Confirm'),
        ),
      ],
    );

Widget _shareText(BuildContext context) => _Card(
      tint: true,
      child: Text(
        'Shopping list\n\nVegetables\n- Tomato: 1 kg\n- Onion: 2 kg\n\n'
        'Dairy\n- Curd: 1 packet',
        style: context.akText.bodyMedium,
      ),
    );

// ------------------------------------------------------------------ Voice

Widget _commandCard(BuildContext context) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const _Note('What was heard'),
        Text(
          'rendu kilo biyyam add cheyyi',
          style: context.akText.bodyLarge,
        ),
        _gapSm,
        const _Card(
          child: _SettingRow(
            icon: Icons.add_rounded,
            title: 'Rice · 2 kg',
            subtitle: 'Add to pantry',
          ),
        ),
        _gapSm,
        const _Note('Understood on your phone'),
        _gap,
        Row(
          children: <Widget>[
            Flexible(
              child: Text(
                'Change words',
                style: context.akText.labelLarge!.copyWith(
                  color: context.akColors.primary,
                ),
              ),
            ),
            _gapW,
            const Flexible(child: _Btn('Confirm')),
          ],
        ),
      ],
    );

Widget _voiceExamples(BuildContext context) => Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (final String phrase in const <String>[
          'add 1 litre milk, 6 eggs and half kilo tomatoes',
          'rendu kilo biyyam add cheyyi',
          'do kilo chawal list mein daalo',
          'milk ayipoyindi',
          'rice inka 3 kilo undi',
        ]) ...<Widget>[
          _Card(
            child: Row(
              children: <Widget>[
                Icon(Icons.mic_rounded, color: context.akColors.primary),
                _gapW,
                Expanded(child: Text(phrase, style: context.akText.bodyMedium)),
              ],
            ),
          ),
          _gapSm,
        ],
      ],
    );

Widget _settingsAi(BuildContext context) => _settingsCard(<Widget>[
      _SettingRow(
        icon: Icons.auto_awesome_rounded,
        title: 'Use AI for hard-to-read commands',
        trailing: _switch(),
      ),
      const _SettingRow(
        icon: Icons.speed_rounded,
        title: 'Daily AI limit',
        subtitle: 'Offline mode takes over after the limit',
      ),
      const _SettingRow(
        icon: Icons.bar_chart_rounded,
        title: 'AI calls today: 3 of 50',
      ),
      _SettingRow(
        icon: Icons.translate_rounded,
        title: 'Voice language',
        subtitle: 'Words shown in the app are always English.',
        trailing: _valueText(context, 'English'),
      ),
    ]);

// ----------------------------------------------------------------- Alerts

Widget _notification(
  BuildContext context, {
  required String title,
  required String body,
  required List<String> actions,
}) {
  final AkshayaColors colors = context.akColors;
  return _Card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(
              Icons.notifications_active_rounded,
              size: AppSizes.iconSm,
              color: colors.primary,
            ),
            _gapW,
            Text('Akshaya Patra', style: context.akText.labelMedium),
          ],
        ),
        _gapSm,
        Text(title, style: context.akText.titleSmall),
        Text(body, style: context.akText.bodyMedium),
        if (actions.isNotEmpty) ...<Widget>[
          _gapSm,
          Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.xs,
            children: <Widget>[
              for (final String action in actions)
                Text(
                  action,
                  style: context.akText.labelLarge!.copyWith(
                    color: colors.primary,
                  ),
                ),
            ],
          ),
        ],
      ],
    ),
  );
}

Widget _settingsAlerts(BuildContext context) => _settingsCard(<Widget>[
      _SettingRow(
        icon: Icons.notifications_active_rounded,
        title: 'Daily alert',
        trailing: _switch(),
      ),
      _SettingRow(
        icon: Icons.schedule_rounded,
        title: 'Alert time',
        subtitle: 'Asia/Kolkata (India) time',
        trailing: _valueText(context, '8:00 am'),
      ),
      _SettingRow(
        icon: Icons.nights_stay_rounded,
        title: 'Quiet hours',
        trailing: _switch(),
      ),
      _SettingRow(
        icon: Icons.groups_rounded,
        title: 'Household changes',
        subtitle: 'When another member changes the shared lists',
        trailing: _switch(),
      ),
    ]);

// ---------------------------------------------------------------- Recipes

Widget _recipeIdeas(BuildContext context) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const _Title('Use these first'),
        _gapSm,
        const Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            _Pill('Curd · tomorrow'),
            _Pill('Spinach · 2 days'),
          ],
        ),
        _gapSm,
        const _Card(
          tint: true,
          child: Text('Vegetarian · South Indian · 30 min · 4 people'),
        ),
        _gapSm,
        _Card(
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text('Palak kadhi', style: context.akText.titleSmall),
              ),
              const StatusChip(
                kind: StatusKind.expiring,
                label: 'Uses 2 expiring',
              ),
            ],
          ),
        ),
        _gapSm,
        _Card(
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text('Curd rice', style: context.akText.titleSmall),
              ),
              const StatusChip(kind: StatusKind.fresh, label: 'Ready to cook'),
            ],
          ),
        ),
        _gap,
        const _Btn('Get recipe ideas', icon: Icons.auto_awesome_rounded),
      ],
    );

Widget _recipeDetail(BuildContext context) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Palak kadhi', style: context.akText.titleLarge),
        _gapSm,
        const _Title('Ingredients'),
        _gapSm,
        for (final line in const <(String, StatusKind, String)>[
          ('Spinach 200 g', StatusKind.fresh, 'In pantry'),
          ('Curd 1 cup', StatusKind.lowStock, 'Short'),
          ('Besan 2 tbsp', StatusKind.outOfStock, 'Missing'),
        ]) ...<Widget>[
          Row(
            children: <Widget>[
              Expanded(child: Text(line.$1, style: context.akText.bodyLarge)),
              StatusChip(kind: line.$2, label: line.$3),
            ],
          ),
          _gapSm,
        ],
        const Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            _Btn('Add missing', filled: false),
            _Btn('I cooked this'),
          ],
        ),
      ],
    );

Widget _preferencesSheet(BuildContext context) => const Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            _Pill('Vegetarian', selected: true),
            _Pill('Eggetarian'),
            _Pill('Non-vegetarian'),
          ],
        ),
        _gapSm,
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            _Pill('20 min'),
            _Pill('30 min', selected: true),
            _Pill('45 min'),
          ],
        ),
        _gapSm,
        _Field('Allergies or foods to avoid', 'peanuts, mushroom'),
        _gap,
        _Btn('Save preferences'),
      ],
    );

Widget _mealPlan(BuildContext context) {
  final AkshayaColors colors = context.akColors;
  Widget day(String name, List<(String, String?)> slots) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(name, style: context.akText.titleSmall),
          _gapSm,
          for (final slot in slots)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                children: <Widget>[
                  SizedBox(
                    width: 84,
                    child: Text(
                      slot.$1,
                      style: context.akText.labelMedium!.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      slot.$2 ?? '+ Add',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.akText.bodyMedium!.copyWith(
                        color: slot.$2 == null
                            ? colors.primary
                            : colors.textPrimary,
                      ),
                    ),
                  ),
                  if (slot.$2 == 'Rajma masala')
                    Icon(
                      Icons.notifications_active_rounded,
                      size: AppSizes.iconSm,
                      color: colors.primary,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  return Column(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Icon(Icons.chevron_left_rounded, color: colors.textSecondary),
          Text('This week', style: context.akText.titleMedium),
          Icon(Icons.chevron_right_rounded, color: colors.textSecondary),
        ],
      ),
      _gapSm,
      day('Monday', const <(String, String?)>[
        ('Breakfast', 'Pesarattu'),
        ('Lunch', 'Rice and sambar'),
        ('Dinner', null),
      ]),
      _gapSm,
      day('Tuesday', const <(String, String?)>[
        ('Breakfast', null),
        ('Lunch', 'Outside'),
        ('Dinner', 'Rajma masala'),
      ]),
      _gap,
      const _Btn(
        'Generate shopping list',
        icon: Icons.shopping_basket_rounded,
        filled: false,
      ),
    ],
  );
}

// ----------------------------------------------------------------- Rescue

Widget _foodRescue(BuildContext context) => const Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _Title('Food rescue'),
        _gapSm,
        _Note('Expires today (1)'),
        _gapSm,
        ItemCard(
          name: 'Paneer',
          subtitle: 'Fridge · 200 g left',
          icon: Icons.restaurant_rounded,
          status: StatusKind.expiring,
          statusLabel: 'Today',
        ),
        _gapSm,
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            _Pill('Use', icon: Icons.check_rounded),
            _Pill('Cook something', icon: Icons.soup_kitchen_rounded),
            _Pill('Freeze', icon: Icons.ac_unit_rounded),
            _Pill('Mark wasted', icon: Icons.delete_outline_rounded),
          ],
        ),
        _gap,
        _Note('Leftovers (1)'),
        _gapSm,
        ItemCard(
          name: 'Sambar',
          subtitle: 'Cooked · Fridge · 3 portions left',
          icon: Icons.soup_kitchen_rounded,
          status: StatusKind.fresh,
          statusLabel: 'In 2 days',
        ),
      ],
    );

Widget _settingsFreeze(BuildContext context) => _settingsCard(<Widget>[
      _SettingRow(
        icon: Icons.ac_unit_rounded,
        title: 'Offer Freeze',
        subtitle: 'Keeps in the freezer (days)',
        trailing: _switch(),
      ),
      _SettingRow(
        icon: Icons.category_rounded,
        title: 'Each category has its own days',
        trailing: _chevron(context),
      ),
    ]);

Widget _wasteReasons(BuildContext context) {
  final AkshayaColors colors = context.akColors;
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      for (final String reason in const <String>[
        'Expired',
        'Spoiled',
        'Forgot about it',
        'Bought too much',
        'Other',
      ])
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
          child: Row(
            children: <Widget>[
              Icon(
                reason == 'Expired'
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: reason == 'Expired'
                    ? colors.primary
                    : colors.textSecondary,
              ),
              _gapW,
              Expanded(child: Text(reason, style: context.akText.bodyLarge)),
            ],
          ),
        ),
      _gapSm,
      const Align(
        alignment: Alignment.centerRight,
        child: _Btn('Mark wasted'),
      ),
    ],
  );
}

Widget _insights(BuildContext context) {
  final AkshayaColors colors = context.akColors;
  const List<double> heights = <double>[28, 44, 36, 60, 48, 72];
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Icon(Icons.chevron_left_rounded, color: colors.textSecondary),
          Text('November', style: context.akText.titleMedium),
          Icon(Icons.chevron_right_rounded, color: colors.textSecondary),
        ],
      ),
      _gapSm,
      _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Spending', style: context.akText.titleSmall),
            _gapSm,
            SizedBox(
              height: 80,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  for (final double h in heights)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xs,
                        ),
                        child: SizedBox(
                          height: h,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: colors.primary,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(AppSpacing.xs),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            _gapSm,
            const _Note('By category, month by month'),
          ],
        ),
      ),
      _gapSm,
      _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Waste', style: context.akText.titleSmall),
            const _Note('Why: Expired, Forgot about it, Bought too much'),
            _gapSm,
            Text('Money saved', style: context.akText.titleSmall),
            const _Note('Food used before it expired'),
          ],
        ),
      ),
    ],
  );
}

// --------------------------------------------------------------- Planning

Widget _countCard(BuildContext context) => Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const LinearProgressIndicator(value: 0.4),
        _gap,
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Rice', style: context.akText.titleLarge),
              const _Note('The app says 4 kg'),
              _gap,
              const Row(
                children: <Widget>[
                  Expanded(child: _Btn('Matches', icon: Icons.check_rounded)),
                  _gapW,
                  Expanded(child: _Btn('Change', filled: false)),
                ],
              ),
              _gapSm,
              Center(
                child: Text(
                  'Finished: none left',
                  style: context.akText.labelLarge!.copyWith(
                    color: context.akColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        _gapSm,
        const _Note('Swipe right for Matches, left for Later'),
      ],
    );

Widget _settingsCount(BuildContext context) => _settingsCard(<Widget>[
      const _SettingRow(
        icon: Icons.fact_check_rounded,
        title: 'Count the shelf',
      ),
      _SettingRow(
        icon: Icons.event_repeat_rounded,
        title: 'Monthly count reminder',
        trailing: _switch(),
      ),
      _SettingRow(
        icon: Icons.calendar_month_rounded,
        title: 'Remind me on day',
        subtitle: 'Day of the month (1 to 28)',
        trailing: _valueText(context, '1'),
      ),
    ]);

Widget _runsOut(BuildContext context) {
  final AkshayaColors colors = context.akColors;
  Widget forecast(String text) => Padding(
        padding: const EdgeInsets.only(top: AppSpacing.xs),
        child: Row(
          children: <Widget>[
            Icon(Icons.schedule_rounded, size: AppSizes.iconSm, color: colors.primary),
            _gapW,
            Expanded(child: Text(text, style: context.akText.bodyMedium)),
          ],
        ),
      );
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      const ItemCard(
        name: 'Milk',
        subtitle: 'Fridge · 2 L left',
        icon: Icons.local_drink_rounded,
        status: StatusKind.fresh,
      ),
      forecast('Runs out in ~3 days'),
      _gap,
      const ItemCard(
        name: 'Atta',
        subtitle: 'Pantry · 3 kg left',
        icon: Icons.grain_rounded,
        status: StatusKind.fresh,
      ),
      forecast('Learning: 2 of 3 days'),
    ],
  );
}

Widget _whatToBuy(BuildContext context) {
  final AkshayaColors colors = context.akColors;
  Widget row(String name, String detail) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: _Card(
          child: Row(
            children: <Widget>[
              Icon(Icons.check_box_rounded, color: colors.primary),
              _gapW,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(name, style: context.akText.titleSmall),
                    _Note(detail),
                  ],
                ),
              ),
              Icon(Icons.remove_rounded, color: colors.textSecondary),
              _gapW,
              Icon(Icons.add_rounded, color: colors.textSecondary),
            ],
          ),
        ),
      );
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Text('Running out within', style: context.akText.labelLarge),
      _gapSm,
      const Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: <Widget>[
          _Pill('3 days'),
          _Pill('7 days', selected: true),
          _Pill('14 days'),
          _Pill('30 days'),
        ],
      ),
      _gapSm,
      row('Milk', 'Buy 2 L · runs out in ~3 days'),
      row('Atta', 'Buy 5 kg · runs out in ~6 days'),
      const _Btn('Add 2 to the list', icon: Icons.add_shopping_cart_rounded),
    ],
  );
}

// ------------------------------------------------------------- Household

Widget _signIn(BuildContext context) => _settingsCard(<Widget>[
      _SettingRow(
        icon: Icons.login_rounded,
        title: 'Sign in to share with your household',
        subtitle: 'Optional. The app works fully without it.',
        trailing: _chevron(context),
      ),
      _SettingRow(
        icon: Icons.groups_rounded,
        title: 'Create or join a household',
        subtitle: 'Not in a household yet',
        trailing: _chevron(context),
      ),
    ]);

Widget _household(BuildContext context) {
  final AkshayaColors colors = context.akColors;
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      const _Title('Invite someone'),
      _gapSm,
      Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          DecoratedBox(
            decoration: const BoxDecoration(
              color: AkshayaColors.qrBackground,
              borderRadius: AppRadius.controlBorder,
            ),
            child: const Padding(
              padding: EdgeInsets.all(AppSpacing.sm),
              child: Icon(
                Icons.qr_code_2_rounded,
                size: 72,
                color: AkshayaColors.qrForeground,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'ABCD-2345',
                  style: context.akText.titleLarge!.copyWith(
                    letterSpacing: 2,
                  ),
                ),
                _gapSm,
                const Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: <Widget>[
                    _Pill('Copy', icon: Icons.content_copy_rounded),
                    _Pill('New code'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      _gap,
      const _Title('Members'),
      _gapSm,
      _settingsCard(const <Widget>[
        _SettingRow(
          icon: Icons.person_rounded,
          title: 'You',
          subtitle: 'Owner',
        ),
        _SettingRow(
          icon: Icons.person_rounded,
          title: 'Priya',
          subtitle: 'Member',
        ),
      ]),
      _gapSm,
      Text(
        'Everyone in the household sees the same pantry.',
        style: context.akText.bodySmall!.copyWith(color: colors.textSecondary),
      ),
    ],
  );
}

Widget _syncStatus(BuildContext context) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _settingsCard(<Widget>[
          _SettingRow(
            icon: Icons.sync_rounded,
            title: 'Sync with household',
            trailing: _switch(),
          ),
        ]),
        _gapSm,
        const Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            _Pill('Synced', icon: Icons.cloud_done_rounded),
            _Btn('Sync now', icon: Icons.sync_rounded, filled: false),
          ],
        ),
      ],
    );

// ----------------------------------------------------------------- Travel

Widget _tripBanner(BuildContext context) {
  final AkshayaColors colors = context.akColors;
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      _Card(
        tint: true,
        child: Row(
          children: <Widget>[
            Icon(Icons.luggage_rounded, color: colors.primary),
            _gapW,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Goa', style: context.akText.titleSmall),
                  const _Note('Leaving tomorrow · back in 4 days'),
                ],
              ),
            ),
          ],
        ),
      ),
      _gap,
      const _Title('Will not last until you are back'),
      _gapSm,
      const ItemCard(
        name: 'Spinach',
        subtitle: 'Fridge · 200 g left',
        icon: Icons.eco_rounded,
        status: StatusKind.expiring,
        statusLabel: 'In 2 days',
      ),
      _gapSm,
      const Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: <Widget>[
          _Pill('Use'),
          _Pill('Freeze'),
          _Pill('Give away'),
          _Pill('Mark wasted'),
        ],
      ),
    ],
  );
}

Widget _homeWidget(BuildContext context) {
  final AkshayaColors colors = context.akColors;
  Widget widgetBox(Widget child) => DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: AppRadius.cardBorder,
          border: Border.all(color: colors.outline, width: AppSizes.borderWidth),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: SizedBox(width: double.infinity, child: child),
        ),
      );
  Widget tickRow(String text, {required bool ticked}) => Padding(
        padding: const EdgeInsets.only(top: AppSpacing.xs),
        child: Row(
          children: <Widget>[
            Icon(
              ticked
                  ? Icons.check_box_rounded
                  : Icons.check_box_outline_blank_rounded,
              size: AppSizes.iconMd,
              color: colors.primary,
            ),
            _gapW,
            Expanded(child: Text(text, style: context.akText.bodyMedium)),
          ],
        ),
      );
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      widgetBox(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Shopping list', style: context.akText.titleSmall),
            tickRow('Tomato · 1 kg', ticked: false),
            tickRow('Onion · 2 kg', ticked: false),
            tickRow('Curd · 1 packet', ticked: true),
          ],
        ),
      ),
      _gapSm,
      widgetBox(
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            Icon(Icons.mic_rounded, color: colors.primary),
            Icon(Icons.qr_code_scanner_rounded, color: colors.primary),
            Icon(Icons.add_rounded, color: colors.primary),
          ],
        ),
      ),
    ],
  );
}

Widget _appShortcuts(BuildContext context) => const _Card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _SettingRow(icon: Icons.mic_rounded, title: 'Voice add'),
          _SettingRow(
            icon: Icons.qr_code_scanner_rounded,
            title: 'Scan barcode',
          ),
          _SettingRow(
            icon: Icons.shopping_basket_rounded,
            title: 'Shopping list',
          ),
        ],
      ),
    );

// --------------------------------------------------------------- Settings

Widget _themeCards(BuildContext context) {
  final AkshayaColors colors = context.akColors;
  const List<(IconData, String)> items = <(IconData, String)>[
    (Icons.brightness_auto_rounded, 'Follow phone'),
    (Icons.light_mode_rounded, 'Light'),
    (Icons.dark_mode_rounded, 'Dark'),
  ];
  return Row(
    children: <Widget>[
      for (int i = 0; i < items.length; i++) ...<Widget>[
        if (i > 0) _gapW,
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: i == 0 ? colors.surfaceAlt : colors.surface,
              borderRadius: AppRadius.cardBorder,
              border: Border.all(
                color: i == 0 ? colors.primary : colors.outline,
                width: AppSizes.borderWidth,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(items[i].$1, color: colors.primary),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    items[i].$2,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.akText.labelSmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ],
  );
}

Widget _settingsGeneral(BuildContext context) => _settingsCard(<Widget>[
      _SettingRow(
        icon: Icons.currency_rupee_rounded,
        title: 'Currency',
        trailing: _valueText(context, '₹'),
      ),
      _SettingRow(
        icon: Icons.scale_rounded,
        title: 'Default unit',
        subtitle: 'Used when adding a new item',
        trailing: _valueText(context, 'kg'),
      ),
      _SettingRow(
        icon: Icons.tune_rounded,
        title: 'Diet and recipe preferences',
        subtitle: 'Veg, cuisine, allergies, cooking time',
        trailing: _chevron(context),
      ),
    ]);

Widget _settingsCategories(BuildContext context) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _settingsCard(<Widget>[
          const _SettingRow(icon: Icons.eco_rounded, title: 'Vegetables'),
          const _SettingRow(icon: Icons.grain_rounded, title: 'Dals & Pulses'),
          const _SettingRow(
            icon: Icons.local_fire_department_rounded,
            title: 'Spices & Masalas',
          ),
        ]),
        _gapSm,
        const _Pill('Add category', icon: Icons.add_rounded),
      ],
    );

Widget _settingsLock(BuildContext context) => Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _settingsCard(<Widget>[
          _SettingRow(
            icon: Icons.lock_rounded,
            title: 'App lock',
            subtitle: 'Ask for fingerprint, face or screen lock',
            trailing: _switch(),
          ),
        ]),
        _gap,
        Icon(
          Icons.fingerprint_rounded,
          size: AppSizes.iconXl,
          color: context.akColors.primary,
        ),
        _gapSm,
        const _Btn('Unlock'),
      ],
    );

Widget _settingsBackup(BuildContext context) => _settingsCard(const <Widget>[
      _SettingRow(
        icon: Icons.download_rounded,
        title: 'Save a backup',
        subtitle: 'Everything in one JSON file',
      ),
      _SettingRow(
        icon: Icons.upload_file_rounded,
        title: 'Restore from a backup',
        subtitle: 'Merges with what is on this phone',
      ),
      _SettingRow(
        icon: Icons.table_chart_rounded,
        title: 'Export pantry as CSV',
      ),
      _SettingRow(
        icon: Icons.history_rounded,
        title: 'Export usage history as CSV',
      ),
    ]);

Widget _settingsSample(BuildContext context) => _settingsCard(const <Widget>[
      _SettingRow(
        icon: Icons.science_outlined,
        title: 'Load sample data',
        subtitle: 'Adds 10 common Indian grocery items',
      ),
    ]);
