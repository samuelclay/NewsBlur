package com.newsblur.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.net.Uri
import android.util.Log
import androidx.core.content.ContextCompat
import com.newsblur.R
import com.newsblur.activity.AllStoriesItemsList
import com.newsblur.activity.ItemsList
import com.newsblur.activity.WidgetConfig
import com.newsblur.util.FeedSet
import com.newsblur.util.PendingIntentUtils.getImmutableBroadcast
import com.newsblur.util.PendingIntentUtils.getMutableBroadcast
import com.newsblur.util.PrefsUtils
import com.newsblur.util.WidgetBackground
import com.newsblur.widget.WidgetUtils.checkWidgetUpdateAlarm

class WidgetProvider : AppWidgetProvider() {

    /**
     * Called when the BroadcastReceiver receives an Intent broadcast.
     */
    override fun onReceive(context: Context, intent: Intent) {
        Log.d(this.javaClass.name, "onReceive")
        if (intent.action == WidgetUtils.ACTION_OPEN_STORY) {
            val storyHash = intent.getStringExtra(WidgetUtils.EXTRA_ITEM_ID)
            Intent(context, AllStoriesItemsList::class.java).apply {
                putExtra(ItemsList.EXTRA_FEED_SET, FeedSet.allFeeds())
                putExtra(ItemsList.EXTRA_STORY_HASH, storyHash)
                putExtra(ItemsList.EXTRA_WIDGET_STORY, true)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }.also {
                context.applicationContext.startActivity(it)
            }
        } else if (intent.action == WidgetUtils.ACTION_OPEN_CONFIG) {
            Intent(context, WidgetConfig::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }.also {
                context.applicationContext.startActivity(it)
            }
        }
        super.onReceive(context, intent)
    }

    /**
     * This is called to update the App Widget at intervals defined by the updatePeriodMillis attribute
     */
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        // update each of the app widgets with the remote adapter
        Log.d(this.javaClass.name, "onUpdate")
        checkWidgetUpdateAlarm(context)
        val widgetBackground = PrefsUtils.getWidgetBackground(context)
        val feedIds = PrefsUtils.getWidgetFeedIds(context)
        for (appWidgetId in appWidgetIds) {

            // Set up the intent that starts the WidgetRemoteViewService, which will
            // provide the views for this collection.
            val intent = Intent(context, WidgetRemoteViewsService::class.java).apply {
                // Add the app widget ID to the intent extras.
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
            }

            // Instantiate the RemoteViews object for the app widget layout.
            val rv = WidgetRemoteViews(context.packageName, R.layout.view_app_widget)
            if (widgetBackground == WidgetBackground.DEFAULT) {
                rv.setViewBackgroundColor(R.id.container_widget, ContextCompat.getColor(context, R.color.widget_background))
            } else if (widgetBackground == WidgetBackground.TRANSPARENT) {
                rv.setViewBackgroundColor(R.id.container_widget, Color.TRANSPARENT)
            }

            // Set up the RemoteViews object to use a RemoteViews adapter.
            // This adapter connects to a RemoteViewsService through the
            // specified intent. This is how you populate the data.
            rv.setRemoteAdapter(R.id.widget_list, intent)

            // The empty view is displayed when the collection has no items.
            // It should be in the same layout used to instantiate the RemoteViews
            // object above.
            rv.setEmptyView(R.id.widget_list, R.id.widget_empty_view)
            if (feedIds != null && feedIds.isEmpty()) {
                rv.setTextViewText(R.id.widget_empty_view, context.getString(R.string.title_widget_setup))
            }

            val configIntent = Intent(context, WidgetProvider::class.java)
            configIntent.action = WidgetUtils.ACTION_OPEN_CONFIG
            val configIntentTemplate = getImmutableBroadcast(context, WidgetUtils.RC_WIDGET_CONFIG, configIntent, PendingIntent.FLAG_UPDATE_CURRENT)
            rv.setOnClickPendingIntent(R.id.widget_empty_view, configIntentTemplate)

            // This section makes it possible for items to have individualized behavior.
            // It does this by setting up a pending intent template. Individuals items of a collection
            // cannot set up their own pending intents. Instead, the collection as a whole sets
            // up a pending intent template, and the individual items set a fillInIntent
            // to create unique behavior on an item-by-item basis.
            val touchIntent = Intent(context, WidgetProvider::class.java).apply {
                // Set the action for the intent.
                // When the user touches a particular view, it will have the effect of
                // broadcasting ACTION_OPEN_STORY.
                action = WidgetUtils.ACTION_OPEN_STORY
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
            }

            val touchIntentTemplate = getMutableBroadcast(context, WidgetUtils.RC_WIDGET_STORY, touchIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT)
            rv.setPendingIntentTemplate(R.id.widget_list, touchIntentTemplate)
            appWidgetManager.updateAppWidget(appWidgetId, rv)
            appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.widget_list)
        }
        super.onUpdate(context, appWidgetManager, appWidgetIds)
    }

    override fun onDeleted(context: Context?, appWidgetIds: IntArray?) {
        super.onDeleted(context, appWidgetIds)
    }
}