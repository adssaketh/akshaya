package com.akshaya.akshaya

import android.os.Build
import io.flutter.embedding.android.FlutterFragmentActivity

// local_auth (the biometric app lock) needs a FragmentActivity.
class MainActivity : FlutterFragmentActivity() {
    override fun onResume() {
        super.onResume()
        requestHighestRefreshRate()
    }

    // Many phones keep apps at 60 Hz unless the app asks for more. Ask for the
    // fastest mode with the same resolution, so scrolling and animations run at
    // 90 or 120 Hz where the screen supports it. The system may still lower it
    // in battery saver.
    @Suppress("DEPRECATION")
    private fun requestHighestRefreshRate() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
        val display = windowManager.defaultDisplay ?: return
        val current = display.mode
        val best = display.supportedModes
            .filter {
                it.physicalWidth == current.physicalWidth &&
                    it.physicalHeight == current.physicalHeight
            }
            .maxByOrNull { it.refreshRate } ?: return
        val params = window.attributes
        if (params.preferredDisplayModeId == best.modeId) return
        params.preferredDisplayModeId = best.modeId
        params.preferredRefreshRate = best.refreshRate
        window.attributes = params
    }
}
