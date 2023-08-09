package com.newsblur.widget

import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import com.newsblur.R
import com.newsblur.util.Log

class WidgetUpdateReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent?) {
        if (intent != null && intent.action != null && intent.action == WidgetUtils.ACTION_UPDATE_WIDGET) {
            Log.d(this.javaClass.name, "Received ${WidgetUtils.ACTION_UPDATE_WIDGET}")
            val widgetManager = AppWidgetManager.getInstance(context)
            val appWidgetIds = widgetManager.getAppWidgetIds(ComponentName(context, WidgetProvider::class.java))
            widgetManager.notifyAppWidgetViewDataChanged(appWidgetIds, R.id.widget_list)
        }
    }
}