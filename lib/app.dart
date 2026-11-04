import 'package:akshaya/core/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/time/clock.dart';
import 'features/shell/app_shell.dart';

class AkshayaApp extends ConsumerStatefulWidget {
  const AkshayaApp({super.key});

  @override
  ConsumerState<AkshayaApp> createState() => _AkshayaAppState();
}

class _AkshayaAppState extends ConsumerState<AkshayaApp> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      // A new day may have started while the app was in the background.
      onResume: () => ref.read(todayProvider.notifier).refresh(),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Akshaya',
      debugShowCheckedModeBanner: false,
      theme: AkshayaTheme.light(),
      darkTheme: AkshayaTheme.dark(),
      themeMode: ThemeMode.system,
      home: const AppShell(),
    );
  }
}
