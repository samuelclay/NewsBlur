package com.newsblur.widget;

import android.os.Parcel;
import android.support.annotation.ColorInt;
import android.widget.RemoteViews;

public class WidgetRemoteViews extends RemoteViews {

    public WidgetRemoteViews(String packageName, int layoutId) {
        super(packageName, layoutId);
    }

    public WidgetRemoteViews(RemoteViews landscape, RemoteViews portrait) {
        super(landscape, portrait);
    }

    public WidgetRemoteViews(Parcel parcel) {
        super(parcel);
    }

    public void setViewBackgroundColor(int viewId, @ColorInt int color) {
        setInt(viewId, "setBackgroundColor", color);
    }

    public void getViewById(int viewId) {

    }
}
