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
    private var observer: ViewTreeObserver? = null
    private var closed = false
    private val preDraw = ViewTreeObserver.OnPreDrawListener { reveal(); true }
    private val attachment = object : View.OnAttachStateChangeListener {
        override fun onViewAttachedToWindow(view: View) { observe() }
        override fun onViewDetachedFromWindow(view: View) {
            observer?.takeIf { it.isAlive }?.removeOnPreDrawListener(preDraw)
            observer = null
        }
    }

    init {
        root.addOnAttachStateChangeListener(attachment)
        observe()
        reveal()
    }

    private fun observe() {
        observer?.takeIf { it.isAlive }?.removeOnPreDrawListener(preDraw)
        observer = root.viewTreeObserver.takeIf { it.isAlive }
        observer?.addOnPreDrawListener(preDraw)
    }

    private fun reveal() {
        if (closed || !enabled()) return
        val current = controls()
        presented.keys.retainAll(current.map { it.identity }.toSet())
        val visible = current.mapNotNull { control ->
            val view = control.view
            if (!view.isShown) presented.remove(control.identity)
            if (presented.containsKey(control.identity) && presented[control.identity] == control.state) return@mapNotNull null
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
        if (once && current.all { presented.containsKey(it.identity) }) close()
    }

    override fun close() {
        closed = true
        observer?.takeIf { it.isAlive }?.removeOnPreDrawListener(preDraw)
        observer = null
        root.removeOnAttachStateChangeListener(attachment)
        presented.clear()
    }
}
