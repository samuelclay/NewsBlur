package com.newsblur.widget

import android.os.CancellationSignal
import com.newsblur.database.BlurDatabaseHelper
import com.newsblur.domain.Feed
import com.newsblur.domain.Story
import com.newsblur.network.StoryApi
import com.newsblur.preference.PrefsRepo
import com.newsblur.util.CursorFilters
import com.newsblur.util.FeedSet
import com.newsblur.util.Log
import com.newsblur.util.ReadFilter
import com.newsblur.util.StoryOrder
import kotlinx.coroutines.withTimeout

object WidgetRepository {
    data class Result(
        val stories: List<Story>,
        val showSetupEmptyText: Boolean,
        val loggedIn: Boolean,
    )

    suspend fun loadForWidget(
        prefsRepo: PrefsRepo,
        storyApi: StoryApi,
        dbHelper: BlurDatabaseHelper,
    ): Result {
        val loggedIn = WidgetUtils.isLoggedIn(prefsRepo)
        if (!loggedIn) {
            return Result(emptyList(), showSetupEmptyText = false, loggedIn = false)
        }

        val feedIds = prefsRepo.getWidgetFeedIds()
        val showSetupEmptyText = (feedIds != null && feedIds.isEmpty())

        val fs =
            if (feedIds == null || feedIds.isNotEmpty()) {
                FeedSet.widgetFeeds(feedIds)
            } else {
                null // intentionally no feeds selected
            }

        if (fs == null) {
            return Result(emptyList(), showSetupEmptyText = true, loggedIn = true)
        }

        val stories: List<Story> =
            try {
                withTimeout(18_000) {
                    val response =
                        storyApi.getStories(
                            fs,
                            1,
                            StoryOrder.NEWEST,
                            ReadFilter.ALL,
                            prefsRepo.getInfrequentCutoff(),
                        )
                    val remote = response?.stories?.toList()
                    if (!remote.isNullOrEmpty()) {
                        val bound = bindFeedFields(dbHelper, remote)
                        dbHelper.insertStories(response, prefsRepo.getStateFilter(), true)
                        bound
                    } else {
                        bindFeedFields(dbHelper, loadCached(dbHelper, prefsRepo, fs))
                    }
                }
            } catch (e: Exception) {
                Log.e("WidgetRepository", "remote fetch failed", e)
                bindFeedFields(dbHelper, loadCached(dbHelper, prefsRepo, fs))
            }

        return Result(
            stories = stories.take(WidgetUtils.STORIES_LIMIT),
            showSetupEmptyText = showSetupEmptyText,
            loggedIn = true,
        )
    }

    private fun loadCached(
        dbHelper: BlurDatabaseHelper,
        prefsRepo: PrefsRepo,
        fs: FeedSet,
    ): List<Story> {
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
            Log.e("WidgetRepository", "loadCached failed", e)
            emptyList()
        }
    }

    private fun bindFeedFields(
        dbHelper: BlurDatabaseHelper,
        stories: List<Story>,
    ): List<Story> {
        if (stories.isEmpty()) return stories

        val signal = CancellationSignal()
        val feedMap = mutableMapOf<String, Feed>()
        dbHelper.getFeedsCursor(signal).use { cursor ->
            while (cursor.moveToNext()) {
                val feed = Feed.fromCursor(cursor)
                if (feed.active) feedMap[feed.feedId] = feed
            }
        }

        val filtered =
            if (feedMap.isEmpty()) {
                stories
            } else {
                stories.filter { feedMap.containsKey(it.feedId) }
            }

        filtered.forEach { s ->
            val feed = feedMap[s.feedId] ?: return@forEach
            if (s.thumbnailUrl.isNullOrBlank()) {
                s.thumbnailUrl = Story.guessStoryThumbnailURL(s)
            }
            s.extern_faviconBorderColor = feed.faviconBorder
            s.extern_faviconUrl = feed.faviconUrl
            s.extern_feedTitle = feed.title
            s.extern_feedFade = feed.faviconFade
            s.extern_feedColor = feed.faviconColor
        }

        return filtered
    }
}
