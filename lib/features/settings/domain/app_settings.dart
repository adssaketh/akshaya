import '../../pantry/domain/unit.dart';

/// Keys of the general settings (stored per phone, never synced).
abstract final class AppSettingKeys {
  static const String theme = 'app.theme';
  static const String currency = 'app.currency';
  static const String defaultUnit = 'app.default_unit';
  static const String appLock = 'app.lock';
  static const String animations = 'app.animations';
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
  });

  factory AppSettings.fromMap(Map<String, String> values) {
    final String currency = values[AppSettingKeys.currency] ?? '₹';
    return AppSettings(
      theme: AppThemeChoice.fromKey(values[AppSettingKeys.theme]),
      currencySymbol: kCurrencyChoices.contains(currency) ? currency : '₹',
      defaultUnit: _unitFromSymbol(values[AppSettingKeys.defaultUnit]),
      appLock: values[AppSettingKeys.appLock] == 'true',
      animations: values[AppSettingKeys.animations] != 'false',
    );
  }

  final AppThemeChoice theme;
  final String currencySymbol;

  /// The unit a new item starts with.
  final Unit defaultUnit;
  final bool appLock;

  /// Whether the app plays its transitions and animations.
  final bool animations;

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
        other.animations == animations;
  }

  @override
  int get hashCode =>
      Object.hash(theme, currencySymbol, defaultUnit, appLock, animations);

  static Unit _unitFromSymbol(String? symbol) {
    for (final Unit u in Unit.values) {
      if (u.symbol == symbol) {
        return u;
      }
    }
    return Unit.pcs;
  }
}
