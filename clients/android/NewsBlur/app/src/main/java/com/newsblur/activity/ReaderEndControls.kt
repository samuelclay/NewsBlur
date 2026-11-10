package com.newsblur.activity

import android.view.View
import android.view.ViewGroup
import android.view.ViewTreeObserver
import android.widget.FrameLayout

/** ReaderEndControls.kt reveals the fixed traversal strip when the active story's footer is visible. */
internal class ReaderEndControls(
    private val floatingHost: FrameLayout,
    private val activeFooter: () -> FrameLayout?,
    private val onArticleEndChanged: () -> Unit,
) {
    private val hostLocation = IntArray(2)
    private val footerLocation = IntArray(2)
    private var visibleFooter: FrameLayout? = null
    private var registeredObserver: ViewTreeObserver? = null

    val isAtArticleEnd: Boolean get() = visibleFooter != null

    private val footerAttachment = object : View.OnAttachStateChangeListener {
        override fun onViewAttachedToWindow(view: View) = Unit

        override fun onViewDetachedFromWindow(view: View) {
            if (view === visibleFooter) setVisibleFooter(null)
        }
    }

    private val frameListener = ViewTreeObserver.OnPreDrawListener {
        update()
        true
    }

    private val hostAttachment = object : View.OnAttachStateChangeListener {
        override fun onViewAttachedToWindow(view: View) = register()

        override fun onViewDetachedFromWindow(view: View) = unregister()
    }

    fun start() {
        floatingHost.addOnAttachStateChangeListener(hostAttachment)
        if (floatingHost.isAttachedToWindow) register()
    }

    fun update() {
        val footer = activeFooter()
        if (footer == null || !footer.isAttachedToWindow || !footer.isShown || !footer.isLaidOut || !floatingHost.isLaidOut) {
            setVisibleFooter(null)
            return
        }
        floatingHost.getLocationOnScreen(hostLocation)
        footer.getLocationOnScreen(footerLocation)
        // ReaderEndControls.kt reveals the fixed row as soon as the footer enters the safe viewport.
        val bottomMargin = (floatingHost.layoutParams as? ViewGroup.MarginLayoutParams)?.bottomMargin ?: 0
        val viewportBottom = hostLocation[1] + floatingHost.height + bottomMargin - floatingHost.paddingBottom
        setVisibleFooter(if (footerLocation[1] < viewportBottom) footer else null)
    }

    fun close() {
        floatingHost.removeOnAttachStateChangeListener(hostAttachment)
        unregister()
        setVisibleFooter(null)
    }

    private fun setVisibleFooter(footer: FrameLayout?) {
        if (footer === visibleFooter) return
        visibleFooter?.removeOnAttachStateChangeListener(footerAttachment)
        visibleFooter = footer
        footer?.addOnAttachStateChangeListener(footerAttachment)
        onArticleEndChanged()
    }

    private fun register() {
        unregister()
        registeredObserver = floatingHost.viewTreeObserver.also { it.addOnPreDrawListener(frameListener) }
        update()
    }

    private fun unregister() {
        registeredObserver?.takeIf { it.isAlive }?.removeOnPreDrawListener(frameListener)
        registeredObserver = null
    }
}
