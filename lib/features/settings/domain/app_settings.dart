import '../../pantry/domain/unit.dart';

/// Keys of the general settings (stored per phone, never synced).
abstract final class AppSettingKeys {
  static const String theme = 'app.theme';
  static const String currency = 'app.currency';
  static const String defaultUnit = 'app.default_unit';
  static const String appLock = 'app.lock';
  static const String animations = 'app.animations';
  static const String wallpaperTheme = 'app.wallpaper_theme';
  static const String barStyle = 'app.bar_style';
  static const String glassAlpha = 'app.glass_alpha';
  static const String glassBlur = 'app.glass_blur';
  static const String glassEdge = 'app.glass_edge';
}

/// Light, dark, or follow the phone.
enum AppThemeChoice {
  system('system', 'Follow phone'),
  light('light', 'Light'),
  dark('dark', 'Dark');

  const AppThemeChoice(this.key, this.label);

  final String key;
  final String label;

  static AppThemeChoice fromKey(String? text) {
    for (final AppThemeChoice c in AppThemeChoice.values) {
      if (c.key == text) {
        return c;
      }
    }
    return AppThemeChoice.system;
  }
}

/// The floating navigation bar: a solid colour, or frosted glass that lets
/// the page show through.
enum BarStyle {
  solid('solid', 'Solid'),
  glass('glass', 'Glass');

  const BarStyle(this.key, this.label);

  final String key;
  final String label;

  static BarStyle fromKey(String? text) {
    for (final BarStyle s in BarStyle.values) {
      if (s.key == text) {
        return s;
      }
    }
    return BarStyle.solid;
  }
}

/// How strongly the glass blurs what is behind it. [px] is the CSS-style blur
/// radius; Flutter's Gaussian sigma is half of it.
enum GlassBlur {
  soft('soft', 'Soft', 10),
  medium('medium', 'Medium', 18),
  strong('strong', 'Strong', 28);

  const GlassBlur(this.key, this.label, this.px);

  final String key;
  final String label;
  final double px;

  double get sigma => px / 2;

  static GlassBlur fromKey(String? text) {
    for (final GlassBlur b in GlassBlur.values) {
      if (b.key == text) {
        return b;
      }
    }
    return GlassBlur.strong;
  }
}

/// Glass opacity (percent of the bar colour that stays opaque) is kept
/// between these limits, so the bar is never invisible or fully solid.
const int kGlassAlphaMin = 20;
const int kGlassAlphaMax = 95;
const int kGlassAlphaDefault = 62;

/// Symbols offered for prices.
const List<String> kCurrencyChoices = <String>['₹', r'$', '€', '£'];

/// General settings with their defaults.
final class AppSettings {
  const AppSettings({
    this.theme = AppThemeChoice.system,
    this.currencySymbol = '₹',
    this.defaultUnit = Unit.pcs,
    this.appLock = false,
    this.animations = true,
    this.wallpaperTheme = true,
    this.barStyle = BarStyle.solid,
    this.glassAlpha = kGlassAlphaDefault,
    this.glassBlur = GlassBlur.strong,
    this.glassEdge = true,
  });

  factory AppSettings.fromMap(Map<String, String> values) {
    final String currency = values[AppSettingKeys.currency] ?? '₹';
    return AppSettings(
      theme: AppThemeChoice.fromKey(values[AppSettingKeys.theme]),
      currencySymbol: kCurrencyChoices.contains(currency) ? currency : '₹',
      defaultUnit: _unitFromSymbol(values[AppSettingKeys.defaultUnit]),
      appLock: values[AppSettingKeys.appLock] == 'true',
      animations: values[AppSettingKeys.animations] != 'false',
      wallpaperTheme: values[AppSettingKeys.wallpaperTheme] != 'false',
      barStyle: BarStyle.fromKey(values[AppSettingKeys.barStyle]),
      glassAlpha: (int.tryParse(values[AppSettingKeys.glassAlpha] ?? '') ??
              kGlassAlphaDefault)
          .clamp(kGlassAlphaMin, kGlassAlphaMax),
      glassBlur: GlassBlur.fromKey(values[AppSettingKeys.glassBlur]),
      glassEdge: values[AppSettingKeys.glassEdge] != 'false',
    );
  }

  final AppThemeChoice theme;
  final String currencySymbol;

  /// The unit a new item starts with.
  final Unit defaultUnit;
  final bool appLock;

  /// Whether the app plays its transitions and animations.
  final bool animations;

  /// Whether colours follow the phone's wallpaper (Material 3 Expressive)
  /// when the phone offers wallpaper colours.
  final bool wallpaperTheme;

  /// Navigation bar: solid or glass.
  final BarStyle barStyle;

  /// Glass only: how opaque the bar colour is, in percent (the Settings
  /// slider shows the opposite, "transparency").
  final int glassAlpha;
  final GlassBlur glassBlur;

  /// Glass only: a thin light rim around the bar.
  final bool glassEdge;

  // Value equality matters: every write to the settings table (including the
  // usage counters that sync and AI bump) rebuilds this object, and without
  // equality the whole app would rebuild each time.
  @override
  bool operator ==(Object other) {
    return other is AppSettings &&
        other.theme == theme &&
        other.currencySymbol == currencySymbol &&
        other.defaultUnit == defaultUnit &&
        other.appLock == appLock &&
        other.animations == animations &&
        other.wallpaperTheme == wallpaperTheme &&
        other.barStyle == barStyle &&
        other.glassAlpha == glassAlpha &&
        other.glassBlur == glassBlur &&
        other.glassEdge == glassEdge;
  }

  @override
  int get hashCode =>
      Object.hash(
        theme,
        currencySymbol,
        defaultUnit,
        appLock,
        animations,
        wallpaperTheme,
        barStyle,
        glassAlpha,
        glassBlur,
        glassEdge,
      );

  static Unit _unitFromSymbol(String? symbol) {
    for (final Unit u in Unit.values) {
      if (u.symbol == symbol) {
        return u;
      }
    }
    return Unit.pcs;
  }
}
