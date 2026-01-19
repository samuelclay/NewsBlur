package com.newsblur.network

import android.content.ContentValues
import android.text.TextUtils
import com.google.gson.Gson
import com.newsblur.domain.Classifier
import com.newsblur.domain.FeedResult
import com.newsblur.domain.ValueMultimap
import com.newsblur.network.domain.AddFeedResponse
import com.newsblur.network.domain.FeedFolderResponse
import com.newsblur.network.domain.NewsBlurResponse
import com.newsblur.network.domain.UnreadCountResponse
import com.newsblur.util.AppConstants
import com.newsblur.util.FeedSet

class FeedApiImpl(
    private val gson: Gson,
    private val networkClient: NetworkClient,
) : FeedApi {
    override suspend fun markFeedsAsRead(
        fs: FeedSet,
        includeOlder: Long?,
        includeNewer: Long?,
    ): NewsBlurResponse? {
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
        val response: APIResponse = networkClient.post(urlString, values)
        return response.getResponse(gson, NewsBlurResponse::class.java)
    }

    override suspend fun getFeedUnreadCounts(apiIds: MutableSet<String>): UnreadCountResponse? {
        val values =
            ValueMultimap().apply {
                for (id in apiIds) {
                    put(APIConstants.PARAMETER_FEEDID, id)
                }
            }
        val urlString = APIConstants.buildUrl(APIConstants.PATH_FEED_UNREAD_COUNT)
        val response: APIResponse = networkClient.get(urlString, values)
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
    override suspend fun getFolderFeedMapping(doUpdateCounts: Boolean): FeedFolderResponse? {
        val params =
            ContentValues().apply {
                put(APIConstants.PARAMETER_UPDATE_COUNTS, (if (doUpdateCounts) APIConstants.VALUE_TRUE else APIConstants.VALUE_FALSE))
            }
        val urlString = APIConstants.buildUrl(APIConstants.PATH_FEEDS)
        val response: APIResponse = networkClient.get(urlString, params)

        if (response.isError) {
            // we can't use the magic polymorphism of NewsBlurResponse because this result uses
            // a custom parser below. let the caller know the action failed.
            return null
        }

        // note: this response is complex enough, we have to do a custom parse in the FFR
        val result = FeedFolderResponse(response.responseBody, gson)
        // bind a little extra instrumentation to this response, since it powers the feedback link
        result.connTime = response.connectTime
        result.readTime = response.readTime
        return result
    }

    override suspend fun updateFeedIntel(
        feedId: String?,
        classifier: Classifier?,
    ): NewsBlurResponse? {
        val values = classifier?.getAPITuples() ?: return null
        values.put(APIConstants.PARAMETER_FEEDID, feedId)
        val urlString = APIConstants.buildUrl(APIConstants.PATH_CLASSIFIER_SAVE)
        val response: APIResponse = networkClient.post(urlString, values)
        return response.getResponse(gson, NewsBlurResponse::class.java)
    }

    override suspend fun addFeed(
        feedUrl: String?,
        folderName: String?,
    ): AddFeedResponse? {
        val values = ContentValues()
        values.put(APIConstants.PARAMETER_URL, feedUrl)
        if (!TextUtils.isEmpty(folderName) && folderName != AppConstants.ROOT_FOLDER) {
            values.put(APIConstants.PARAMETER_FOLDER, folderName)
        }
        val urlString = APIConstants.buildUrl(APIConstants.PATH_ADD_FEED)
        val response: APIResponse = networkClient.post(urlString, values)
        return response.getResponse(gson, AddFeedResponse::class.java)
    }

    override suspend fun searchForFeed(searchTerm: String?): Array<FeedResult>? {
        val values = ContentValues()
        values.put(APIConstants.PARAMETER_FEED_SEARCH_TERM, searchTerm)
        val urlString = APIConstants.buildUrl(APIConstants.PATH_FEED_AUTOCOMPLETE)
        val response: APIResponse = networkClient.get(urlString, values)

        return if (!response.isError) {
            gson.fromJson(response.responseBody, Array<FeedResult>::class.java)
        } else {
            null
        }
    }

    override suspend fun deleteFeed(
        feedId: String?,
        folderName: String?,
    ): NewsBlurResponse? {
        val values = ContentValues()
        values.put(APIConstants.PARAMETER_FEEDID, feedId)
        if ((!TextUtils.isEmpty(folderName)) && (folderName != AppConstants.ROOT_FOLDER)) {
            values.put(APIConstants.PARAMETER_IN_FOLDER, folderName)
        }
        val urlString = APIConstants.buildUrl(APIConstants.PATH_DELETE_FEED)
        val response: APIResponse = networkClient.post(urlString, values)
        return response.getResponse(gson, NewsBlurResponse::class.java)
    }

    override suspend fun deleteSearch(
        feedId: String?,
        query: String?,
    ): NewsBlurResponse? {
        val values = ContentValues()
        values.put(APIConstants.PARAMETER_FEEDID, feedId)
        values.put(APIConstants.PARAMETER_QUERY, query)
        val urlString = APIConstants.buildUrl(APIConstants.PATH_DELETE_SEARCH)
        val response: APIResponse = networkClient.post(urlString, values)
        return response.getResponse(gson, NewsBlurResponse::class.java)
    }

    override suspend fun saveSearch(
        feedId: String?,
        query: String?,
    ): NewsBlurResponse? {
        val values = ContentValues()
        values.put(APIConstants.PARAMETER_FEEDID, feedId)
        values.put(APIConstants.PARAMETER_QUERY, query)
        val urlString = APIConstants.buildUrl(APIConstants.PATH_SAVE_SEARCH)
        val response: APIResponse = networkClient.post(urlString, values)
        return response.getResponse(gson, NewsBlurResponse::class.java)
    }

    override suspend fun saveFeedChooser(feeds: Set<String>): NewsBlurResponse? {
        val values = ValueMultimap()
        for (feed in feeds) {
            values.put(APIConstants.PARAMETER_APPROVED_FEEDS, feed)
        }
        val urlString = APIConstants.buildUrl(APIConstants.PATH_SAVE_FEED_CHOOSER)
        val response: APIResponse = networkClient.post(urlString, values)
        return response.getResponse(gson, NewsBlurResponse::class.java)
    }

    override suspend fun setFeedMute(
        feedId: String,
        mute: Boolean,
    ): NewsBlurResponse? {
        val values = ContentValues()
        values.put(APIConstants.PARAMETER_FEEDID, feedId)
        values.put(APIConstants.PARAMETER_MUTE, if (mute) "true" else "false")
        val urlString = APIConstants.buildUrl(APIConstants.PATH_SET_FEED_MUTE)
        val response: APIResponse = networkClient.post(urlString, values)
        return response.getResponse(gson, NewsBlurResponse::class.java)
    }

    override suspend fun updateFeedNotifications(
        feedId: String?,
        notifyTypes: List<String>,
        notifyFilter: String?,
    ): NewsBlurResponse? {
        val values = ValueMultimap()
        values.put(APIConstants.PARAMETER_FEEDID, feedId)
        for (type in notifyTypes) {
            values.put(APIConstants.PARAMETER_NOTIFICATION_TYPES, type)
        }
        if (notifyFilter != null) values.put(APIConstants.PARAMETER_NOTIFICATION_FILTER, notifyFilter)
        val urlString = APIConstants.buildUrl(APIConstants.PATH_SET_NOTIFICATIONS)
        val response: APIResponse = networkClient.post(urlString, values)
        return response.getResponse(gson, NewsBlurResponse::class.java)
    }

    override suspend fun instaFetch(feedId: String?): NewsBlurResponse? {
        val values = ValueMultimap()
        values.put(APIConstants.PARAMETER_FEEDID, feedId)
        // this param appears fixed and mandatory for the call to succeed
        values.put(APIConstants.PARAMETER_RESET_FETCH, APIConstants.VALUE_FALSE)
        val urlString = APIConstants.buildUrl(APIConstants.PATH_INSTA_FETCH)
        val response: APIResponse = networkClient.post(urlString, values)
        return response.getResponse(gson, NewsBlurResponse::class.java)
    }

    override suspend fun renameFeed(
        feedId: String?,
        newFeedName: String?,
    ): NewsBlurResponse? {
        val values = ValueMultimap()
        values.put(APIConstants.PARAMETER_FEEDID, feedId)
        values.put(APIConstants.PARAMETER_FEEDTITLE, newFeedName)
        val urlString = APIConstants.buildUrl(APIConstants.PATH_RENAME_FEED)
        val response: APIResponse = networkClient.post(urlString, values)
        return response.getResponse(gson, NewsBlurResponse::class.java)
    }

    private suspend fun markAllAsRead(): NewsBlurResponse? {
        val values =
            ValueMultimap().apply {
                put(APIConstants.PARAMETER_DAYS, "0")
            }
        val urlString = APIConstants.buildUrl(APIConstants.PATH_MARK_ALL_AS_READ)
        val response: APIResponse = networkClient.post(urlString, values)
        return response.getResponse(gson, NewsBlurResponse::class.java)
    }
}
