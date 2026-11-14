package com.newsblur.view

import android.animation.ValueAnimator
import android.graphics.Rect
import android.view.View
import android.view.ViewTreeObserver
import com.newsblur.util.ViewUtils

/** ReaderControlMotion.kt waits for actual presentation and leaves semantic visibility/disabled alpha intact. */
class ReaderControlMotion(
    private val root: View,
    private val controls: () -> List<Control>,
    private val enabled: () -> Boolean = { true },
    private val once: Boolean = false,
) : AutoCloseable {
    data class Control(val view: View, val identity: Any = view, val state: Any? = null)
    private val presented = mutableMapOf<Any, Any?>()
    private var pending = emptyList<Control>()
    private var dirty = true
    private var observer: ViewTreeObserver? = null
    private var closed = false
    private val preDraw = ViewTreeObserver.OnPreDrawListener { reveal(); true }
    private val layout = ViewTreeObserver.OnGlobalLayoutListener { invalidate() }
    private val attachment = object : View.OnAttachStateChangeListener {
        override fun onViewAttachedToWindow(view: View) { observe() }
        override fun onViewDetachedFromWindow(view: View) {
            unobserve()
        }
    }

    init {
        root.addOnAttachStateChangeListener(attachment)
        observe()
        reveal()
    }

    private fun observe() {
        unobserve()
        observer = root.viewTreeObserver.takeIf { it.isAlive }
        observer?.addOnPreDrawListener(preDraw)
        observer?.addOnGlobalLayoutListener(layout)
        invalidate()
    }

    private fun unobserve() {
        observer?.takeIf { it.isAlive }?.let {
            it.removeOnPreDrawListener(preDraw)
            it.removeOnGlobalLayoutListener(layout)
        }
        observer = null
    }

    /** ReaderControlMotion.kt rebuilds controls after rebinding or layout, never on ordinary animation frames. */
    fun invalidate() { dirty = true }

    private fun reveal() {
        if (closed || !enabled()) return
        if (dirty) {
            dirty = false
            val current = controls()
            presented.keys.retainAll(current.map { it.identity }.toSet())
            pending = current.filter { control ->
                // ReaderControlMotion.kt retains one-shot history even when an earlier pill is subsequently hidden.
                if (!once && !control.view.isShown) presented.remove(control.identity)
                !presented.containsKey(control.identity) || presented[control.identity] != control.state
            }
        }
        if (pending.isEmpty()) {
            if (once) close()
            return
        }
        val visible = pending.mapNotNull { control ->
            val view = control.view
            if (!view.isAttachedToWindow || !view.isShown || view.windowVisibility != View.VISIBLE) return@mapNotNull null
            var ancestor: View? = view
            while (ancestor != null) {
                if (ancestor.visibility != View.VISIBLE || ancestor.alpha <= 0f) return@mapNotNull null
                ancestor = ancestor.parent as? View
            }
            val rect = Rect()
            if (!view.getGlobalVisibleRect(rect)) return@mapNotNull null
            control to rect
        }.sortedWith(compareBy({ it.second.top }, { it.second.left }))
        val step = if (visible.size > 1) minOf(28.0, 150.0 / (visible.size - 1)) else 0.0
        visible.forEachIndexed { index, (control, _) ->
            if (!ValueAnimator.areAnimatorsEnabled() || ViewUtils.isPowerSaveMode(control.view.context) ||
                ReaderMotion.enter(control.view, (index * step).toLong(), 8f)) {
                presented[control.identity] = control.state
            }
        }
        pending = pending.filterNot { presented.containsKey(it.identity) && presented[it.identity] == it.state }
        if (once && pending.isEmpty()) close()
    }

    override fun close() {
        closed = true
        unobserve()
        root.removeOnAttachStateChangeListener(attachment)
        presented.clear()
        pending = emptyList()
    }
}
