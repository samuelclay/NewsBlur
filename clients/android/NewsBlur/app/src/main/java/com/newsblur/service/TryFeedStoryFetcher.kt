package com.newsblur.service

import com.newsblur.network.StoryApi
import com.newsblur.network.domain.StoriesResponse
import com.newsblur.util.FeedSet
import com.newsblur.util.ReadFilter
import com.newsblur.util.StoryOrder
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.delay
import kotlinx.coroutines.withTimeoutOrNull

/** TryFeedStoryFetcher.kt bounds the initial empty-feed refresh independently of pagination. */
internal class TryFeedStoryFetcher(
    private val api: StoryApi,
    private val pollMillis: Long = 2_000,
    private val timeoutMillis: Long = 60_000,
) {
    sealed interface Result {
        data class Complete(val response: StoriesResponse) : Result
        data object Failed : Result
        data object Stale : Result
    }

    suspend fun refresh(
        feedId: String,
        order: StoryOrder,
        filter: ReadFilter,
        isCurrent: () -> Boolean,
    ): Result = try {
        withTimeoutOrNull(timeoutMillis) {
            var forceRefresh = true
            while (true) {
                if (!isCurrent()) return@withTimeoutOrNull Result.Stale
                val response = api.getTryFeedStories(feedId, order, filter, forceRefresh)
                if (!isCurrent()) return@withTimeoutOrNull Result.Stale
                if (response == null || response.isError || response.feedId != feedId || response.stories == null) {
                    return@withTimeoutOrNull Result.Failed
                }
                if (response.stories.isNotEmpty()) return@withTimeoutOrNull Result.Complete(response)
                if (response.hasException == true) return@withTimeoutOrNull Result.Failed
                if (response.notYetFetched != true && response.fetchedOnce != false) {
                    return@withTimeoutOrNull Result.Complete(response)
                }
                forceRefresh = false
                delay(pollMillis)
            }
            @Suppress("UNREACHABLE_CODE")
            Result.Failed
        } ?: Result.Failed
    } catch (e: CancellationException) {
        throw e
    } catch (_: Exception) {
        Result.Failed
    }

    companion object {
        fun shouldRefresh(fs: FeedSet, page: Int, response: StoriesResponse?, isTryFeed: Boolean): Boolean =
            isTryFeed && page == 1 && fs.getSingleFeed() != null && fs.searchQuery == null && !fs.isFilterSaved &&
                response != null && !response.isError && response.feedId == fs.getSingleFeed() && response.stories?.isEmpty() == true
    }
}

enum class TryFeedRefreshStatus { NONE, FETCHING, EMPTY, FAILED }
