import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/diagnostics/app_info.dart';
import 'core/diagnostics/diag.dart';
import 'core/diagnostics/error_handlers.dart';
import 'features/alerts/presentation/providers.dart';
import 'features/pantry/presentation/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Errors are caught from here on, and the diagnostics log is ready before
  // the first screen so nothing at start-up is missed.
  installDiagnosticsErrorHandlers();
  await Diag.init();
  unawaited(_logSessionStart());
  runApp(
    ProviderScope(
      overrides: [
        // The pantry's "expiring soon" window is the saved alert setting, so
        // the Pantry list and the daily alert always agree.
        expiryWarningDaysProvider.overrideWith(
          (Ref ref) => ref.watch(savedWarningDaysProvider),
        ),
      ],
      child: const AkshayaApp(),
    ),
  );
}

/// First line of every run, so a log shows where one session ends and the next
/// begins (two starts with nothing in between often means a crash).
Future<void> _logSessionStart() async {
  final AppInfo info = await AppInfo.load();
  Diag.info(
    'app',
    'Session start: ${info.versionLabel} ${info.mode}, ${info.device}, '
        '${info.system}',
  );
}
