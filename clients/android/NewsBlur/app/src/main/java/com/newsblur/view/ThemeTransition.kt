package com.newsblur.view

import android.animation.ValueAnimator
import android.app.Activity
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.os.Handler
import android.os.Looper
import android.view.ViewGroup
import android.view.animation.DecelerateInterpolator
import androidx.core.view.doOnPreDraw
import com.newsblur.util.ViewUtils
import java.util.UUID

/** ThemeTransition.kt carries a drawing, never an Activity, across theme recreation. */
object ThemeTransition {
    private val frames = mutableMapOf<String, Bitmap>()
    private val handler by lazy { Handler(Looper.getMainLooper()) }
    private val revealing = java.util.Collections.newSetFromMap(java.util.WeakHashMap<android.view.View, Boolean>())

    fun isRevealing(view: android.view.View): Boolean = revealing.contains(view.rootView)
    private class Cover(val decor: ViewGroup, val ghost: BitmapDrawable, val ready: () -> Boolean)
    private val covers = mutableListOf<Cover>()
    private var waitingSince = 0L

    private val revealWhenReady = object : Runnable {
        override fun run() {
            if (covers.isEmpty()) return
            // ThemeTransition.kt waits for committed rows in every recreated tablet pane.
            if ((frames.isNotEmpty() || covers.any { !it.ready() }) &&
                android.os.SystemClock.uptimeMillis() - waitingSince < 1500) {
                handler.postDelayed(this, 16)
                return
            }
            val batch = covers.toList()
            covers.clear()
            ValueAnimator.ofInt(255, 0).apply {
                duration = 300
                interpolator = DecelerateInterpolator()
                addUpdateListener { animation -> batch.forEach { it.ghost.alpha = animation.animatedValue as Int } }
                addListener(object : android.animation.AnimatorListenerAdapter() {
                    override fun onAnimationEnd(animation: android.animation.Animator) {
                        batch.forEach { it.decor.overlay.remove(it.ghost); revealing.remove(it.decor) }
                    }
                })
                start()
            }
        }
    }

    fun capture(activity: Activity): String? {
        val decor = activity.window?.decorView ?: return null
        if (!decor.isShown || decor.width == 0 || decor.height == 0 ||
            !ValueAnimator.areAnimatorsEnabled() || ViewUtils.isPowerSaveMode(activity)) return null
        // ThemeTransition.kt caps temporary memory on large tablets without changing the layout.
        val scale = minOf(1f, 1600f / maxOf(decor.width, decor.height))
        val bitmap = try {
            Bitmap.createBitmap((decor.width * scale).toInt(), (decor.height * scale).toInt(), Bitmap.Config.ARGB_8888)
                .also { decor.draw(Canvas(it).apply { scale(scale, scale) }) }
        } catch (_: OutOfMemoryError) { return null }
        val token = UUID.randomUUID().toString()
        frames[token] = bitmap
        handler.postDelayed({ frames.remove(token) }, 5000)
        return token
    }

    fun reveal(activity: Activity, token: String?, ready: () -> Boolean): Boolean {
        val bitmap = frames.remove(token) ?: return false
        val decor = activity.window.decorView as? ViewGroup ?: return false
        if (!ValueAnimator.areAnimatorsEnabled() || ViewUtils.isPowerSaveMode(activity)) return false
        val ghost = BitmapDrawable(activity.resources, bitmap)
        revealing.add(decor)
        decor.doOnPreDraw {
            ghost.setBounds(0, 0, decor.width, decor.height)
            decor.overlay.add(ghost)
            if (covers.isEmpty()) waitingSince = android.os.SystemClock.uptimeMillis()
            covers.add(Cover(decor, ghost, ready))
            handler.removeCallbacks(revealWhenReady)
            decor.postOnAnimation { handler.post(revealWhenReady) }
        }
        return true
    }
}
