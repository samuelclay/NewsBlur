package com.newsblur.widget;

import androidx.annotation.ColorInt;
import android.widget.RemoteViews;

class WidgetRemoteViews extends RemoteViews {

    WidgetRemoteViews(String packageName, int layoutId) {
        super(packageName, layoutId);
    }

    void setViewBackgroundColor(int viewId, @ColorInt int color) {
        setInt(viewId, "setBackgroundColor", color);
    }
}
