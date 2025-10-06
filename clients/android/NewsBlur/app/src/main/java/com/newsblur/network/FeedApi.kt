package com.newsblur.network

import com.newsblur.domain.Classifier
import com.newsblur.domain.FeedResult
import com.newsblur.network.domain.AddFeedResponse
import com.newsblur.network.domain.FeedFolderResponse
import com.newsblur.network.domain.NewsBlurResponse
import com.newsblur.network.domain.UnreadCountResponse
import com.newsblur.util.FeedSet

interface FeedApi {

    // TODO suspend
    fun markFeedsAsRead(fs: FeedSet, includeOlder: Long?, includeNewer: Long?): NewsBlurResponse?

    // TODO suspend
    fun getFeedUnreadCounts(apiIds: MutableSet<String>): UnreadCountResponse?

    // TODO suspend
    fun getFolderFeedMapping(doUpdateCounts: Boolean): FeedFolderResponse?

    // TODO suspend
    fun updateFeedIntel(feedId: String?, classifier: Classifier): NewsBlurResponse?

    suspend fun addFeed(feedUrl: String?, folderName: String?): AddFeedResponse?

    suspend fun searchForFeed(searchTerm: String?): Array<FeedResult>?

    suspend fun deleteFeed(feedId: String?, folderName: String?): NewsBlurResponse?

    suspend fun deleteSearch(feedId: String?, query: String?): NewsBlurResponse?

    suspend fun saveSearch(feedId: String?, query: String?): NewsBlurResponse?

    // TODO suspend
    fun saveFeedChooser(feeds: MutableSet<String?>): NewsBlurResponse?

    // TODO suspend
    fun updateFeedNotifications(feedId: String?, notifyTypes: MutableList<String?>, notifyFilter: String?): NewsBlurResponse?

    // TODO suspend
    fun instaFetch(feedId: String?): NewsBlurResponse?

    // TODO suspend
    fun renameFeed(feedId: String?, newFeedName: String?): NewsBlurResponse?
}