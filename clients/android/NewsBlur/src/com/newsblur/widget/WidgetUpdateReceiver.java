package com.newsblur.widget;

import android.appwidget.AppWidgetManager;
import android.content.BroadcastReceiver;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import androidx.annotation.Nullable;

import com.newsblur.R;
import com.newsblur.util.Log;

public class WidgetUpdateReceiver extends BroadcastReceiver {

    @Override
    public void onReceive(Context context, @Nullable Intent intent) {
        if (intent != null && intent.getAction() != null &&
                intent.getAction().equals(WidgetUtils.ACTION_UPDATE_WIDGET)) {
            Log.d(this.getClass().getName(), "Received " + WidgetUtils.ACTION_UPDATE_WIDGET);
            AppWidgetManager widgetManager = AppWidgetManager.getInstance(context);
            int[] appWidgetIds = widgetManager.getAppWidgetIds(new ComponentName(context, WidgetProvider.class));
            widgetManager.notifyAppWidgetViewDataChanged(appWidgetIds, R.id.widget_list);
        }
    }
}
