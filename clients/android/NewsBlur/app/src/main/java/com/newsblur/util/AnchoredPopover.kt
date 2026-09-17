package com.newsblur.util

import android.graphics.Rect
import android.view.Gravity
import android.view.View
import android.widget.PopupWindow

/** AnchoredPopover.kt reserves space for the original button instead of covering it with a tall menu. */
object AnchoredPopover {
    @JvmStatic fun show(
        anchor: View,
        popup: PopupWindow,
        desiredWidth: Int,
        desiredHeight: Int,
        updating: Boolean = false,
    ) {
        val frame = Rect()
        anchor.getWindowVisibleDisplayFrame(frame)
        val location = IntArray(2)
        anchor.getLocationOnScreen(location)
        val fit =
            FloatingToolbarLayout.popover(
                frame.left,
                frame.top,
                frame.right,
                frame.bottom,
                location[0],
                location[1],
                location[0] + anchor.width,
                location[1] + anchor.height,
                desiredWidth,
                desiredHeight,
                UIUtils.dp2px(anchor.context, 8),
            )
        if (updating) {
            popup.update(fit.x, fit.y, fit.width, fit.height)
        } else {
            popup.width = fit.width
            popup.height = fit.height
            popup.showAtLocation(anchor.rootView, Gravity.TOP or Gravity.LEFT, fit.x, fit.y)
        }
        // AnchoredPopover.kt dismisses stale windows when rotation or keyboard movement moves their anchor.
        val listener =
            View.OnLayoutChangeListener { _, l, t, r, b, ol, ot, or, ob ->
                if (l != ol || t != ot || r != or || b != ob) popup.dismiss()
            }
        anchor.addOnLayoutChangeListener(listener)
        popup.contentView.addOnAttachStateChangeListener(
            object : View.OnAttachStateChangeListener {
                override fun onViewAttachedToWindow(v: View) = Unit

                override fun onViewDetachedFromWindow(v: View) {
                    anchor.removeOnLayoutChangeListener(listener)
                }
            },
        )
    }
}
