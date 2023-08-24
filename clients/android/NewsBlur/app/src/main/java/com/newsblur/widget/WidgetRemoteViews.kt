package com.newsblur.widget

import android.widget.RemoteViews
import androidx.annotation.ColorInt

internal class WidgetRemoteViews(
        packageName: String,
        layoutId: Int,
) : RemoteViews(packageName, layoutId) {

    fun setViewBackgroundColor(viewId: Int, @ColorInt color: Int) {
        setInt(viewId, "setBackgroundColor", color)
    }
}