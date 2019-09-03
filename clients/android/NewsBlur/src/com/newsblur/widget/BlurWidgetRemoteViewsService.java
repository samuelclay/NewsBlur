package com.newsblur.widget;

import android.app.LoaderManager;
import android.appwidget.AppWidgetManager;
import android.content.Context;
import android.content.Intent;
import android.database.Cursor;
import android.os.Bundle;
import android.support.annotation.NonNull;
import android.support.annotation.Nullable;
import android.support.v4.content.Loader;
import android.widget.RemoteViews;
import android.widget.RemoteViewsService;

import com.newsblur.R;
import com.newsblur.database.BlurDatabaseHelper;
import com.newsblur.domain.Story;
import com.newsblur.util.FeedSet;
import com.newsblur.util.Log;

import java.util.ArrayList;
import java.util.List;
import java.util.Set;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public class BlurWidgetRemoteViewsService extends RemoteViewsService {
    private static String TAG = "BlurWidgetRemoteViewsFactory";
    public static String EXTRA_FEED_ID = "EXTRA_FEED_ID";
    @Override
    public RemoteViewsFactory onGetViewFactory(Intent intent) {
        Log.d(TAG, "onGetViewFactory");
        return new BlurWidgetRemoteViewsFactory(this.getApplicationContext(), intent);
    }
}

class BlurWidgetRemoteViewsFactory implements RemoteViewsService.RemoteViewsFactory {
    private Context context;
    private int appWidgetId;
    private String feedId;
    private BlurDatabaseHelper dbHelper;
    private static String TAG = "BlurWidgetRemoteViewsFactory";
    private List<Story> storyItems = new ArrayList<Story>();
    private FeedSet fs;
    private Cursor cursor;
    public BlurWidgetRemoteViewsFactory(Context context, Intent intent) {
        Log.d(TAG, "Constructor");
        this.context = context;
        appWidgetId = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID,
                AppWidgetManager.INVALID_APPWIDGET_ID);
        feedId = intent.getStringExtra(BlurWidgetRemoteViewsService.EXTRA_FEED_ID);
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
        dbHelper = new BlurDatabaseHelper(context);
        fs = FeedSet.singleFeed(feedId);
        cursor = null;
        Loader<Cursor> loader = dbHelper.getActiveStoriesLoader(fs);
        loader.registerListener(loader.getId(), new Loader.OnLoadCompleteListener<Cursor>() {
            @Override
            public void onLoadComplete(@NonNull Loader<Cursor> loader, @Nullable Cursor data) {
                cursor = data;
                loadStories(10);
            }
        });
        loader.startLoading();
    }

    /**
     * load up to {count} stories
     */
    private void loadStories(int count) {
        List<Story> loadedStories = new ArrayList<>();
        if (cursor == null || cursor.isClosed()) {
            return;
        }
        cursor.moveToPosition(-1);
        while (!cursor.isClosed() && cursor.moveToNext() && loadedStories.size() < count) {
            Story s = Story.fromCursor(cursor);
            s.bindExternValues(cursor);
            loadedStories.add(s);
        }
        storyItems.clear();
        storyItems.addAll(loadedStories);
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
        rv.setTextViewText(R.id.newsblur_widget_item_title, story.title);



        // Next, set a fill-intent, which will be used to fill in the pending intent template
        // that is set on the collection view in StackWidgetProvider.
        Bundle extras = new Bundle();
        extras.putInt(NewsBlurWidgetProvider.EXTRA_ITEM_ID, position);
        Intent fillInIntent = new Intent();
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
        loadStories(10);
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
        Log.d(TAG, "getCount");
        return Math.min(storyItems.size(), 10);
    }
}
