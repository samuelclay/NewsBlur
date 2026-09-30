package com.newsblur.activity

import android.content.Context
import android.content.Intent
import android.os.Bundle
import com.newsblur.domain.Feed
import com.newsblur.util.FeedSet
import com.newsblur.util.SessionDataSource
import com.newsblur.util.StorySplitView
import com.newsblur.util.UIUtils
import dagger.hilt.android.AndroidEntryPoint

/**
 * One feed's stories. The toolbar, the try feed banner, the feed's own menu items and the saved
 * search id come from StoryListKind.kt. This list also asks for an app review on the way out.
 */
@AndroidEntryPoint
class FeedItemsList : ItemsList() {
    private val reviewHelper by lazy { InAppReviewHelper(this, prefsRepo) }

    override fun onCreate(bundle: Bundle?) {
        super.onCreate(bundle)
        reviewHelper.check()
    }

    // A tablet story list that switched to a folder in place doesn't ask for a review of a feed.
    override fun interceptBackPress(isGestureNavigation: Boolean): Boolean =
        kind is StoryListKind.Feed && reviewHelper.interceptBackPress(isGestureNavigation) { backToFeedList() }

    override fun shouldResetReadingSessionOnCreate(): Boolean =
        intent?.getBooleanExtra(EXTRA_IS_TRY_FEED, false) == true

    companion object {
        const val EXTRA_FEED: String = "feed"
        const val EXTRA_FOLDER_NAME: String = "folderName"
        const val EXTRA_IS_TRY_FEED: String = "is_try_feed"
        const val EXTRA_TRY_FEED_URL: String = "try_feed_url"

        @JvmStatic
        fun startActivity(
            context: Context,
            feedSet: FeedSet,
            feed: Feed?,
            folderName: String?,
            sessionDataSource: SessionDataSource?,
            storyListSessionDataSource: SessionDataSource?,
        ) {
            Intent(context, FeedItemsList::class.java)
                .apply {
                    putExtra(EXTRA_FEED, feed)
                    putExtra(EXTRA_FOLDER_NAME, folderName)
                    putExtra(EXTRA_FEED_SET, feedSet)
                    putSessionDataKeyExtra(this, sessionDataSource, storyListSessionDataSource)
                }.also { intent ->
                    StorySplitView.startStoryList(context, intent)
                }
        }

        @JvmStatic
        fun startStoryActivity(
            context: Context,
            feedSet: FeedSet,
            feed: Feed?,
            folderName: String?,
            storyHash: String,
        ) {
            Intent(context, FeedItemsList::class.java)
                .apply {
                    putExtra(EXTRA_FEED, feed)
                    putExtra(EXTRA_FOLDER_NAME, folderName)
                    putExtra(EXTRA_FEED_SET, feedSet)
                    putExtra(EXTRA_STORY_HASH, storyHash)
                    putExtra(EXTRA_AUTO_OPEN_STORY, true)
                    putExtra(Reading.EXTRA_TOOLBAR_HIDDEN, UIUtils.isReaderToolbarHidden(context))
                }.also { intent ->
                    StorySplitView.startStoryList(context, intent)
                }
        }

        @JvmStatic
        @JvmOverloads
        fun startTryFeedActivity(
            context: Context,
            feed: Feed,
            storyHash: String? = null,
        ) {
            Intent(context, FeedItemsList::class.java)
                .apply {
                    putExtra(EXTRA_FEED, feed)
                    putExtra(EXTRA_FOLDER_NAME, com.newsblur.util.AppConstants.ROOT_FOLDER)
                    putExtra(EXTRA_FEED_SET, FeedSet.singleFeed(feed.feedId))
                    putExtra(EXTRA_IS_TRY_FEED, true)
                    putExtra(EXTRA_TRY_FEED_URL, feed.address)
                    if (!storyHash.isNullOrBlank()) {
                        putExtra(EXTRA_STORY_HASH, storyHash)
                        putExtra(EXTRA_AUTO_OPEN_STORY, true)
                        putExtra(Reading.EXTRA_TOOLBAR_HIDDEN, UIUtils.isReaderToolbarHidden(context))
                    }
                }.also { intent ->
                    StorySplitView.startStoryList(context, intent)
                }
        }
    }
}
