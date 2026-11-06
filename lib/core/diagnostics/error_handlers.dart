import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'diag.dart';

/// Sends every error that reaches Flutter's top level to the diagnostics log:
/// errors in widgets (build, layout, paint) and errors thrown in async code
/// that nothing caught. Call once from `main()` after the binding exists.
void installDiagnosticsErrorHandlers() {
  final FlutterExceptionHandler? previous = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    final String where = details.library == null
        ? 'Flutter error'
        : 'Flutter error in ${details.library}';
    Diag.error(
      'flutter',
      where,
      error: details.exception,
      stack: details.stack,
    );
    // Keep Flutter's own console report.
    if (previous != null) {
      previous(details);
    } else {
      FlutterError.presentError(details);
    }
  };

  WidgetsBinding.instance.platformDispatcher.onError =
      (Object error, StackTrace stack) {
    Diag.error('uncaught', 'Unhandled error', error: error, stack: stack);
    // Handled: the app keeps running, as it did before.
    return true;
  };
}

/// Notes each page, dialog and sheet that opens or closes ("what was the
/// person doing"). Route names are not set in this app, so the route's type is
/// used.
class DiagNavigatorObserver extends NavigatorObserver {
  String _label(Route<dynamic>? route) {
    if (route == null) {
      return 'none';
    }
    final String? name = route.settings.name;
    return name ?? route.runtimeType.toString();
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    Diag.info('nav', 'open ${_label(route)}');
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    Diag.info('nav', 'close ${_label(route)}');
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    Diag.info('nav', 'replace ${_label(oldRoute)} with ${_label(newRoute)}');
  }
}
