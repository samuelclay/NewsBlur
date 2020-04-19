package com.newsblur.widget;

import android.appwidget.AppWidgetManager;
import android.content.Context;
import android.content.Intent;
import android.database.Cursor;
import android.graphics.Color;
import android.os.Bundle;
import android.support.annotation.NonNull;
import android.support.annotation.Nullable;
import android.support.v4.content.Loader;
import android.text.TextUtils;
import android.view.View;
import android.widget.RemoteViews;
import android.widget.RemoteViewsService;

import com.newsblur.R;
import com.newsblur.domain.Story;
import com.newsblur.util.FeedSet;
import com.newsblur.util.FeedUtils;
import com.newsblur.util.Log;
import com.newsblur.util.PrefsUtils;
import com.newsblur.util.StoryUtils;
import com.newsblur.util.ThumbnailStyle;
import com.newsblur.util.UIUtils;

import java.util.ArrayList;
import java.util.List;

public class WidgetRemoteViewsFactory implements RemoteViewsService.RemoteViewsFactory {

    private static String TAG = "WidgetRemoteViewsFactory";

    private Context context;
    private List<Story> storyItems = new ArrayList<>();
    private FeedSet fs;
    private Cursor cursor;
    private int appWidgetId;
    private boolean skipCursorUpdate;

    WidgetRemoteViewsFactory(Context context, Intent intent) {
        com.newsblur.util.Log.d(TAG, "Constructor");
        this.context = context;
        appWidgetId = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID,
                AppWidgetManager.INVALID_APPWIDGET_ID);
        final String feedId = PrefsUtils.getWidgetFeed(context, appWidgetId);
        final String feedName = PrefsUtils.getWidgetFeedName(context, appWidgetId);

        if (feedId != null) {
            // this is a single feed
            fs = FeedSet.singleFeed(feedId);
        } else {
            // this is a folder
            fs = FeedUtils.feedSetFromFolderName(feedName);
        }
    }

    /**
     * The system calls onCreate() when creating your factory for the first time.
     * This is where you set up any connections and/or cursors to your data source.
     * <p>
     * Heavy lifting,
     * for example downloading or creating content etc, should be deferred to onDataSetChanged()
     * or getViewAt(). Taking more than 20 seconds in this call will result in an ANR.
     */
    @Override
    public void onCreate() {
        Log.d(TAG, "onCreate");
        while (FeedUtils.dbHelper == null) {
            // widget could be created before app init
            // wait for the dbHelper to be ready for use
        }
    }

    private void fetchStories() {
        com.newsblur.util.Log.d(TAG, "Fetching widget stories");
        final List<Story> newStories;
        try {
            if (cursor == null) {
                newStories = new ArrayList<>(0);
            } else {
                if (cursor.isClosed()) return;
                newStories = new ArrayList<>(cursor.getCount());
                cursor.moveToPosition(-1);
                while (cursor.moveToNext()) {
                    if (cursor.isClosed()) return;
                    Story s = Story.fromCursor(cursor);
                    s.bindExternValues(cursor);
                    newStories.add(s);
                }
            }
        } catch (Exception e) {
            com.newsblur.util.Log.e(this, "error thawing story list: " + e.getMessage(), e);
            return;
        }

        storyItems.clear();
        storyItems.addAll(newStories);
    }

    /**
     * Allowed to run synchronous calls
     */
    @Override
    public RemoteViews getViewAt(int position) {
        com.newsblur.util.Log.d(TAG, "getViewAt " + position);
        Story story = storyItems.get(position);

        WidgetRemoteViews rv = new WidgetRemoteViews(context.getPackageName(), R.layout.view_widget_story_item);
        rv.setTextViewText(R.id.story_item_title, story.title);
        rv.setTextViewText(R.id.story_item_content, story.shortContent);
        rv.setTextViewText(R.id.story_item_author, story.authors);
        rv.setTextViewText(R.id.story_item_feedtitle, story.extern_feedTitle);

        // image dimensions same as R.layout.view_widget_story_item
        FeedUtils.iconLoader.displayWidgetImage(story.extern_faviconUrl, R.id.story_item_feedicon, UIUtils.dp2px(context, 18), rv);
        if (PrefsUtils.getThumbnailStyle(context) != ThumbnailStyle.OFF && !TextUtils.isEmpty(story.thumbnailUrl)) {
            FeedUtils.thumbnailLoader.displayWidgetImage(story.thumbnailUrl, R.id.story_item_thumbnail, UIUtils.dp2px(context, 64), rv);
        } else {
            rv.setViewVisibility(R.id.story_item_thumbnail, View.GONE);
        }

        //TODO: authors and dates don't get along
        CharSequence time = StoryUtils.formatRelativeTime(context, story.timestamp);
        rv.setTextViewText(R.id.story_item_date, time);

        rv.setViewBackgroundColor(R.id.story_item_favicon_borderbar_1, UIUtils.decodeColourValue(story.extern_feedColor, Color.GRAY));
        rv.setViewBackgroundColor(R.id.story_item_favicon_borderbar_2, UIUtils.decodeColourValue(story.extern_feedFade, Color.LTGRAY));

        // set fill-intent which is used to fill in the pending intent template
        // set on the collection view in WidgetProvider
        Bundle extras = new Bundle();
        extras.putString(WidgetProvider.EXTRA_ITEM_ID, story.storyHash);
        extras.putString(WidgetProvider.EXTRA_FEED_ID, story.feedId);
        Intent fillInIntent = new Intent();
        fillInIntent.putExtras(extras);

        rv.setOnClickFillInIntent(R.id.view_widget_item, fillInIntent);
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
     * @return The number of types of Views that will be returned by this factory.
     */
    @Override
    public int getViewTypeCount() {
        return 1;
    }

    /**
     * @param position The position of the item within the data set whose row id we want.
     * @return The id of the item at the specified position.
     */
    @Override
    public long getItemId(int position) {
        return storyItems.get(position).hashCode();
    }

    /**
     * @return True if the same id always refers to the same object.
     */
    @Override
    public boolean hasStableIds() {
        return true;
    }

    @Override
    public void onDataSetChanged() {
        if (skipCursorUpdate) {
            com.newsblur.util.Log.d(TAG, "onDataSetChanged - skip cursor update");
            skipCursorUpdate = false;
            fetchStories();
        } else {
            com.newsblur.util.Log.d(TAG, "onDataSetChanged - do update cursor");
            Loader<Cursor> loader = FeedUtils.dbHelper.getStoriesLoader(fs);
            loader.registerListener(loader.getId(), new Loader.OnLoadCompleteListener<Cursor>() {
                @Override
                public void onLoadComplete(@NonNull Loader<Cursor> loader, @Nullable Cursor cursor) {
                    com.newsblur.util.Log.d(TAG, "onDataSetChanged - update cursor completed");
                    WidgetRemoteViewsFactory.this.cursor = cursor;
                    skipCursorUpdate = true;
                    fetchStories();
                    invalidate();
                }
            });
            loader.startLoading();
        }
    }

    /**
     * Called when the last RemoteViewsAdapter that is associated with this factory is
     * unbound.
     */
    @Override
    public void onDestroy() {
        com.newsblur.util.Log.d(TAG, "onDestroy");
        if (cursor != null) {
            cursor.close();
        }
        PrefsUtils.removeWidgetFeed(context, appWidgetId);
    }

    /**
     * @return Count of items.
     */
    @Override
    public int getCount() {
        return Math.min(storyItems.size(), 10);
    }

    private void invalidate() {
        com.newsblur.util.Log.d(TAG, "Invalidate app widget with id: " + appWidgetId);
        AppWidgetManager appWidgetManager = AppWidgetManager.getInstance(context);
        appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.widget_list);
    }
}