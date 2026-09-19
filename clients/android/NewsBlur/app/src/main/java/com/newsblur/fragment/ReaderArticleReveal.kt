package com.newsblur.fragment

import android.view.View

/** ReadingItemFragment.kt keeps Chromium drawing while hiding incomplete article frames. */
internal class ReaderArticleReveal(private val onVisible: () -> Unit) {
    private var view: View? = null
    private var generation = 0L
    private var paused = true
    private var ready = false
    private var animating = false
    var isVisible = false
        private set

    fun prepare(view: View) {
        release()
        this.view = view
        ready = false
        isVisible = false
        view.alpha = 1f / 255f
        view.importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO_HIDE_DESCENDANTS
    }

    fun ready() {
        ready = true
        reveal()
    }

    fun resume() {
        paused = false
        reveal()
    }

    fun pause() {
        paused = true
        generation++
        view?.animate()?.cancel()
        animating = false
        if (!isVisible) view?.alpha = 1f / 255f
    }

    fun release() {
        generation++
        view?.animate()?.cancel()
        view = null
        animating = false
        ready = false
        isVisible = false
    }

    private fun reveal() {
        val target = view ?: return
        if (paused || !ready || isVisible || animating) return
        val token = ++generation
        animating = true
        target.animate().alpha(1f).setDuration(140L).withEndAction {
            // ReaderArticleReveal.kt rejects callbacks queued before pause, replacement, or view destruction.
            if (token == generation && view === target && !paused) {
                animating = false
                isVisible = true
                target.importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_AUTO
                onVisible()
            }
        }.start()
    }
}
