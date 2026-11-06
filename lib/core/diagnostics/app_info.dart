import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Which build is running and on what phone. Nothing here identifies a person.
@immutable
final class AppInfo {
  const AppInfo({
    required this.version,
    required this.build,
    required this.mode,
    required this.device,
    required this.system,
    required this.locale,
  });

  /// "1.0.8"
  final String version;

  /// "9"
  final String build;

  /// release, profile or debug.
  final String mode;

  /// "Google Pixel 7"
  final String device;

  /// "Android 15 (API 35)"
  final String system;

  /// "en_IN"
  final String locale;

  String get versionLabel => '$version+$build';

  /// Label and value pairs, in the order they are shown and reported.
  List<MapEntry<String, String>> rows() => <MapEntry<String, String>>[
        MapEntry<String, String>('App', versionLabel),
        MapEntry<String, String>('Build', mode),
        MapEntry<String, String>('Phone', device),
        MapEntry<String, String>('System', system),
        MapEntry<String, String>('Language', locale),
      ];

  static String get _mode =>
      kReleaseMode ? 'release' : (kProfileMode ? 'profile' : 'debug');

  /// Reads the real values. Any part that cannot be read becomes "unknown".
  static Future<AppInfo> load() async {
    String version = 'unknown';
    String build = '?';
    try {
      final PackageInfo info = await PackageInfo.fromPlatform();
      version = info.version;
      build = info.buildNumber;
    } on Object {
      // Keep the placeholders.
    }
    String device = 'unknown';
    String system = Platform.operatingSystemVersion;
    try {
      final AndroidDeviceInfo info = await DeviceInfoPlugin().androidInfo;
      device = '${info.manufacturer} ${info.model}';
      system = 'Android ${info.version.release} (API ${info.version.sdkInt})';
    } on Object {
      // Keep the placeholders.
    }
    return AppInfo(
      version: version,
      build: build,
      mode: _mode,
      device: device,
      system: system,
      locale: Platform.localeName,
    );
  }
}

/// Loads [AppInfo] once. Tests override it with a fixed value.
final FutureProvider<AppInfo> appInfoProvider = FutureProvider<AppInfo>(
  (Ref ref) => AppInfo.load(),
);
