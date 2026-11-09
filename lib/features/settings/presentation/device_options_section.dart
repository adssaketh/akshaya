import 'dart:async';

import 'package:akshaya/core/design/design.dart';
import 'package:flutter/material.dart';

import '../../../core/platform/device_bridge.dart';

/// Settings block: alerts as a floating card over other apps, and silencing
/// the microphone's start and end beeps. Both live on the phone (native
/// preferences), never synced.
class DeviceOptionsSection extends StatefulWidget {
  const DeviceOptionsSection({super.key});

  @override
  State<DeviceOptionsSection> createState() => _DeviceOptionsSectionState();
}

class _DeviceOptionsSectionState extends State<DeviceOptionsSection>
    with WidgetsBindingObserver {
  bool _overlayOn = false;
  bool _overlayGranted = false;
  bool _muteStart = false;
  bool _muteEnd = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_load());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Back from Android's permission screen: read the answer again.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    final ({bool enabled, bool granted}) overlay =
        await DeviceBridge.overlayState();
    final ({bool muteStart, bool muteEnd}) mic = await DeviceBridge.micState();
    if (!mounted) {
      return;
    }
    setState(() {
      _overlayOn = overlay.enabled;
      _overlayGranted = overlay.granted;
      _muteStart = mic.muteStart;
      _muteEnd = mic.muteEnd;
    });
  }

  Future<void> _setOverlay(bool on) async {
    setState(() => _overlayOn = on);
    await DeviceBridge.setOverlayEnabled(on);
    if (on && !_overlayGranted) {
      await DeviceBridge.requestOverlayPermission();
    }
    await _load();
  }

  Future<void> _setMic({bool? start, bool? end}) async {
    final bool s = start ?? _muteStart;
    final bool e = end ?? _muteEnd;
    setState(() {
      _muteStart = s;
      _muteEnd = e;
    });
    await DeviceBridge.setMic(muteStart: s, muteEnd: e);
  }

  @override
  Widget build(BuildContext context) {
    final bool active = _overlayOn && _overlayGranted;
    final AkshayaColors colors = context.akColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SectionHeader(title: 'Display over other apps'),
        SwitchListTile(
          secondary: const Icon(Icons.picture_in_picture_alt_rounded),
          title: const Text('Show alerts as a floating card'),
          subtitle: Text(
            _overlayOn && !_overlayGranted
                ? 'Allow "Display over other apps" for Akshaya Patra, then '
                    'come back here.'
                : 'When an alert arrives, a small card appears over '
                    'whatever app you are using.',
          ),
          value: active,
          onChanged: (bool on) => unawaited(_setOverlay(on)),
        ),
        if (_overlayOn && !_overlayGranted)
          ListTile(
            leading: Icon(Icons.warning_amber_rounded, color: colors.primary),
            title: const Text('Permission needed'),
            subtitle: const Text('Open the Android permission screen'),
            onTap: () => unawaited(DeviceBridge.requestOverlayPermission()),
          ),
        if (active)
          ListTile(
            leading: const Icon(Icons.play_circle_outline_rounded),
            title: const Text('Preview the floating card'),
            onTap: () => unawaited(
              DeviceBridge.showOverlayNow(
                'Akshaya Patra',
                'This is how your alerts will look.',
              ),
            ),
          ),
        const SectionHeader(title: 'Microphone sounds'),
        SwitchListTile(
          secondary: const Icon(Icons.volume_off_rounded),
          title: const Text('Silence the sound before listening'),
          subtitle: const Text('Mutes the beep when the mic starts.'),
          value: _muteStart,
          onChanged: (bool on) => unawaited(_setMic(start: on)),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.volume_off_rounded),
          title: const Text('Silence the sound after listening'),
          subtitle: const Text(
            'Mutes the beep when the mic stops. Other sounds on the phone '
            'are muted while the mic is listening.',
          ),
          value: _muteEnd,
          onChanged: (bool on) => unawaited(_setMic(end: on)),
        ),
      ],
    );
  }
}
