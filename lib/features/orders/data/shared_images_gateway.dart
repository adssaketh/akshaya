import 'dart:async';

import 'package:flutter/services.dart';

/// Pictures other apps shared to Akshaya Patra (Android share menu).
abstract interface class SharedImagesGateway {
  /// Pictures that arrived since the last call, as file paths in the app's
  /// cache. Each path is returned once.
  Future<List<String>> take();

  /// Fires when new pictures arrive while the app is open.
  Stream<void> get arrivals;
}

/// Talks to MainActivity over the `akshaya/share` channel. The native side
/// copies each shared picture into the cache folder and keeps the paths until
/// Dart takes them.
final class ChannelSharedImagesGateway implements SharedImagesGateway {
  ChannelSharedImagesGateway() {
    _channel.setMethodCallHandler((MethodCall call) async {
      if (call.method == 'shared') {
        _arrivals.add(null);
      }
      return null;
    });
  }

  static const MethodChannel _channel = MethodChannel('akshaya/share');
  final StreamController<void> _arrivals = StreamController<void>.broadcast();

  @override
  Stream<void> get arrivals => _arrivals.stream;

  @override
  Future<List<String>> take() async {
    try {
      final List<Object?>? paths =
          await _channel.invokeListMethod<Object?>('take');
      return <String>[
        for (final Object? p in paths ?? const <Object?>[])
          if (p is String) p,
      ];
    } on MissingPluginException {
      return const <String>[];
    } on PlatformException {
      return const <String>[];
    }
  }
}
