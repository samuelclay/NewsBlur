package com.newsblur.widget

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.os.Bundle
import android.os.CancellationSignal
import android.text.TextUtils
import android.view.View
import android.widget.RemoteViews
import android.widget.RemoteViewsService.RemoteViewsFactory
import com.newsblur.R
import com.newsblur.database.BlurDatabaseHelper
import com.newsblur.di.IconLoader
import com.newsblur.di.ThumbnailLoader
import com.newsblur.domain.Feed
import com.newsblur.domain.Story
import com.newsblur.network.APIManager
import com.newsblur.util.*
import dagger.hilt.EntryPoint
import dagger.hilt.InstallIn
import dagger.hilt.android.EntryPointAccessors
import dagger.hilt.components.SingletonComponent
import java.util.*
import kotlin.math.min

class WidgetRemoteViewsFactory(context: Context, intent: Intent) : RemoteViewsFactory {

    private val context: Context
    private val apiManager: APIManager
    private val dbHelper: BlurDatabaseHelper
    private val iconLoader: ImageLoader
    private val thumbnailLoader: ImageLoader
    private var fs: FeedSet? = null
    private val appWidgetId: Int
    private var dataCompleted = false
    private val storyItems: MutableList<Story> = ArrayList()
    private val cancellationSignal = CancellationSignal()

    init {
        Log.d(TAG, "Constructor")
        val hiltEntryPoint = EntryPointAccessors
                .fromApplication(context.applicationContext, WidgetRemoteViewsFactoryEntryPoint::class.java)
        this.context = context
        this.apiManager = hiltEntryPoint.apiManager()
        this.dbHelper = hiltEntryPoint.dbHelper()
        this.iconLoader = hiltEntryPoint.iconLoader()
        this.thumbnailLoader = hiltEntryPoint.thumbnailLoader()
        appWidgetId = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID,
                AppWidgetManager.INVALID_APPWIDGET_ID)
    }

    /**
     * The system calls onCreate() when creating your factory for the first time.
     * This is where you set up any connections and/or cursors to your data source.
     *
     *
     * Heavy lifting,
     * for example downloading or creating content etc, should be deferred to onDataSetChanged()
     * or getViewAt(). Taking more than 20 seconds in this call will result in an ANR.
     */
    override fun onCreate() {
        Log.d(TAG, "onCreate")
        WidgetUtils.enableWidgetUpdate(context)
    }

    /**
     * Allowed to run synchronous calls
     */
    override fun getViewAt(position: Int): RemoteViews {
        Log.d(TAG, "getViewAt $position")
        val story = storyItems[position]
        val rv = WidgetRemoteViews(context.packageName, R.layout.view_widget_story_item)
        rv.setTextViewText(R.id.story_item_title, story.title)
        rv.setTextViewText(R.id.story_item_content, story.shortContent)
        rv.setTextViewText(R.id.story_item_author, story.authors)
        rv.setTextViewText(R.id.story_item_feedtitle, story.extern_feedTitle)
        val time: CharSequence = StoryUtils.formatShortDate(context, story.timestamp)
        rv.setTextViewText(R.id.story_item_date, time)

        // image dimensions same as R.layout.view_widget_story_item
        iconLoader.displayWidgetImage(story.extern_faviconUrl, R.id.story_item_feedicon, UIUtils.dp2px(context, 19), rv)
        if (PrefsUtils.getThumbnailStyle(context) != ThumbnailStyle.OFF && !TextUtils.isEmpty(story.thumbnailUrl)) {
            thumbnailLoader.displayWidgetImage(story.thumbnailUrl, R.id.story_item_thumbnail, UIUtils.dp2px(context, 64), rv)
        } else {
            rv.setViewVisibility(R.id.story_item_thumbnail, View.GONE)
        }
        rv.setViewBackgroundColor(R.id.story_item_favicon_borderbar_1, UIUtils.decodeColourValue(story.extern_feedColor, Color.GRAY))
        rv.setViewBackgroundColor(R.id.story_item_favicon_borderbar_2, UIUtils.decodeColourValue(story.extern_feedFade, Color.LTGRAY))

        // set fill-intent which is used to fill in the pending intent template
        // set on the collection view in WidgetProvider
        val extras = Bundle()
        extras.putString(WidgetUtils.EXTRA_ITEM_ID, story.storyHash)
        val fillInIntent = Intent()
        fillInIntent.putExtras(extras)
        rv.setOnClickFillInIntent(R.id.view_widget_item, fillInIntent)
        return rv
    }

    /**
     * This allows for the use of a custom loading view which appears between the time that
     * [.getViewAt] is called and returns. If null is returned, a default loading
     * view will be used.
     *
     * @return The RemoteViews representing the desired loading view.
     */
    override fun getLoadingView(): RemoteViews? = null

    /**
     * @return The number of types of Views that will be returned by this factory.
     */
    override fun getViewTypeCount(): Int = 1

    /**
     * @param position The position of the item within the data set whose row id we want.
     * @return The id of the item at the specified position.
     */
    override fun getItemId(position: Int): Long = storyItems[position].hashCode().toLong()

    /**
     * @return True if the same id always refers to the same object.
     */
    override fun hasStableIds(): Boolean = true

    override fun onDataSetChanged() {
        Log.d(TAG, "onDataSetChanged")
        // if user logged out don't try to update widget
        if (!WidgetUtils.isLoggedIn(context)) {
            Log.d(TAG, "onDataSetChanged - not logged in")
            return
        }
        if (dataCompleted) {
            // we have all the stories data, just let the widget redraw
            Log.d(TAG, "onDataSetChanged - redraw widget")
            dataCompleted = false
        } else {
            setFeedSet()
            if (fs == null) {
                Log.d(TAG, "onDataSetChanged - null feed set. Show empty view")
                setStories(arrayOf(), HashMap(0))
                return
            }
            Log.d(TAG, "onDataSetChanged - fetch stories")
            val response = apiManager.getStories(fs, 1, StoryOrder.NEWEST, ReadFilter.ALL)
            if (response?.stories == null) {
                Log.d(TAG, "Error fetching widget stories")
            } else {
                Log.d(TAG, "Fetched widget stories")
                processStories(response.stories)
                dbHelper.insertStories(response, true)
            }
        }
    }

    /**
     * Called when the last RemoteViewsAdapter that is associated with this factory is
     * unbound.
     */
    override fun onDestroy() {
        Log.d(TAG, "onDestroy")
        cancellationSignal.cancel()
        WidgetUtils.disableWidgetUpdate(context)
        PrefsUtils.removeWidgetData(context)
    }

    /**
     * @return Count of items.
     */
    override fun getCount(): Int = min(storyItems.size, WidgetUtils.STORIES_LIMIT)

    private fun processStories(stories: Array<Story>) {
        Log.d(TAG, "processStories")
        val feedMap = HashMap<String, Feed>()
        NBScope.executeAsyncTask(
                doInBackground = {
                    dbHelper.getFeedsCursor(cancellationSignal)
                },
                onPostExecute = {
                    while (it != null && it.moveToNext()) {
                        val feed = Feed.fromCursor(it)
                        if (feed.active) {
                            feedMap[feed.feedId] = feed
                        }
                    }
                    setStories(stories, feedMap)
                }
        )
    }

    private fun setStories(stories: Array<Story>, feedMap: HashMap<String, Feed>) {
        Log.d(TAG, "setStories")
        for (story in stories) {
            val storyFeed = feedMap[story.feedId]
            storyFeed?.let { bindStoryValues(story, it) }
        }
        storyItems.clear()
        storyItems.addAll(mutableListOf(*stories))
        // we have the data, notify data set changed
        dataCompleted = true
        invalidate()
    }

    private fun bindStoryValues(story: Story, feed: Feed) {
        story.thumbnailUrl = Story.guessStoryThumbnailURL(story)
        story.extern_faviconBorderColor = feed.faviconBorder
        story.extern_faviconUrl = feed.faviconUrl
        story.extern_feedTitle = feed.title
        story.extern_feedFade = feed.faviconFade
        story.extern_feedColor = feed.faviconColor
    }

    private fun invalidate() {
        Log.d(TAG, "Invalidate app widget with id: $appWidgetId")
        val appWidgetManager = AppWidgetManager.getInstance(context)
        appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.widget_list)
    }

    private fun setFeedSet() {
        val feedIds = PrefsUtils.getWidgetFeedIds(context)
        fs = if (feedIds == null || feedIds.isNotEmpty()) {
            FeedSet.widgetFeeds(feedIds)
        } else {
            // no feeds selected. Widget will show tap to config view
            null
        }
    }

    companion object {
        private const val TAG = "WidgetRemoteViewsFactory"
    }

    @EntryPoint
    @InstallIn(SingletonComponent::class)
    interface WidgetRemoteViewsFactoryEntryPoint {

        fun apiManager(): APIManager

        fun dbHelper(): BlurDatabaseHelper

        @IconLoader
        fun iconLoader(): ImageLoader

        @ThumbnailLoader
        fun thumbnailLoader(): ImageLoader
    }
}