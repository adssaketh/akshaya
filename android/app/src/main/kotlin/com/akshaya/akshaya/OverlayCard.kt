package com.akshaya.akshaya

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView

/** Fires when a scheduled alert is due and shows the floating card. */
class OverlayReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val app = context.applicationContext
        if (!DeviceBridge.prefs(app).getBoolean(DeviceBridge.KEY_OVERLAY, false)) return
        if (!DeviceBridge.canDraw(app)) return
        val title = intent.getStringExtra("title") ?: return
        val body = intent.getStringExtra("body") ?: ""
        // Keep the receiver alive while the card is on screen.
        val pending = goAsync()
        Handler(Looper.getMainLooper()).post {
            try {
                OverlayCard.show(app, title, body) { pending.finish() }
            } catch (e: Exception) {
                pending.finish()
            }
        }
    }
}

/** A small card drawn over other apps. Tap opens Akshaya Patra; x closes it. */
object OverlayCard {
    private const val SHOW_MILLIS = 12_000L
    private val handler = Handler(Looper.getMainLooper())
    private var current: View? = null
    private var dismissTask: Runnable? = null
    private var onDone: (() -> Unit)? = null

    @Suppress("DEPRECATION")
    fun show(app: Context, title: String, body: String, done: () -> Unit) {
        remove(app)
        onDone = done

        val density = app.resources.displayMetrics.density
        fun dp(v: Int) = (v * density).toInt()
        val dark = (app.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) ==
            Configuration.UI_MODE_NIGHT_YES
        val background = if (dark) 0xFF2B2522.toInt() else 0xFFFFFFFF.toInt()
        val stroke = if (dark) 0xFF4A413C.toInt() else 0xFFE6DDD5.toInt()
        val strong = if (dark) 0xFFF5EDE6.toInt() else 0xFF2B2522.toInt()
        val soft = if (dark) 0xFFCFC3BA.toInt() else 0xFF5C524B.toInt()
        val accent = 0xFFC8553D.toInt()

        val titleView = TextView(app).apply {
            text = title
            setTextColor(accent)
            setTypeface(typeface, Typeface.BOLD)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
        }
        val closeView = TextView(app).apply {
            text = "\u2715"
            setTextColor(soft)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
            setPadding(dp(12), 0, 0, 0)
            setOnClickListener { remove(app); finish() }
        }
        val header = LinearLayout(app).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            addView(titleView, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
            addView(closeView)
        }
        val bodyView = TextView(app).apply {
            text = body
            setTextColor(strong)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 15f)
            maxLines = 6
            setPadding(0, dp(4), 0, 0)
        }
        val card = LinearLayout(app).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(16), dp(12), dp(16), dp(14))
            this.background = GradientDrawable().apply {
                setColor(background)
                cornerRadius = dp(20).toFloat()
                setStroke(dp(1), stroke)
            }
            addView(header)
            addView(bodyView)
            setOnClickListener {
                app.packageManager.getLaunchIntentForPackage(app.packageName)?.let {
                    it.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    try {
                        app.startActivity(it)
                    } catch (_: Exception) {
                    }
                }
                remove(app)
                finish()
            }
        }

        val statusId = app.resources.getIdentifier("status_bar_height", "dimen", "android")
        val statusBar = if (statusId > 0) app.resources.getDimensionPixelSize(statusId) else dp(24)
        val host = FrameLayout(app).apply {
            setPadding(dp(12), statusBar + dp(8), dp(12), 0)
            addView(
                card,
                FrameLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.WRAP_CONTENT,
                ),
            )
        }

        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            WindowManager.LayoutParams.TYPE_PHONE
        }
        val params = WindowManager.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.WRAP_CONTENT,
            type,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT,
        ).apply { gravity = Gravity.TOP }

        val wm = app.getSystemService(Context.WINDOW_SERVICE) as WindowManager
        wm.addView(host, params)
        current = host

        val task = Runnable { remove(app); finish() }
        dismissTask = task
        handler.postDelayed(task, SHOW_MILLIS)
    }

    private fun finish() {
        val done = onDone
        onDone = null
        done?.invoke()
    }

    private fun remove(app: Context) {
        dismissTask?.let { handler.removeCallbacks(it) }
        dismissTask = null
        val view = current ?: return
        current = null
        try {
            (app.getSystemService(Context.WINDOW_SERVICE) as WindowManager).removeView(view)
        } catch (_: Exception) {
        }
    }
}
