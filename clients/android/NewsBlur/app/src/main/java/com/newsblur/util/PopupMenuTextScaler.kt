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

    fun apply(root: View, preferenceScale: Float) {
        val textScale = resolvedTextScale(preferenceScale)
        scaleView(root, textScale)
    }

    @VisibleForTesting
    internal fun resolvedTextScale(preferenceScale: Float): Float = preferenceScale.coerceAtLeast(MIN_MENU_TEXT_SCALE)

    @VisibleForTesting
    internal fun scaledTextSizePx(
        baseTextSizePx: Float,
        preferenceScale: Float,
    ): Float = baseTextSizePx * resolvedTextScale(preferenceScale)

    @VisibleForTesting
    internal fun scaledWidthPx(
        baseWidthPx: Int,
        preferenceScale: Float,
    ): Int = (baseWidthPx * resolvedTextScale(preferenceScale)).roundToInt()

    @VisibleForTesting
    internal fun scaledControlHeightPx(
        baseHeightPx: Int,
        preferenceScale: Float,
    ): Int {
        if (baseHeightPx <= 0) return 0
        return baseHeightPx + additionalControlHeightDp(preferenceScale).roundToInt()
    }

    @VisibleForTesting
    internal fun additionalControlHeightDp(preferenceScale: Float): Float =
        when (resolvedTextScale(preferenceScale)) {
            in 1.4f..<1.8f -> 3f
            in 1.2f..<1.4f -> 2f
            else -> if (resolvedTextScale(preferenceScale) >= 1.8f) 6f else 0f
        }

    private fun scaleView(
        view: View,
        textScale: Float,
    ) {
        if (view is TextView) {
            val baseTextSize =
                (view.getTag(R.id.popup_menu_scaler_base_text_size) as? Float)
                    ?: view.textSize.also { view.setTag(R.id.popup_menu_scaler_base_text_size, it) }
            view.setTextSize(TypedValue.COMPLEX_UNIT_PX, baseTextSize * textScale)
        }

        if (view is MaterialButton || view.id == R.id.group_theme) {
            val layoutParams = view.layoutParams
            val baseHeight =
                (view.getTag(R.id.popup_menu_scaler_base_height) as? Int)
                    ?: maxOf(layoutParams?.height ?: 0, view.minimumHeight).takeIf { it > 0 }?.also {
                        view.setTag(R.id.popup_menu_scaler_base_height, it)
                    }
                    ?: 0
            if (layoutParams != null && baseHeight > 0) {
                val extraHeightPx = UIUtils.dp2px(view.context, additionalControlHeightDp(textScale)).roundToInt()
                layoutParams.height = baseHeight + extraHeightPx
                view.layoutParams = layoutParams
            }
        }

        if (view is ViewGroup) {
            for (index in 0 until view.childCount) {
                scaleView(view.getChildAt(index), textScale)
            }
        }
    }
}
