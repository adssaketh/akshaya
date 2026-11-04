import 'dart:async';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

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
    try {
      // Debug builds use the debug provider (register its token in the
      // Firebase console); release builds use Play Integrity.
      await FirebaseAppCheck.instance.activate(
        providerAndroid: kDebugMode
            ? const AndroidDebugProvider()
            : const AndroidPlayIntegrityProvider(),
      );
    } on Object {
      // Without App Check the AI calls are refused by the server when
      // enforcement is on; that surfaces as a normal AI failure.
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
