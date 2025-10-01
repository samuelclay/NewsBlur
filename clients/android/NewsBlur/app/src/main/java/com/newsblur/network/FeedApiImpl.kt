package com.newsblur.network

import android.content.ContentValues
import com.google.gson.Gson
import com.newsblur.domain.ValueMultimap
import com.newsblur.network.domain.FeedFolderResponse
import com.newsblur.network.domain.NewsBlurResponse
import com.newsblur.network.domain.UnreadCountResponse
import com.newsblur.util.FeedSet

class FeedApiImpl(
        private val gson: Gson,
        private val apiManager: APIManager,
) : FeedApi {

    override fun markFeedsAsRead(fs: FeedSet, includeOlder: Long?, includeNewer: Long?): NewsBlurResponse? {
        val values = ValueMultimap()

        if (fs.getSingleFeed() != null) {
            values.put(APIConstants.PARAMETER_FEEDID, fs.getSingleFeed())
        } else if (fs.multipleFeeds != null) {
            for (feedId in fs.multipleFeeds) {
                // the API isn't supposed to care if the zero-id pseudo feed gets mentioned, but it seems to
                // error out for some users
                if (feedId != "0") {
                    values.put(APIConstants.PARAMETER_FEEDID, feedId)
                }
            }
        } else if (fs.singleSocialFeed != null) {
            values.put(APIConstants.PARAMETER_FEEDID, APIConstants.VALUE_PREFIX_SOCIAL + fs.singleSocialFeed.key)
        } else if (fs.multipleSocialFeeds != null) {
            for (entry in fs.multipleSocialFeeds.entries) {
                values.put(APIConstants.PARAMETER_FEEDID, APIConstants.VALUE_PREFIX_SOCIAL + entry.key)
            }
        } else if (fs.isAllNormal) {
            // all stories uses a special API call
            return markAllAsRead()
        } else if (fs.isAllSocial) {
            values.put(APIConstants.PARAMETER_FEEDID, APIConstants.VALUE_ALLSOCIAL)
        } else {
            throw IllegalStateException("Asked to get stories for FeedSet of unknown type.")
        }

        if (includeOlder != null) {
            // the app uses  milliseconds but the API wants seconds
            val cut = includeOlder
            values.put(APIConstants.PARAMETER_CUTOFF_TIME, (cut / 1000L).toString())
            values.put(APIConstants.PARAMETER_DIRECTION, APIConstants.VALUE_OLDER)
        }
        if (includeNewer != null) {
            // the app uses  milliseconds but the API wants seconds
            val cut = includeNewer
            values.put(APIConstants.PARAMETER_CUTOFF_TIME, (cut / 1000L).toString())
            values.put(APIConstants.PARAMETER_DIRECTION, APIConstants.VALUE_NEWER)
        }

        val urlString = APIConstants.buildUrl(APIConstants.PATH_MARK_FEED_AS_READ)
        val response: APIResponse = apiManager.post(urlString, values)
        return response.getResponse(gson, NewsBlurResponse::class.java)
    }

    override fun getFeedUnreadCounts(apiIds: MutableSet<String?>): UnreadCountResponse? {
        val values = ValueMultimap().apply {
            for (id in apiIds) {
                put(APIConstants.PARAMETER_FEEDID, id)
            }
        }
        val urlString = APIConstants.buildUrl(APIConstants.PATH_FEED_UNREAD_COUNT)
        val response: APIResponse = apiManager.get(urlString, values)
        return response.getResponse(gson, UnreadCountResponse::class.java)
    }

    /**
     * Fetch the list of feeds/folders/socials from the backend.
     *
     * @param doUpdateCounts forces a refresh of unread counts.  This has a high latency
     * cost and should not be set if the call is being used to display the UI for
     * the first time, in which case it is more appropriate to make a separate,
     * additional call to refreshFeedCounts().
     */
    override fun getFolderFeedMapping(doUpdateCounts: Boolean): FeedFolderResponse? {
        val params = ContentValues().apply {
            put(APIConstants.PARAMETER_UPDATE_COUNTS, (if (doUpdateCounts) "true" else "false"))
        }
        val urlString = APIConstants.buildUrl(APIConstants.PATH_FEEDS)
        val response: APIResponse = apiManager.get(urlString, params)

        if (response.isError) {
            // we can't use the magic polymorphism of NewsBlurResponse because this result uses
            // a custom parser below. let the caller know the action failed.
            return null
        }

        // note: this response is complex enough, we have to do a custom parse in the FFR
        val result = FeedFolderResponse(response.getResponseBody(), gson)
        // bind a little extra instrumentation to this response, since it powers the feedback link
        result.connTime = response.connectTime
        result.readTime = response.readTime
        return result
    }

    private fun markAllAsRead(): NewsBlurResponse? {
        val values = ValueMultimap().apply {
            put(APIConstants.PARAMETER_DAYS, "0")
        }
        val urlString = APIConstants.buildUrl(APIConstants.PATH_MARK_ALL_AS_READ)
        val response: APIResponse = apiManager.post(urlString, values)
        return response.getResponse(gson, NewsBlurResponse::class.java)
    }
}