package com.akshaya.akshaya

import android.content.Context
import android.media.AudioManager
import android.os.Build
import android.os.Handler
import android.os.Looper

/**
 * Silences the speech recogniser's start and end beeps by muting sound streams
 * only while the mic is listening, then putting them back. A stream the person
 * had already muted is never touched.
 *
 * Which stream carries the beeps differs between phones and recognisers, so
 * the music, notification and system streams are all muted. Change [STREAMS] if
 * a phone still beeps (or if you would rather not mute music).
 */
object MicBeeps {
    private val STREAMS = intArrayOf(
        AudioManager.STREAM_MUSIC,
        AudioManager.STREAM_NOTIFICATION,
        AudioManager.STREAM_SYSTEM,
    )

    /** The start beep plays within about this long after listening starts. */
    private const val START_WINDOW_MILLIS = 1000L

    /** The end beep can trail the end of listening by a moment. */
    private const val END_TAIL_MILLIS = 1500L

    /** Never leave the phone muted longer than this, whatever happens. */
    private const val FAILSAFE_MILLIS = 45_000L

    private val handler = Handler(Looper.getMainLooper())
    private val mutedByUs = mutableSetOf<Int>()
    private var phase: Runnable? = null
    private var failsafe: Runnable? = null

    fun begin(app: Context, muteStart: Boolean, muteEnd: Boolean) {
        cancelTasks()
        if (!muteStart && !muteEnd) return
        if (muteStart) muteAll(app)
        val step = Runnable {
            if (muteStart && !muteEnd) {
                unmuteAll(app)
            } else if (!muteStart && muteEnd) {
                muteAll(app)
            }
        }
        phase = step
        handler.postDelayed(step, START_WINDOW_MILLIS)
        val safety = Runnable { unmuteAll(app) }
        failsafe = safety
        handler.postDelayed(safety, FAILSAFE_MILLIS)
    }

    fun end(app: Context, muteEnd: Boolean) {
        cancelTasks()
        if (muteEnd) {
            muteAll(app)
            val restore = Runnable { unmuteAll(app) }
            phase = restore
            handler.postDelayed(restore, END_TAIL_MILLIS)
        } else {
            unmuteAll(app)
        }
    }

    /** Called when the activity goes away: never leave sound muted. */
    fun release(app: Context) {
        cancelTasks()
        unmuteAll(app)
    }

    private fun cancelTasks() {
        phase?.let { handler.removeCallbacks(it) }
        failsafe?.let { handler.removeCallbacks(it) }
        phase = null
        failsafe = null
    }

    private fun audio(app: Context) = app.getSystemService(Context.AUDIO_SERVICE) as AudioManager

    private fun muteAll(app: Context) {
        val manager = audio(app)
        for (stream in STREAMS) {
            if (mutedByUs.contains(stream)) continue
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && manager.isStreamMute(stream)) continue
                manager.adjustStreamVolume(stream, AudioManager.ADJUST_MUTE, 0)
                mutedByUs.add(stream)
            } catch (_: Exception) {
                // Some phones refuse (for example in Do Not Disturb): skip it.
            }
        }
    }

    private fun unmuteAll(app: Context) {
        val manager = audio(app)
        for (stream in mutedByUs.toList()) {
            try {
                manager.adjustStreamVolume(stream, AudioManager.ADJUST_UNMUTE, 0)
            } catch (_: Exception) {
            }
        }
        mutedByUs.clear()
    }
}
