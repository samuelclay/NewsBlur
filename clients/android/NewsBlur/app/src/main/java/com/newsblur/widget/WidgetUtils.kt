package com.newsblur.widget

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.SystemClock
import com.newsblur.util.Log
import com.newsblur.util.PendingIntentUtils.getImmutableBroadcast
import com.newsblur.util.PrefsUtils

object WidgetUtils {

    private const val RC_WIDGET_UPDATE = 1

    const val ACTION_UPDATE_WIDGET = "ACTION_UPDATE_WIDGET"
    const val ACTION_OPEN_STORY = "ACTION_OPEN_STORY"
    const val ACTION_OPEN_CONFIG = "ACTION_OPEN_CONFIG"
    const val EXTRA_ITEM_ID = "EXTRA_ITEM_ID"

    const val RC_WIDGET_STORY = 2
    const val RC_WIDGET_CONFIG = 3
    const val STORIES_LIMIT = 5

    fun enableWidgetUpdate(context: Context) {
        Log.d(this.javaClass.name, "enableWidgetUpdate")
        val alarmManager = context.getSystemService(AlarmManager::class.java)
        val intent = getUpdateIntent(context)
        val pendingIntent = getImmutableBroadcast(context, RC_WIDGET_UPDATE, intent, PendingIntent.FLAG_UPDATE_CURRENT)
        val widgetUpdateInterval = 1000 * 60 * 5
        val startAlarmAt = SystemClock.currentThreadTimeMillis() + widgetUpdateInterval
        pendingIntent?.let {
            alarmManager.setInexactRepeating(AlarmManager.RTC, startAlarmAt, widgetUpdateInterval.toLong(), it)
        }
    }

    @JvmStatic
    fun disableWidgetUpdate(context: Context) {
        Log.d(this.javaClass.name, "disableWidgetUpdate")
        val alarmManager = context.getSystemService(AlarmManager::class.java)
        val pendingIntent = getImmutableBroadcast(context, RC_WIDGET_UPDATE, getUpdateIntent(context), PendingIntent.FLAG_UPDATE_CURRENT)
        pendingIntent?.let {
            alarmManager.cancel(it)
        }
    }

    @JvmStatic
    fun resetWidgetUpdate(context: Context) {
        if (hasActiveAppWidgets(context)) {
            enableWidgetUpdate(context)
        }
    }

    @JvmStatic
    fun hasActiveAppWidgets(context: Context): Boolean {
        val widgetManager = AppWidgetManager.getInstance(context)
        val appWidgetIds = widgetManager.getAppWidgetIds(ComponentName(context, WidgetProvider::class.java))
        return appWidgetIds.isNotEmpty()
    }

    @JvmStatic
    fun updateWidget(context: Context) {
        val appWidgetManager = AppWidgetManager.getInstance(context)
        val appWidgetIds = appWidgetManager.getAppWidgetIds(ComponentName(context, WidgetProvider::class.java))
        val intent = Intent(context, WidgetProvider::class.java)
        intent.action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
        intent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, appWidgetIds)
        context.sendBroadcast(intent)
    }

    @JvmStatic
    fun checkWidgetUpdateAlarm(context: Context) {
        val hasActiveUpdates = getImmutableBroadcast(context, RC_WIDGET_UPDATE, getUpdateIntent(context), PendingIntent.FLAG_NO_CREATE) != null
        if (!hasActiveUpdates) {
            enableWidgetUpdate(context)
        }
    }

    fun isLoggedIn(context: Context): Boolean = PrefsUtils.getUniqueLoginKey(context) != null

    private fun getUpdateIntent(context: Context) = Intent(context, WidgetUpdateReceiver::class.java).apply {
        action = ACTION_UPDATE_WIDGET
    }
}