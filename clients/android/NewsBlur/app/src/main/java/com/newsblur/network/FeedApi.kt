package com.newsblur.network

import com.newsblur.domain.Classifier
import com.newsblur.domain.FeedResult
import com.newsblur.network.domain.AddFeedResponse
import com.newsblur.network.domain.FeedFolderResponse
import com.newsblur.network.domain.NewsBlurResponse
import com.newsblur.network.domain.UnreadCountResponse
import com.newsblur.util.FeedSet

interface FeedApi {
    suspend fun markFeedsAsRead(
        fs: FeedSet,
        includeOlder: Long?,
        includeNewer: Long?,
    ): NewsBlurResponse?

    suspend fun getFeedUnreadCounts(apiIds: MutableSet<String>): UnreadCountResponse?

    suspend fun getFolderFeedMapping(doUpdateCounts: Boolean): FeedFolderResponse?

    suspend fun updateFeedIntel(
        feedId: String?,
        classifier: Classifier?,
    ): NewsBlurResponse?

    suspend fun addFeed(
        feedUrl: String?,
        folderName: String?,
    ): AddFeedResponse?

    suspend fun searchForFeed(searchTerm: String?): Array<FeedResult>?

    suspend fun deleteFeed(
        feedId: String?,
        folderName: String?,
    ): NewsBlurResponse?

    suspend fun deleteSearch(
        feedId: String?,
        query: String?,
    ): NewsBlurResponse?

    suspend fun saveSearch(
        feedId: String?,
        query: String?,
    ): NewsBlurResponse?

    suspend fun saveFeedChooser(feeds: Set<String>): NewsBlurResponse?

    suspend fun setFeedMute(
        feedId: String,
        mute: Boolean,
    ): NewsBlurResponse?

    suspend fun updateFeedNotifications(
        feedId: String?,
        notifyTypes: List<String>,
        notifyFilter: String?,
    ): NewsBlurResponse?

    suspend fun instaFetch(feedId: String?): NewsBlurResponse?

    suspend fun renameFeed(
        feedId: String?,
        newFeedName: String?,
    ): NewsBlurResponse?
}
