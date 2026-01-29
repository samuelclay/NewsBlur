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
import com.newsblur.network.StoryApi
import com.newsblur.preference.PrefsRepo
import com.newsblur.util.CursorFilters
import com.newsblur.util.FeedSet
import com.newsblur.util.ImageLoader
import com.newsblur.util.Log
import com.newsblur.util.ReadFilter
import com.newsblur.util.StoryOrder
import com.newsblur.util.StoryUtils
import com.newsblur.util.ThumbnailStyle
import com.newsblur.util.UIUtils
import dagger.hilt.android.EntryPointAccessors
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeout
import java.util.concurrent.locks.ReentrantLock
import kotlin.concurrent.withLock
import kotlin.math.min

class WidgetRemoteViewsFactory(
    context: Context,
    intent: Intent,
) : RemoteViewsFactory {
    private val context: Context
    private val storyApi: StoryApi
    private val dbHelper: BlurDatabaseHelper
    private val iconLoader: ImageLoader
    private val thumbnailLoader: ImageLoader
    private val prefsRepo: PrefsRepo
    private val appWidgetId: Int

    private val storyItems: MutableList<Story> = mutableListOf()
    private var cancellationSignal: CancellationSignal? = null

    private val storiesLock = ReentrantLock()

    init {
        Log.d(this.javaClass.name, "init")
        val hiltEntryPoint =
            EntryPointAccessors
                .fromApplication(context.applicationContext, WidgetRemoteViewsFactoryEntryPoint::class.java)
        this.context = context
        this.storyApi = hiltEntryPoint.storyApi()
        this.dbHelper = hiltEntryPoint.dbHelper()
        this.iconLoader = hiltEntryPoint.iconLoader()
        this.thumbnailLoader = hiltEntryPoint.thumbnailLoader()
        this.prefsRepo = hiltEntryPoint.prefRepository()
        appWidgetId =
            intent.getIntExtra(
                AppWidgetManager.EXTRA_APPWIDGET_ID,
                AppWidgetManager.INVALID_APPWIDGET_ID,
            )
    }

    /**
     * The system calls onCreate() when creating your factory for the first time.
     */
    override fun onCreate() {
        Log.d(this.javaClass.name, "onCreate")
    }

    override fun getViewAt(position: Int): RemoteViews =
        storiesLock.withLock {
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
            if (prefsRepo.getThumbnailStyle() != ThumbnailStyle.OFF && !TextUtils.isEmpty(story.thumbnailUrl)) {
                thumbnailLoader.displayWidgetImage(story.thumbnailUrl, R.id.story_item_thumbnail, UIUtils.dp2px(context, 64), rv)
            } else {
                rv.setViewVisibility(R.id.story_item_thumbnail, View.GONE)
            }
            rv.setViewBackgroundColor(
                R.id.story_item_favicon_borderbar_1,
                UIUtils.decodeColourValue(story.extern_feedColor, Color.GRAY),
            )
            rv.setViewBackgroundColor(
                R.id.story_item_favicon_borderbar_2,
                UIUtils.decodeColourValue(story.extern_feedFade, Color.LTGRAY),
            )

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
    override fun getItemId(position: Int): Long =
        storiesLock.withLock {
            storyItems[position].hashCode().toLong()
        }

    /**
     * @return True if the same id always refers to the same object.
     */
    override fun hasStableIds(): Boolean = true

    /**
     * Heavy lifting like downloading or creating content etc, should be deferred to onDataSetChanged()
     */
    override fun onDataSetChanged() =
        storiesLock.withLock {
            Log.d(this.javaClass.name, "onDataSetChanged")
            // if user logged out don't try to update widget
            if (!WidgetUtils.isLoggedIn(prefsRepo)) {
                Log.d(this.javaClass.name, "onDataSetChanged - not logged in")
                return@withLock
            }

            // get fs based on pref widget feed ids
            val feedIds = prefsRepo.getWidgetFeedIds()
            val fs =
                if (feedIds == null || feedIds.isNotEmpty()) {
                    // null feed ids get all feeds
                    FeedSet.widgetFeeds(feedIds)
                } else {
                    null // intentionally no feeds selected.
                }

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
                        val response = storyApi.getStories(fs, 1, StoryOrder.NEWEST, ReadFilter.ALL, prefsRepo.getInfrequentCutoff())
                        response?.stories?.let {
                            val stateFilter = prefsRepo.getStateFilter()
                            Log.d(this.javaClass.name, "onDataSetChanged - got ${it.size} remote stories")
                            processStories(response.stories)
                            dbHelper.insertStories(response, stateFilter, true)
                        }
                            ?: Log.d(this.javaClass.name, "onDataSetChanged - null remote stories")
                    }
                } catch (e: Exception) {
                    Log.e(this.javaClass.name, "onDataSetChanged - remote fetch failed", e)
                    if (storyItems.isEmpty()) {
                        val cached = loadCachedStoriesForWidget(fs)
                        if (cached.isNotEmpty()) {
                            processStories(cached.toTypedArray())
                        }
                    }
                }
            }
        }

    /**
     * Called when the last RemoteViewsAdapter that is associated with this factory is
     * unbound.
     */
    override fun onDestroy() {
        Log.d(this.javaClass.name, "onDestroy")
        cancellationSignal?.cancel()
        cancellationSignal = null
    }

    /**
     * @return Count of items.
     */
    override fun getCount(): Int =
        storiesLock.withLock {
            min(storyItems.size, WidgetUtils.STORIES_LIMIT)
        }

    /**
     * Widget will show tap to config view when
     * empty stories and feeds maps are used
     */
    private fun processStories(stories: Array<Story>) =
        storiesLock.withLock {
            Log.d(this.javaClass.name, "processStories")
            val signal = CancellationSignal()
            cancellationSignal = signal
            val feedMap = mutableMapOf<String, Feed>()
            dbHelper.getFeedsCursor(signal).use { cursor ->
                while (cursor.moveToNext()) {
                    val feed = Feed.fromCursor(cursor)
                    if (feed.active) {
                        feedMap[feed.feedId] = feed
                    }
                }
            }

            val filtered =
                if (feedMap.isEmpty()) {
                    Log.d(this.javaClass.name, "processStories - feedMap empty, skipping active filter")
                    stories.toList()
                } else {
                    stories.filter { feedMap.containsKey(it.feedId) }
                }

            for (story in filtered) {
                val feed = feedMap[story.feedId]
                if (feed != null) {
                    bindStoryValues(story, feed)
                }
            }
            storyItems.clear()
            storyItems.addAll(filtered)
        }

    private fun bindStoryValues(
        story: Story,
        feed: Feed,
    ) = story.apply {
        thumbnailUrl = Story.guessStoryThumbnailURL(story)
        extern_faviconBorderColor = feed.faviconBorder
        extern_faviconUrl = feed.faviconUrl
        extern_feedTitle = feed.title
        extern_feedFade = feed.faviconFade
        extern_feedColor = feed.faviconColor
    }

    private fun loadCachedStoriesForWidget(fs: FeedSet): List<Story> {
        val signal = CancellationSignal()
        val filters =
            CursorFilters(
                stateFilter = prefsRepo.getStateFilter(),
                readFilter = ReadFilter.ALL,
                storyOrder = StoryOrder.NEWEST,
            )

        return try {
            dbHelper.getActiveStoriesCursor(fs, filters, signal).use { c ->
                val out = ArrayList<Story>(WidgetUtils.STORIES_LIMIT)
                if (c.moveToFirst()) {
                    do {
                        out.add(Story.fromCursor(c))
                    } while (out.size < WidgetUtils.STORIES_LIMIT && c.moveToNext())
                }
                out
            }
        } catch (e: Exception) {
            Log.e(this.javaClass.name, "loadCachedStoriesForWidget failed", e)
            emptyList()
        }
    }
}
