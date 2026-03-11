package com.newsblur.util

import com.newsblur.domain.Feed
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class TryFeedStore
    @Inject
    constructor() {
        @Volatile
        private var tryFeed: Feed? = null

        fun get(): Feed? = tryFeed

        fun set(feed: Feed) {
            feed.active = true
            tryFeed = feed
        }

        fun clear() {
            tryFeed = null
        }

        fun isTryFeed(feedId: String?): Boolean = tryFeed?.feedId == feedId
    }
