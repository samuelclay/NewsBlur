package com.newsblur.activity

import android.view.View
import android.view.ViewGroup
import android.view.ViewTreeObserver
import android.widget.FrameLayout

/** ReaderEndControls.kt moves the existing traversal strip into the active story's footer. */
internal class ReaderEndControls(
    private val floatingHost: FrameLayout,
    private val controls: View,
    private val activeFooter: () -> FrameLayout?,
    private val onDockChanged: () -> Unit,
) {
    private val originalParams = controls.layoutParams
    private val hostLocation = IntArray(2)
    private val footerLocation = IntArray(2)
    private var dockedFooter: FrameLayout? = null
    private var registeredObserver: ViewTreeObserver? = null

    val isDocked: Boolean get() = dockedFooter != null

    private val footerAttachment = object : View.OnAttachStateChangeListener {
        override fun onViewAttachedToWindow(view: View) = Unit

        override fun onViewDetachedFromWindow(view: View) {
            if (view === dockedFooter) moveTo(null)
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
            moveTo(null)
            return
        }
        floatingHost.getLocationOnScreen(hostLocation)
        footer.getLocationOnScreen(footerLocation)
        // ReaderEndControls.kt reveals the inline row as soon as it enters the viewport, even partially.
        // The host bottom stays fixed when its strip moves out; its margin restores the window edge.
        val bottomMargin = (floatingHost.layoutParams as? ViewGroup.MarginLayoutParams)?.bottomMargin ?: 0
        val viewportBottom = hostLocation[1] + floatingHost.height + bottomMargin - floatingHost.paddingBottom
        moveTo(if (footerLocation[1] < viewportBottom) footer else null)
    }

    fun close() {
        floatingHost.removeOnAttachStateChangeListener(hostAttachment)
        unregister()
        moveTo(null)
    }

    private fun moveTo(footer: FrameLayout?) {
        if (footer === dockedFooter) return
        dockedFooter?.removeOnAttachStateChangeListener(footerAttachment)
        (controls.parent as? ViewGroup)?.removeView(controls)
        (footer ?: floatingHost).addView(controls, originalParams)
        dockedFooter = footer
        footer?.addOnAttachStateChangeListener(footerAttachment)
        onDockChanged()
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
