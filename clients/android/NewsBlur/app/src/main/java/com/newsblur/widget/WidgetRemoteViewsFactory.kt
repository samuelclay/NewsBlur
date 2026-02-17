package com.newsblur.widget

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import android.widget.RemoteViewsService.RemoteViewsFactory
import com.newsblur.R
import com.newsblur.database.BlurDatabaseHelper
import com.newsblur.domain.Story
import com.newsblur.network.StoryApi
import com.newsblur.preference.PrefsRepo
import com.newsblur.util.ImageLoader
import com.newsblur.util.Log
import dagger.hilt.android.EntryPointAccessors
import kotlinx.coroutines.runBlocking
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
            if (position < 0 || position >= storyItems.size) {
                Log.d(this.javaClass.name, "getViewAt $position not in story collection range")
                return WidgetRemoteViews(context.packageName, R.layout.view_widget_story_item)
            }

            val story = storyItems[position]
            return WidgetRow.create(
                context = context,
                prefsRepo = prefsRepo,
                iconLoader = iconLoader,
                thumbnailLoader = thumbnailLoader,
                story = story,
            )
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
            storyItems
                .getOrNull(position)
                ?.storyHash
                ?.let(WidgetRow::id64)
                ?: position.toLong()
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
            runBlocking {
                val result =
                    WidgetRepository.loadForWidget(
                        prefsRepo = prefsRepo,
                        storyApi = storyApi,
                        dbHelper = dbHelper,
                    )
                storyItems.clear()
                storyItems.addAll(result.stories)

                WidgetImage.prefetch(
                    context = context,
                    prefsRepo = prefsRepo,
                    iconLoader = iconLoader,
                    thumbnailLoader = thumbnailLoader,
                    stories = storyItems,
                )
            }
        }

    /**
     * Called when the last RemoteViewsAdapter that is associated with this factory is
     * unbound.
     */
    override fun onDestroy() {
        Log.d(this.javaClass.name, "onDestroy")
    }

    /**
     * @return Count of items.
     */
    override fun getCount(): Int =
        storiesLock.withLock {
            min(storyItems.size, WidgetUtils.STORIES_LIMIT)
        }
}
