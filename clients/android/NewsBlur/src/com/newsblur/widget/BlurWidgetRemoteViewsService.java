package com.newsblur.widget;

import android.appwidget.AppWidgetManager;
import android.content.Context;
import android.content.Intent;
import android.os.Bundle;
import android.text.format.DateFormat;
import android.text.format.DateUtils;
import android.widget.RemoteViews;
import android.widget.RemoteViewsService;

import com.newsblur.R;
import com.newsblur.domain.Story;
import com.newsblur.network.APIManager;
import com.newsblur.network.domain.StoriesResponse;
import com.newsblur.util.FeedSet;
import com.newsblur.util.Log;
import com.newsblur.util.PrefsUtils;
import com.newsblur.util.ReadFilter;
import com.newsblur.util.StoryOrder;
import com.newsblur.util.StoryUtils;

import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

public class BlurWidgetRemoteViewsService extends RemoteViewsService {
    private static String TAG = "BlurWidgetRemoteViewsFactory";
    @Override
    public RemoteViewsFactory onGetViewFactory(Intent intent) {
        Log.d(TAG, "onGetViewFactory");
        return new BlurWidgetRemoteViewsFactory(this.getApplicationContext(), intent);
    }
}

class BlurWidgetRemoteViewsFactory implements RemoteViewsService.RemoteViewsFactory {
    private Context context;
    private String feedId;
    private static String TAG = "BlurWidgetRemoteViewsFactory";
    private List<Story> storyItems = new ArrayList<Story>();
    private FeedSet fs;
    private APIManager apiManager;
    public BlurWidgetRemoteViewsFactory(Context context, Intent intent) {
        Log.d(TAG, "Constructor");
        this.context = context;
        int appWidgetId = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID,
                AppWidgetManager.INVALID_APPWIDGET_ID);
        feedId = PrefsUtils.getWidgetFeed(context, appWidgetId);
        apiManager = new APIManager(context);
        Log.d(TAG, "Feed ID: " + feedId);
    }
    /**
     * The system calls onCreate() when creating your factory for the first time.
     * This is where you set up any connections and/or cursors to your data source.
     *
     * Heavy lifting,
     * for example downloading or creating content etc, should be deferred to onDataSetChanged()
     * or getViewAt(). Taking more than 20 seconds in this call will result in an ANR.
     */
    @Override
    public void onCreate() {
        Log.d(TAG, "onCreate");
        fs = FeedSet.singleFeed(feedId);
    }

    private void fetchStories() {
        Log.d(TAG, String.format("Fetching stories %s", fs.hashCode()));
        StoriesResponse response =
                apiManager.getStories(fs, 1, StoryOrder.NEWEST, ReadFilter.ALL);

        if (response == null) {
            Log.e(TAG, "Response is null");
            return;
        } else if (response.stories == null) {
            Log.e(TAG, "Stories are empty");
            return;
        } else if (response.isError()) {
            String err = String.format("response error for feed %s", fs.hashCode());
            Log.e(TAG, response.getErrorMessage(err));
            return;
        }
        storyItems.clear();
        storyItems.addAll(Arrays.asList(response.stories));
    }
    /**
     * allowed to run synchronous calls
     */
    @Override
    public RemoteViews getViewAt(int position) {
        Log.d(TAG, "getViewAt " + position);
        Story story = storyItems.get(position);
        // Construct a remote views item based on the app widget item XML file,
        // and set the text based on the position.
        RemoteViews rv = new RemoteViews(context.getPackageName(), R.layout.newsblur_widget_item);
        rv.setTextViewText(R.id.widget_item_title, story.title);

        CharSequence time = StoryUtils.formatRelativeTime(context, story.timestamp);

        rv.setTextViewText(R.id.widget_item_time, time);



        // Next, set a fill-intent, which will be used to fill in the pending intent template
        // that is set on the collection view in StackWidgetProvider.
        Bundle extras = new Bundle();
        extras.putString(NewsBlurWidgetProvider.EXTRA_ITEM_ID, story.storyHash);
        extras.putString(NewsBlurWidgetProvider.EXTRA_FEED_ID, story.feedId);
        Intent fillInIntent = new Intent();
//        fillInIntent.setAction(NewsBlurWidgetProvider.ACTION_OPEN_STORY);
        fillInIntent.putExtras(extras);
        // Make it possible to distinguish the individual on-click
        // action of a given item
        rv.setOnClickFillInIntent(R.id.newsblur_widget_item, fillInIntent);
        return rv;
    }

    /**
     * This allows for the use of a custom loading view which appears between the time that
     * {@link #getViewAt(int)} is called and returns. If null is returned, a default loading
     * view will be used.
     *
     * @return The RemoteViews representing the desired loading view.
     */
    @Override
    public RemoteViews getLoadingView() {
        return null;
    }

    /**
     *
     * @return The number of types of Views that will be returned by this factory.
     */
    @Override
    public int getViewTypeCount() {
        return 1;
    }

    /**
     *
     * @param position The position of the item within the data set whose row id we want.
     * @return The id of the item at the specified position.
     */
    @Override
    public long getItemId(int position) {
        return storyItems.get(position).hashCode();
    }

    /**
     *
     * @return True if the same id always refers to the same object.
     */
    @Override
    public boolean hasStableIds() {
        return true;
    }


    @Override
    public void onDataSetChanged() {
        // fetch any new data
        fetchStories();
        Log.d(TAG, "onDataSetChanged");
    }

    /**
     * Called when the last RemoteViewsAdapter that is associated with this factory is
     * unbound.
     */
    @Override
    public void onDestroy() {
        Log.d(TAG, "onDestroy");
    }

    /**
     *
     * @return Count of items.
     */
    @Override
    public int getCount() {
        Log.d(TAG, "getCount: " + Math.min(storyItems.size(), 10));
        return Math.min(storyItems.size(), 10);
    }
}
