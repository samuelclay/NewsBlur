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
import com.newsblur.domain.Feed
import com.newsblur.domain.Story
import com.newsblur.network.APIManager
import com.newsblur.util.*
import dagger.hilt.android.EntryPointAccessors
import kotlinx.coroutines.TimeoutCancellationException
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeout
import java.util.concurrent.locks.ReentrantLock
import kotlin.concurrent.withLock
import kotlin.math.min

class WidgetRemoteViewsFactory(context: Context, intent: Intent) : RemoteViewsFactory {

    private val context: Context
    private val apiManager: APIManager
    private val dbHelper: BlurDatabaseHelper
    private val iconLoader: ImageLoader
    private val thumbnailLoader: ImageLoader
    private val appWidgetId: Int

    private val storyItems: MutableList<Story> = mutableListOf()
    private val cancellationSignal = CancellationSignal()

    private val storiesLock = ReentrantLock()

    init {
        Log.d(this.javaClass.name, "init")
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
     */
    override fun onCreate() {
        Log.d(this.javaClass.name, "onCreate")
        WidgetUtils.enableWidgetUpdate(context)
    }

    override fun getViewAt(position: Int): RemoteViews = storiesLock.withLock {
        Log.d(this.javaClass.name, "getViewAt $position")
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
    override fun getItemId(position: Int): Long = storiesLock.withLock {
        storyItems[position].hashCode().toLong()
    }

    /**
     * @return True if the same id always refers to the same object.
     */
    override fun hasStableIds(): Boolean = true

    /**
     * Heavy lifting like downloading or creating content etc, should be deferred to onDataSetChanged()
     */
    override fun onDataSetChanged() = storiesLock.withLock {
        Log.d(this.javaClass.name, "onDataSetChanged")
        // if user logged out don't try to update widget
        if (!WidgetUtils.isLoggedIn(context)) {
            Log.d(this.javaClass.name, "onDataSetChanged - not logged in")
            return@withLock
        }

        // get fs based on pref widget feed ids
        val feedIds = PrefsUtils.getWidgetFeedIds(context)
        val fs = if (feedIds == null || feedIds.isNotEmpty()) {
            // null feed ids get all feeds
            FeedSet.widgetFeeds(feedIds)
        } else null // intentionally no feeds selected.

        if (fs == null) {
            Log.d(this.javaClass.name, "onDataSetChanged - null fs cleared stories")
            storyItems.clear()
            return@withLock
        }

        runBlocking {
            try {
                // Taking more than 20 seconds in this method will result in an ANR.
                withTimeout(18000) {
                    Log.d(this.javaClass.name, "onDataSetChanged - get remote stories")
                    val response = apiManager.getStories(fs, 1, StoryOrder.NEWEST, ReadFilter.ALL)
                    response.stories?.let {
                        val stateFilter = PrefsUtils.getStateFilter(context)
                        Log.d(this.javaClass.name, "onDataSetChanged - got ${it.size} remote stories")
                        processStories(response.stories)
                        dbHelper.insertStories(response, stateFilter, true)
                    } ?: Log.d(this.javaClass.name, "onDataSetChanged - null remote stories")
                }
            } catch (e: TimeoutCancellationException) {
                Log.d(this.javaClass.name, "onDataSetChanged - timeout")
            }
        }
    }

    /**
     * Called when the last RemoteViewsAdapter that is associated with this factory is
     * unbound.
     */
    override fun onDestroy() {
        Log.d(this.javaClass.name, "onDestroy")
        cancellationSignal.cancel()
        WidgetUtils.disableWidgetUpdate(context)
        PrefsUtils.removeWidgetData(context)
    }

    /**
     * @return Count of items.
     */
    override fun getCount(): Int = storiesLock.withLock {
        min(storyItems.size, WidgetUtils.STORIES_LIMIT)
    }

    /**
     * Widget will show tap to config view when
     * empty stories and feeds maps are used
     */
    private fun processStories(stories: Array<Story>) = storiesLock.withLock {
        Log.d(this.javaClass.name, "processStories")
        val feedMap = mutableMapOf<String, Feed>()
        val cursor = dbHelper.getFeedsCursor(cancellationSignal)
        while (cursor != null && cursor.moveToNext()) {
            val feed = Feed.fromCursor(cursor)
            if (feed.active) {
                feedMap[feed.feedId] = feed
            }
        }

        for (story in stories) {
            val storyFeed = feedMap[story.feedId]
            storyFeed?.let { bindStoryValues(story, it) }
        }
        storyItems.clear()
        storyItems.addAll(stories.toList())
    }

    private fun bindStoryValues(story: Story, feed: Feed) = story.apply {
        thumbnailUrl = Story.guessStoryThumbnailURL(story)
        extern_faviconBorderColor = feed.faviconBorder
        extern_faviconUrl = feed.faviconUrl
        extern_feedTitle = feed.title
        extern_feedFade = feed.faviconFade
        extern_feedColor = feed.faviconColor
    }
}