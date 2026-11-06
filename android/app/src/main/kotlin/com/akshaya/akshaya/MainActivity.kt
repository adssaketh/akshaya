package com.akshaya.akshaya

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.UUID

// local_auth (the biometric app lock) needs a FragmentActivity.
class MainActivity : FlutterFragmentActivity() {
    private var shareChannel: MethodChannel? = null

    // Pictures copied from the share sheet, waiting for Dart to take them.
    private val pending = mutableListOf<String>()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "akshaya/share")
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "take" -> synchronized(pending) {
                    val paths = pending.toList()
                    pending.clear()
                    result.success(paths)
                }
                else -> result.notImplemented()
            }
        }
        shareChannel = channel
        collectShared(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        collectShared(intent)
    }

    // Copies shared pictures into the cache (the sender's permission to read
    // them ends with this intent) and tells Dart they are ready.
    private fun collectShared(source: Intent?) {
        val sent = source ?: return
        val uris = ArrayList<Uri>()
        when (sent.action) {
            Intent.ACTION_SEND -> {
                @Suppress("DEPRECATION")
                val uri = if (Build.VERSION.SDK_INT >= 33) {
                    sent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
                } else {
                    sent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
                }
                if (uri != null) uris.add(uri)
            }
            Intent.ACTION_SEND_MULTIPLE -> {
                @Suppress("DEPRECATION")
                val list = if (Build.VERSION.SDK_INT >= 33) {
                    sent.getParcelableArrayListExtra(Intent.EXTRA_STREAM, Uri::class.java)
                } else {
                    sent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)
                }
                if (list != null) uris.addAll(list)
            }
            else -> return
        }
        // Handle each share once, even if the activity is recreated.
        sent.action = null
        if (uris.isEmpty()) return
        val folder = File(cacheDir, "shared_orders").apply { mkdirs() }
        Thread {
            val copied = mutableListOf<String>()
            for (uri in uris.take(MAX_PICTURES)) {
                try {
                    val target = File(folder, "${UUID.randomUUID()}.img")
                    contentResolver.openInputStream(uri)?.use { input ->
                        target.outputStream().use { output -> input.copyTo(output) }
                    } ?: continue
                    copied.add(target.absolutePath)
                } catch (_: Exception) {
                    // A picture that cannot be read is skipped.
                }
            }
            if (copied.isEmpty()) return@Thread
            synchronized(pending) { pending.addAll(copied) }
            Handler(Looper.getMainLooper()).post {
                shareChannel?.invokeMethod("shared", null)
            }
        }.start()
    }

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

    private companion object {
        const val MAX_PICTURES = 6
    }
}
