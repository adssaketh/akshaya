import 'package:flutter/services.dart';

/// One floating-card alert the phone should show at [at] (epoch millis).
final class OverlayAlert {
  const OverlayAlert({
    required this.id,
    required this.title,
    required this.body,
    required this.at,
  });

  final int id;
  final String title;
  final String body;
  final int at;

  Map<String, Object> toMap() => <String, Object>{
        'id': id,
        'title': title,
        'body': body,
        'at': at,
      };
}

/// Small native features that no plugin covers: the floating alert card shown
/// over other apps, and muting the speech recogniser's start/end beeps.
///
/// Every call is safe to make anywhere: where the native side is missing (unit
/// tests, the background worker's engine, non-Android) it quietly does nothing.
abstract final class DeviceBridge {
  static const MethodChannel _channel = MethodChannel('akshaya/device');

  static Future<Map<String, Object?>?> _map(String method, [Object? args]) async {
    try {
      return await _channel.invokeMapMethod<String, Object?>(method, args);
    } on Object {
      return null;
    }
  }

  static Future<void> _fire(String method, [Object? args]) async {
    try {
      await _channel.invokeMethod<void>(method, args);
    } on Object {
      // Not available on this engine: nothing to do.
    }
  }

  // ---- Display over other apps ------------------------------------------

  /// [enabled] is the person's switch; [granted] is Android's "Display over
  /// other apps" permission.
  static Future<({bool enabled, bool granted})> overlayState() async {
    final Map<String, Object?>? m = await _map('overlayState');
    return (enabled: m?['enabled'] == true, granted: m?['granted'] == true);
  }

  static Future<void> setOverlayEnabled(bool enabled) =>
      _fire('overlaySetEnabled', enabled);

  /// Opens Android's "Display over other apps" screen for this app.
  static Future<void> requestOverlayPermission() =>
      _fire('overlayRequestPermission');

  /// Replaces every scheduled floating card with [alerts].
  static Future<void> scheduleOverlays(List<OverlayAlert> alerts) => _fire(
        'overlaySchedule',
        <Map<String, Object>>[for (final OverlayAlert a in alerts) a.toMap()],
      );

  static Future<void> cancelOverlays() => _fire('overlayCancel');

  /// Shows the floating card now (only if the switch is on and permitted).
  static Future<void> showOverlayNow(String title, String body) => _fire(
        'overlayShowNow',
        <String, String>{'title': title, 'body': body},
      );

  // ---- Microphone beeps -------------------------------------------------

  static Future<({bool muteStart, bool muteEnd})> micState() async {
    final Map<String, Object?>? m = await _map('micState');
    return (
      muteStart: m?['muteStart'] == true,
      muteEnd: m?['muteEnd'] == true,
    );
  }

  static Future<void> setMic({
    required bool muteStart,
    required bool muteEnd,
  }) =>
      _fire('micSet', <String, bool>{
        'muteStart': muteStart,
        'muteEnd': muteEnd,
      });

  /// Call just before listening starts / after it ends. Both are no-ops when
  /// the person has not asked to silence either beep.
  static Future<void> micBegin() => _fire('micBegin');

  static Future<void> micEnd() => _fire('micEnd');
}
