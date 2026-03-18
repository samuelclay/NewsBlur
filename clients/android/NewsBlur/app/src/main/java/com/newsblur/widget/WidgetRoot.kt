package com.newsblur.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.graphics.Color
import androidx.core.content.ContextCompat
import com.newsblur.R
import com.newsblur.preference.PrefsRepo
import com.newsblur.util.PendingIntentUtils.getImmutableBroadcast
import com.newsblur.util.PendingIntentUtils.getMutableBroadcast
import com.newsblur.util.WidgetBackground

object WidgetRoot {
    fun create(
        context: Context,
        prefsRepo: PrefsRepo,
        appWidgetId: Int,
        showSetupEmptyText: Boolean,
    ): WidgetRemoteViews {
        val rv = WidgetRemoteViews(context.packageName, R.layout.view_app_widget)

        val bg = prefsRepo.getWidgetBackground()
        if (bg == WidgetBackground.DEFAULT) {
            rv.setViewBackgroundColor(R.id.container_widget, ContextCompat.getColor(context, R.color.widget_background))
        } else if (bg == WidgetBackground.TRANSPARENT) {
            rv.setViewBackgroundColor(R.id.container_widget, Color.TRANSPARENT)
        }

        rv.setEmptyView(R.id.widget_list, R.id.widget_empty_view)
        if (showSetupEmptyText) {
            rv.setTextViewText(R.id.widget_empty_view, context.getString(R.string.title_widget_setup))
        }

        val configIntent =
            Intent(context, WidgetProvider::class.java).apply {
                action = WidgetUtils.ACTION_OPEN_CONFIG
            }
        val configPI =
            getImmutableBroadcast(context, WidgetUtils.RC_WIDGET_CONFIG, configIntent, PendingIntent.FLAG_UPDATE_CURRENT)
        rv.setOnClickPendingIntent(R.id.widget_empty_view, configPI)

        val touchIntent =
            Intent(context, WidgetProvider::class.java).apply {
                action = WidgetUtils.ACTION_OPEN_STORY
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
            }
        val touchPI =
            getMutableBroadcast(context, WidgetUtils.RC_WIDGET_STORY, touchIntent, PendingIntent.FLAG_UPDATE_CURRENT)

        rv.setPendingIntentTemplate(R.id.widget_list, touchPI)

        return rv
    }
}
