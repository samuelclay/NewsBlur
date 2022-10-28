package com.newsblur.widget;

import android.app.PendingIntent;
import android.appwidget.AppWidgetManager;
import android.appwidget.AppWidgetProvider;
import android.content.Context;
import android.content.Intent;
import android.graphics.Color;
import android.net.Uri;
import androidx.core.content.ContextCompat;
import android.util.Log;

import com.newsblur.R;
import com.newsblur.activity.AllStoriesItemsList;
import com.newsblur.activity.ItemsList;
import com.newsblur.activity.WidgetConfig;
import com.newsblur.util.FeedSet;
import com.newsblur.util.PendingIntentUtils;
import com.newsblur.util.PrefsUtils;
import com.newsblur.util.WidgetBackground;

import java.util.Set;

public class WidgetProvider extends AppWidgetProvider {

    private static String TAG = "WidgetProvider";

    // Called when the BroadcastReceiver receives an Intent broadcast.
    @Override
    public void onReceive(Context context, Intent intent) {
        Log.d(TAG, "onReceive");
        if (intent.getAction().equals(WidgetUtils.ACTION_OPEN_STORY)) {
            String storyHash = intent.getStringExtra(WidgetUtils.EXTRA_ITEM_ID);
            Intent i = new Intent(context, AllStoriesItemsList.class);
            i.putExtra(ItemsList.EXTRA_FEED_SET, FeedSet.allFeeds());
            i.putExtra(ItemsList.EXTRA_STORY_HASH, storyHash);
            i.putExtra(ItemsList.EXTRA_WIDGET_STORY, true);
            i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            context.getApplicationContext().startActivity(i);
        } else if (intent.getAction().equals(WidgetUtils.ACTION_OPEN_CONFIG)) {
            Intent i = new Intent(context, WidgetConfig.class);
            i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            context.getApplicationContext().startActivity(i);
        }
        super.onReceive(context, intent);
    }

    /**
     * This is called to update the App Widget at intervals defined by the updatePeriodMillis attribute
     */
    @Override
    public void onUpdate(Context context, AppWidgetManager appWidgetManager, int[] appWidgetIds) {
        // update each of the app widgets with the remote adapter
        Log.d(TAG, "onUpdate");
        WidgetUtils.checkWidgetUpdateAlarm(context);
        WidgetBackground widgetBackground = PrefsUtils.getWidgetBackground(context);
        Set<String> feedIds = PrefsUtils.getWidgetFeedIds(context);
        for (int appWidgetId : appWidgetIds) {

            // Set up the intent that starts the WidgetRemoteViewService, which will
            // provide the views for this collection.
            Intent intent = new Intent(context, WidgetRemoteViewsService.class);
            // Add the app widget ID to the intent extras.
            intent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId);
            intent.setData(Uri.parse(intent.toUri(Intent.URI_INTENT_SCHEME)));

            // Instantiate the RemoteViews object for the app widget layout.
            WidgetRemoteViews rv = new WidgetRemoteViews(context.getPackageName(), R.layout.view_app_widget);

            if (widgetBackground == WidgetBackground.DEFAULT) {
                rv.setViewBackgroundColor(R.id.container_widget, ContextCompat.getColor(context, R.color.widget_background));
            } else if (widgetBackground == WidgetBackground.TRANSPARENT) {
                rv.setViewBackgroundColor(R.id.container_widget, Color.TRANSPARENT);
            }
            // Set up the RemoteViews object to use a RemoteViews adapter.
            // This adapter connects
            // to a RemoteViewsService  through the specified intent.
            // This is how you populate the data.
            rv.setRemoteAdapter(R.id.widget_list, intent);

            // The empty view is displayed when the collection has no items.
            // It should be in the same layout used to instantiate the RemoteViews
            // object above.
            rv.setEmptyView(R.id.widget_list, R.id.widget_empty_view);

            if (feedIds != null && feedIds.isEmpty()) {
                rv.setTextViewText(R.id.widget_empty_view, context.getString(R.string.title_widget_setup));
            }

            Intent configIntent = new Intent(context, WidgetProvider.class);
            configIntent.setAction(WidgetUtils.ACTION_OPEN_CONFIG);
            PendingIntent configIntentTemplate = PendingIntentUtils.getImmutableBroadcast(context, WidgetUtils.RC_WIDGET_CONFIG, configIntent, PendingIntent.FLAG_UPDATE_CURRENT);
            rv.setOnClickPendingIntent(R.id.widget_empty_view, configIntentTemplate);

            // This section makes it possible for items to have individualized behavior.
            // It does this by setting up a pending intent template. Individuals items of a collection
            // cannot set up their own pending intents. Instead, the collection as a whole sets
            // up a pending intent template, and the individual items set a fillInIntent
            // to create unique behavior on an item-by-item basis.
            Intent touchIntent = new Intent(context, WidgetProvider.class);
            // Set the action for the intent.
            // When the user touches a particular view, it will have the effect of
            // broadcasting ACTION_OPEN_STORY.
            touchIntent.setAction(WidgetUtils.ACTION_OPEN_STORY);
            touchIntent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId);
            intent.setData(Uri.parse(intent.toUri(Intent.URI_INTENT_SCHEME)));
            PendingIntent touchIntentTemplate = PendingIntentUtils.getImmutableBroadcast(context, WidgetUtils.RC_WIDGET_STORY, touchIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT);
            rv.setPendingIntentTemplate(R.id.widget_list, touchIntentTemplate);

            appWidgetManager.updateAppWidget(appWidgetId, rv);
            appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.widget_list);
        }
        super.onUpdate(context, appWidgetManager, appWidgetIds);
    }
}