package com.akshaya.akshaya

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Native features no plugin covers (Dart side: lib/core/platform/device_bridge.dart):
 * the floating alert card shown over other apps, and muting the speech
 * recogniser's start/end beeps. Switches live in plain SharedPreferences.
 */
object DeviceBridge {
    const val PREFS = "akshaya_device"
    const val KEY_OVERLAY = "overlay_enabled"
    const val KEY_MUTE_START = "mic_mute_start"
    const val KEY_MUTE_END = "mic_mute_end"
    private const val KEY_IDS = "overlay_ids"

    fun prefs(context: Context): SharedPreferences =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun canDraw(context: Context): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.M || Settings.canDrawOverlays(context)

    fun attach(activity: Context, messenger: BinaryMessenger) {
        val app = activity.applicationContext
        MethodChannel(messenger, "akshaya/device").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "overlayState" -> result.success(
                        mapOf(
                            "enabled" to prefs(app).getBoolean(KEY_OVERLAY, false),
                            "granted" to canDraw(app),
                        ),
                    )
                    "overlaySetEnabled" -> {
                        prefs(app).edit().putBoolean(KEY_OVERLAY, call.arguments == true).apply()
                        result.success(null)
                    }
                    "overlayRequestPermission" -> {
                        requestPermission(activity)
                        result.success(null)
                    }
                    "overlaySchedule" -> {
                        schedule(app, call.arguments as? List<*> ?: emptyList<Any>())
                        result.success(null)
                    }
                    "overlayCancel" -> {
                        cancelAll(app)
                        result.success(null)
                    }
                    "overlayShowNow" -> {
                        val args = call.arguments as? Map<*, *>
                        if (prefs(app).getBoolean(KEY_OVERLAY, false) && canDraw(app)) {
                            OverlayCard.show(
                                app,
                                args?.get("title") as? String ?: "",
                                args?.get("body") as? String ?: "",
                            ) {}
                        }
                        result.success(null)
                    }
                    "micState" -> result.success(
                        mapOf(
                            "muteStart" to prefs(app).getBoolean(KEY_MUTE_START, false),
                            "muteEnd" to prefs(app).getBoolean(KEY_MUTE_END, false),
                        ),
                    )
                    "micSet" -> {
                        val args = call.arguments as? Map<*, *>
                        prefs(app).edit()
                            .putBoolean(KEY_MUTE_START, args?.get("muteStart") == true)
                            .putBoolean(KEY_MUTE_END, args?.get("muteEnd") == true)
                            .apply()
                        result.success(null)
                    }
                    "micBegin" -> {
                        MicBeeps.begin(
                            app,
                            prefs(app).getBoolean(KEY_MUTE_START, false),
                            prefs(app).getBoolean(KEY_MUTE_END, false),
                        )
                        result.success(null)
                    }
                    "micEnd" -> {
                        MicBeeps.end(app, prefs(app).getBoolean(KEY_MUTE_END, false))
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("device", e.message, null)
            }
        }
    }

    private fun requestPermission(activity: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
        val intent = Intent(
            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
            Uri.parse("package:${activity.packageName}"),
        ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        activity.startActivity(intent)
    }

    private fun flags(): Int =
        PendingIntent.FLAG_UPDATE_CURRENT or
            (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)

    /** Replaces every pending floating card with the given alerts. */
    private fun schedule(app: Context, items: List<*>) {
        cancelAll(app)
        val alarm = app.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val now = System.currentTimeMillis()
        val ids = mutableSetOf<String>()
        for (raw in items) {
            val m = raw as? Map<*, *> ?: continue
            val id = (m["id"] as? Number)?.toInt() ?: continue
            val at = (m["at"] as? Number)?.toLong() ?: continue
            if (at <= now) continue
            val intent = Intent(app, OverlayReceiver::class.java)
                .putExtra("title", m["title"] as? String ?: "")
                .putExtra("body", m["body"] as? String ?: "")
            val pending = PendingIntent.getBroadcast(app, id, intent, flags())
            // Inexact on purpose: no exact-alarm permission, like the alerts.
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarm.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pending)
            } else {
                alarm.set(AlarmManager.RTC_WAKEUP, at, pending)
            }
            ids.add(id.toString())
        }
        prefs(app).edit().putStringSet(KEY_IDS, ids).apply()
    }

    private fun cancelAll(app: Context) {
        val alarm = app.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val ids = prefs(app).getStringSet(KEY_IDS, emptySet()) ?: emptySet()
        val noCreate = PendingIntent.FLAG_NO_CREATE or
            (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
        for (id in ids) {
            val code = id.toIntOrNull() ?: continue
            val pending = PendingIntent.getBroadcast(
                app,
                code,
                Intent(app, OverlayReceiver::class.java),
                noCreate,
            ) ?: continue
            alarm.cancel(pending)
            pending.cancel()
        }
        prefs(app).edit().remove(KEY_IDS).apply()
    }
}
