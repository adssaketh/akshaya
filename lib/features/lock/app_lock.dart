import 'dart:async';

import 'package:akshaya/core/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../settings/domain/app_settings.dart';
import '../settings/presentation/providers.dart';

/// Asks the phone to confirm the person (fingerprint, face or screen lock).
abstract interface class AppAuthenticator {
  /// False when the phone has no screen lock or biometrics, so the app cannot
  /// be locked (and must never lock itself).
  Future<bool> isAvailable();

  /// True when the person proved who they are.
  Future<bool> authenticate(String reason);
}

/// [AppAuthenticator] on top of `local_auth`.
final class LocalAuthAuthenticator implements AppAuthenticator {
  LocalAuthAuthenticator([LocalAuthentication? auth])
      : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<bool> isAvailable() async {
    try {
      return await _auth.isDeviceSupported();
    } on Object {
      return false;
    }
  }

  @override
  Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        persistAcrossBackgrounding: true,
      );
    } on Object {
      return false;
    }
  }
}

final Provider<AppAuthenticator> appAuthenticatorProvider =
    Provider<AppAuthenticator>((Ref ref) => LocalAuthAuthenticator());

/// Covers the app with a lock screen while the app lock is on and the person
/// has not unlocked it. The app locks again whenever it goes to the
/// background.
class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate> {
  late final AppLifecycleListener _lifecycle;
  bool _locked = true;
  bool _checking = false;
  bool _tried = false;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onHide: () {
        // Ignore the system's own dialog: the prompt hides the app too.
        if (!_checking && ref.read(appSettingsProvider).appLock) {
          setState(() {
            _locked = true;
            _tried = false;
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _unlock() async {
    if (_checking) {
      return;
    }
    setState(() {
      _checking = true;
      _tried = true;
    });
    final AppAuthenticator auth = ref.read(appAuthenticatorProvider);
    bool ok = true;
    if (await auth.isAvailable()) {
      ok = await auth.authenticate('Unlock Akshaya Patra');
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _checking = false;
      if (ok) {
        _locked = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Narrow watches: the lock only cares whether settings have loaded and
    // whether the lock is on, not about every other setting that changes.
    final bool stillLoading = ref.watch(
      settingsMapProvider.select(
        (AsyncValue<Map<String, String>> v) => v.isLoading && !v.hasValue,
      ),
    );
    final bool enabled =
        ref.watch(appSettingsProvider.select((AppSettings s) => s.appLock));
    if (stillLoading) {
      return ColoredBox(color: context.akColors.background);
    }
    final bool showLock = enabled && _locked;
    if (showLock && !_tried && !_checking) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _locked && !_tried) {
          unawaited(_unlock());
        }
      });
    }
    // The app stays mounted underneath (so screens keep their state) but is
    // hidden and cannot be reached while locked.
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Offstage(offstage: showLock, child: widget.child),
        if (showLock) _LockScreen(busy: _checking, onUnlock: _unlock),
      ],
    );
  }
}

class _LockScreen extends StatelessWidget {
  const _LockScreen({required this.busy, required this.onUnlock});

  final bool busy;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    final AkshayaColors colors = context.akColors;
    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const AkshayaLogo(size: AppSizes.sarukuluEmpty),
                const SizedBox(height: AppSpacing.lg),
                Text('Akshaya Patra is locked', style: context.akText.titleLarge),
                const SizedBox(height: AppSpacing.xl),
                FilledButton.icon(
                  onPressed: busy ? null : onUnlock,
                  icon: const Icon(Icons.lock_open_rounded),
                  label: const Text('Unlock'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Used by Settings: the lock switch text depends on what the phone offers.
String appLockUnavailableMessage() =>
    'Set a screen lock or fingerprint in your phone settings first.';
