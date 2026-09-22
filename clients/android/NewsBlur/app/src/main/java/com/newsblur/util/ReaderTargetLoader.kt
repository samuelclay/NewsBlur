package com.newsblur.util

import com.newsblur.database.BlurDatabaseHelper
import com.newsblur.domain.Story
import com.newsblur.network.StoryApi
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.withTimeoutOrNull
import javax.inject.Inject

class ReaderTargetLoader @Inject constructor(
    private val storyApi: StoryApi,
    private val dbHelper: BlurDatabaseHelper,
) {
    suspend fun load(hash: String): Story? =
        try {
            withTimeoutOrNull(20_000L) {
                val response = storyApi.getStoriesByHash(listOf(hash)) ?: return@withTimeoutOrNull null
                currentCoroutineContext().ensureActive()
                if (response.isError || response.code < 0) return@withTimeoutOrNull null
                val target = response.stories?.firstOrNull { it.storyHash == hash } ?: return@withTimeoutOrNull null
                // ReaderTargetLoader.kt leaves session membership alone; Reading.kt merges this target into its own batch.
                // BlurDatabaseHelper.java normalizes the hash response against known local read state before returning it.
                dbHelper.insertStories(response, StateFilter.ALL, false)
                dbHelper.getFeed(target.feedId)?.let { feed ->
                    target.extern_feedTitle = feed.title
                    target.extern_feedColor = feed.faviconColor
                    target.extern_feedFade = feed.faviconFade
                    target.extern_faviconUrl = feed.faviconUrl
                    target.extern_faviconTextColor = feed.faviconText
                    target.extern_faviconBorderColor = feed.faviconBorder
                }
                target
            }
        } catch (cancelled: CancellationException) {
            throw cancelled
        } catch (_: Exception) {
            null
        }
}
