package com.newsblur.network

import com.newsblur.network.domain.FeedFolderResponse
import com.newsblur.network.domain.NewsBlurResponse
import com.newsblur.network.domain.UnreadCountResponse
import com.newsblur.util.FeedSet

interface FeedApi {

    // TODO suspend
    fun markFeedsAsRead(fs: FeedSet, includeOlder: Long?, includeNewer: Long?): NewsBlurResponse?

    // TODO suspend
    fun getFeedUnreadCounts(apiIds: MutableSet<String?>): UnreadCountResponse?

    // TODO suspend
    fun getFolderFeedMapping(doUpdateCounts: Boolean): FeedFolderResponse?
}