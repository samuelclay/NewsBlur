package com.newsblur.util

import android.util.TypedValue
import android.view.View
import android.view.ViewGroup
import android.widget.TextView
import androidx.annotation.VisibleForTesting
import com.google.android.material.button.MaterialButton
import com.newsblur.R
import kotlin.math.roundToInt

object PopupMenuTextScaler {
    private const val MIN_MENU_TEXT_SCALE = 1f
    private const val EXTRA_MIN_HEIGHT_FACTOR = 0.2f

    fun apply(root: View, preferenceScale: Float) {
        val textScale = resolvedTextScale(preferenceScale)
        val minHeightScale = resolvedMinHeightScale(preferenceScale)
        if (textScale == 1f && minHeightScale == 1f) return
        scaleView(root, textScale, minHeightScale)
    }

    @VisibleForTesting
    internal fun resolvedTextScale(preferenceScale: Float): Float = preferenceScale.coerceAtLeast(MIN_MENU_TEXT_SCALE)

    @VisibleForTesting
    internal fun resolvedMinHeightScale(preferenceScale: Float): Float =
        1f + ((resolvedTextScale(preferenceScale) - 1f) * EXTRA_MIN_HEIGHT_FACTOR)

    @VisibleForTesting
    internal fun scaledTextSizePx(
        baseTextSizePx: Float,
        preferenceScale: Float,
    ): Float = baseTextSizePx * resolvedTextScale(preferenceScale)

    @VisibleForTesting
    internal fun scaledMinimumHeightPx(
        baseMinimumHeightPx: Int,
        preferenceScale: Float,
    ): Int {
        if (baseMinimumHeightPx <= 0) return 0
        return (baseMinimumHeightPx * resolvedMinHeightScale(preferenceScale)).roundToInt()
    }

    private fun scaleView(
        view: View,
        textScale: Float,
        minHeightScale: Float,
    ) {
        if (view is TextView) {
            view.setTextSize(TypedValue.COMPLEX_UNIT_PX, view.textSize * textScale)
        }

        if (view is MaterialButton) {
            val fixedHeight = relaxFixedHeight(view)
            scaleMinimumHeight(view, fixedHeight, minHeightScale)
        } else if (view.id == R.id.group_theme) {
            relaxFixedHeight(view)
        }

        if (view is ViewGroup) {
            for (index in 0 until view.childCount) {
                scaleView(view.getChildAt(index), textScale, minHeightScale)
            }
        }
    }

    private fun relaxFixedHeight(view: View): Int {
        val layoutParams = view.layoutParams ?: return 0
        if (layoutParams.height > 0) {
            val fixedHeight = layoutParams.height
            layoutParams.height = ViewGroup.LayoutParams.WRAP_CONTENT
            view.layoutParams = layoutParams
            return fixedHeight
        }
        return 0
    }

    private fun scaleMinimumHeight(
        view: View,
        fixedHeightPx: Int,
        minHeightScale: Float,
    ) {
        val baseMinimumHeight = maxOf(view.minimumHeight, fixedHeightPx)
        if (baseMinimumHeight > 0) {
            view.minimumHeight = (baseMinimumHeight * minHeightScale).roundToInt()
        }
    }
}
