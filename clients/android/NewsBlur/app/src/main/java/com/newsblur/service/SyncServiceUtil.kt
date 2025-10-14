package com.newsblur.service

import com.newsblur.network.domain.StoriesResponse
import com.newsblur.util.Log

object SyncServiceUtil {
    @JvmStatic
    fun isStoryResponseGood(response: StoriesResponse?): Boolean {
        if (response == null) {
            Log.e(this, "Null response received while loading stories.")
            return false
        }
        if (response.stories == null) {
            Log.e(this, "Null stories member received while loading stories.")
            return false
        }
        return true
    }
}
