import 'dart:ui' show FrameTiming, PlatformDispatcher;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'diag.dart';

/// Measures how smoothly the app draws and writes short summaries to the
/// diagnostics log, so a report shows real numbers instead of "it feels
/// slow":
///
/// * how long after start the first screen was on the display;
/// * the first few seconds after start (where most stutter happens);
/// * each stretch the app was open, written when it goes to the background.
///
/// A frame is counted as slow when building it or drawing it took longer
/// than one refresh of the screen (8.3 ms at 120 Hz, 16.7 ms at 60 Hz).
/// Flutter hands the timings over in batches, so watching them costs next to
/// nothing.
abstract final class FrameStats {
  /// How long after the first frame the start-up summary is written.
  static const Duration startupWindow = Duration(seconds: 4);

  static bool _started = false;
  static bool _inStartup = true;
  static _Window _window = _Window();

  /// Starts measuring. Call once, from main(), before runApp. The first line
  /// is written only after [after] (the session-start line), so a log still
  /// reads in order.
  static void start({Future<void>? after}) {
    if (_started) {
      return;
    }
    _started = true;
    final Stopwatch sinceMain = Stopwatch()..start();
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
    WidgetsBinding.instance.waitUntilFirstFrameRasterized.then((_) async {
      final int firstMs = sinceMain.elapsedMilliseconds;
      try {
        await after;
      } on Object {
        // The order of two log lines is not worth an error.
      }
      Diag.info('perf', 'First screen drawn $firstMs ms after start');
      Future<void>.delayed(startupWindow, () {
        _write('Start-up (first ${startupWindow.inSeconds} s)');
        _inStartup = false;
      });
    });
  }

  /// Writes the frames since the last summary (if any) and starts a new
  /// stretch. Called when the app goes to the background.
  static void flush(String label) {
    if (!_started || _inStartup) {
      return;
    }
    _write(label);
  }

  static void _write(String label) {
    final _Window w = _window;
    _window = _Window();
    if (w.frames == 0) {
      return;
    }
    final double hz = _refreshRate();
    final double pct = w.slow * 100 / w.frames;
    Diag.info(
      'perf',
      '$label: ${w.frames} frames at ${hz.round()} Hz, '
          '${w.slow} slow (${pct.toStringAsFixed(1)}%), '
          'worst build ${w.worstBuildMs.toStringAsFixed(1)} ms, '
          'worst draw ${w.worstRasterMs.toStringAsFixed(1)} ms',
    );
  }

  static double _refreshRate() {
    try {
      final double hz =
          PlatformDispatcher.instance.views.first.display.refreshRate;
      return hz > 0 ? hz : 60;
    } on Object {
      return 60;
    }
  }

  static void _onTimings(List<FrameTiming> timings) {
    final double budgetMs = 1000 / _refreshRate();
    final _Window w = _window;
    for (final FrameTiming t in timings) {
      final double build = t.buildDuration.inMicroseconds / 1000;
      final double raster = t.rasterDuration.inMicroseconds / 1000;
      w.frames++;
      if (build > budgetMs || raster > budgetMs) {
        w.slow++;
      }
      if (build > w.worstBuildMs) {
        w.worstBuildMs = build;
      }
      if (raster > w.worstRasterMs) {
        w.worstRasterMs = raster;
      }
    }
  }
}

class _Window {
  int frames = 0;
  int slow = 0;
  double worstBuildMs = 0;
  double worstRasterMs = 0;
}
