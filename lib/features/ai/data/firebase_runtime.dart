import 'dart:async';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

import '../../../core/diagnostics/diag.dart';

/// Firebase settings for this build, passed with `--dart-define` (the CI
/// workflow derives them from the `GOOGLE_SERVICES_JSON` secret). This avoids
/// the google-services Gradle plugin and keeps keys out of the repository.
abstract final class FirebaseBuildConfig {
  static const String apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const String appId = String.fromEnvironment('FIREBASE_APP_ID');
  static const String projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const String senderId = String.fromEnvironment('FIREBASE_SENDER_ID');

  /// The OAuth web client id Google sign-in needs (Phase 6). Optional: without
  /// it email/password sign-in still works.
  static const String webClientId =
      String.fromEnvironment('FIREBASE_WEB_CLIENT_ID');

  /// A fixed App Check debug token (a random UUID registered under App Check,
  /// Manage debug tokens, in the Firebase console), passed with
  /// `--dart-define=APP_CHECK_DEBUG_TOKEN=...`. A phone that installs the APK
  /// directly (not from Google Play) cannot pass Play Integrity, so without
  /// this the AI calls fail with `firebase_app_check/unknown`.
  static const String appCheckDebugToken =
      String.fromEnvironment('APP_CHECK_DEBUG_TOKEN');

  static bool get isConfigured =>
      apiKey.isNotEmpty &&
      appId.isNotEmpty &&
      projectId.isNotEmpty &&
      senderId.isNotEmpty;
}

/// Remote Config key holding the Gemini model name, so it can change without a
/// new build.
const String kGeminiModelKey = 'gemini_model_name';

/// Used until Remote Config has been fetched, and when it cannot be.
const String kDefaultGeminiModel = 'gemini-3.8-flash';

/// Which App Check provider a build uses.
enum AppCheckMode {
  /// The debug provider with the fixed token from the build.
  fixedDebugToken,

  /// The debug provider with a token the plugin makes up and prints in the
  /// log (debug builds that run from a computer).
  debug,

  /// Play Integrity: needs an app that Google Play recognises.
  playIntegrity,
}

/// The fixed token wins whenever the build has one, in any build type.
AppCheckMode chooseAppCheckMode({
  required bool debugBuild,
  required String debugToken,
}) {
  if (debugToken.trim().isNotEmpty) {
    return AppCheckMode.fixedDebugToken;
  }
  return debugBuild ? AppCheckMode.debug : AppCheckMode.playIntegrity;
}

/// Starts Firebase on first use (never at app start), so the app opens at the
/// same speed with or without AI.
class FirebaseRuntime {
  FirebaseRuntime();

  Future<void>? _starting;

  /// Initialises Firebase, App Check and Remote Config once. Throws when the
  /// build has no Firebase configuration or start-up fails.
  Future<void> ensureReady() {
    return _starting ??= _start().catchError((Object error) {
      _starting = null;
      throw error;
    });
  }

  Future<void> _start() async {
    if (!FirebaseBuildConfig.isConfigured) {
      throw StateError('Firebase is not configured in this build.');
    }
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: FirebaseBuildConfig.apiKey,
          appId: FirebaseBuildConfig.appId,
          messagingSenderId: FirebaseBuildConfig.senderId,
          projectId: FirebaseBuildConfig.projectId,
        ),
      );
    }
    final AppCheckMode mode = chooseAppCheckMode(
      debugBuild: kDebugMode,
      debugToken: FirebaseBuildConfig.appCheckDebugToken,
    );
    try {
      await FirebaseAppCheck.instance.activate(
        providerAndroid: switch (mode) {
          AppCheckMode.fixedDebugToken => AndroidDebugProvider(
              debugToken: FirebaseBuildConfig.appCheckDebugToken.trim(),
            ),
          AppCheckMode.debug => const AndroidDebugProvider(),
          AppCheckMode.playIntegrity => const AndroidPlayIntegrityProvider(),
        },
      );
      Diag.info('ai', 'App Check started (${mode.name})');
    } on Object catch (error) {
      // Without App Check the AI calls are refused by the server when
      // enforcement is on; that surfaces as a normal AI failure. The kind of
      // error is logged (never the token) so the cause can be found.
      Diag.warn(
        'ai',
        'App Check could not start (${mode.name}): ${error.runtimeType}',
      );
    }
    try {
      final FirebaseRemoteConfig config = FirebaseRemoteConfig.instance;
      await config.setDefaults(<String, Object>{
        kGeminiModelKey: kDefaultGeminiModel,
      });
      await config.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          minimumFetchInterval: const Duration(hours: 12),
        ),
      );
      await config.fetchAndActivate();
    } on Object {
      // The default model name is used.
    }
  }

  /// The Gemini model to call, from Remote Config.
  String modelName() {
    try {
      final String name =
          FirebaseRemoteConfig.instance.getString(kGeminiModelKey).trim();
      return name.isEmpty ? kDefaultGeminiModel : name;
    } on Object {
      return kDefaultGeminiModel;
    }
  }
}
