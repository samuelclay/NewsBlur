package com.newsblur.view

import android.content.Context
import android.util.AttributeSet
import android.view.View
import androidx.coordinatorlayout.widget.CoordinatorLayout
import androidx.core.view.ViewCompat
import com.google.android.material.appbar.AppBarLayout

/** ReaderToolbarBehavior.kt keeps small reverse movements from revealing the reader controls. */
internal class ReaderToolbarRevealGate(private val threshold: Int) {
    private var reverseDistance = 0

    fun reset() {
        reverseDistance = 0
    }

    fun filter(dy: Int, touch: Boolean, hidden: Boolean, atTop: Boolean): Int {
        if (dy == 0) return 0
        if (dy > 0) {
            reset()
            return dy
        }
        if (atTop) return dy
        if (!touch) return 0
        if (!hidden) return dy
        val before = reverseDistance
        reverseDistance += -dy
        return -(reverseDistance - maxOf(before, threshold)).coerceAtLeast(0)
    }
}

class ReaderToolbarBehavior(context: Context, attrs: AttributeSet?) : AppBarLayout.Behavior(context, attrs) {
    private val revealGate = ReaderToolbarRevealGate((30 * context.resources.displayMetrics.density).toInt())

    override fun onStartNestedScroll(
        parent: CoordinatorLayout,
        child: AppBarLayout,
        directTargetChild: View,
        target: View,
        nestedScrollAxes: Int,
        type: Int,
    ): Boolean {
        if (type == ViewCompat.TYPE_TOUCH) revealGate.reset()
        return super.onStartNestedScroll(parent, child, directTargetChild, target, nestedScrollAxes, type)
    }

    override fun onNestedPreScroll(
        coordinatorLayout: CoordinatorLayout,
        child: AppBarLayout,
        target: View,
        dx: Int,
        dy: Int,
        consumed: IntArray,
        type: Int,
    ) {
        val delta = revealGate.filter(
            dy,
            touch = type == ViewCompat.TYPE_TOUCH,
            hidden = topAndBottomOffset <= -child.totalScrollRange,
            atTop = !target.canScrollVertically(-1),
        )
        super.onNestedPreScroll(coordinatorLayout, child, target, dx, delta, consumed, type)
    }
}
