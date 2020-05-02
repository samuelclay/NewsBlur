package com.newsblur.widget;

import android.appwidget.AppWidgetManager;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.support.annotation.Nullable;

import com.newsblur.R;
import com.newsblur.util.Log;

public class WidgetUpdateReceiver extends BroadcastReceiver {

    @Override
    public void onReceive(Context context, @Nullable Intent intent) {
        if (intent != null && intent.getAction() != null &&
                intent.getAction().equals(WidgetUtils.ACTION_UPDATE_WIDGET)) {
            Log.d(this.getClass().getName(), "Received " + WidgetUtils.ACTION_UPDATE_WIDGET);
            int widgetId = intent.getIntExtra(WidgetUtils.EXTRA_WIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID);
            if (widgetId != AppWidgetManager.INVALID_APPWIDGET_ID) {
                AppWidgetManager widgetManager = AppWidgetManager.getInstance(context);
                widgetManager.notifyAppWidgetViewDataChanged(widgetId, R.id.widget_list);
            }
        }
    }
}
