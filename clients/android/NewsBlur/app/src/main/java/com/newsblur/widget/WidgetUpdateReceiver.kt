package com.newsblur.widget

import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import com.newsblur.R
import com.newsblur.util.Log
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class WidgetUpdateReceiver : BroadcastReceiver() {
    override fun onReceive(
        context: Context,
        intent: Intent?,
    ) {
        if (intent?.action != WidgetUtils.ACTION_UPDATE_WIDGET) return

        Log.d(this.javaClass.name, "Received ${WidgetUtils.ACTION_UPDATE_WIDGET}")

        if (Build.VERSION.SDK_INT >= 31) {
            val pending = goAsync()
            CoroutineScope(Dispatchers.IO).launch {
                try {
                    WidgetUpdater.updateAll(context)
                } finally {
                    pending.finish()
                }
            }
        } else {
            val widgetManager = AppWidgetManager.getInstance(context)
            val appWidgetIds = widgetManager.getAppWidgetIds(ComponentName(context, WidgetProvider::class.java))
            @Suppress("DEPRECATION")
            widgetManager.notifyAppWidgetViewDataChanged(appWidgetIds, R.id.widget_list)
        }
    }
}
