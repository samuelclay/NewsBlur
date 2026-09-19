package com.newsblur.discover

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.newsblur.activity.FeedItemsList
import com.newsblur.activity.NbActivity
import com.newsblur.util.AppConstants
import com.newsblur.util.FeedSet
import com.newsblur.util.FeedUtils
import com.newsblur.util.TryFeedStore
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

// DiscoveryActionEffects.kt keeps subscription sync and exact-story routing identical in every discovery host.
@Composable
internal fun DiscoveryActionEffects(activity: NbActivity, model: DiscoveryViewModel, tryFeedStore: TryFeedStore) {
    val state by model.state.collectAsStateWithLifecycle()
    LaunchedEffect(state.revision) {
        val (folders, subscribed) = withContext(Dispatchers.IO) {
            activity.dbHelper.folders to activity.dbHelper.allFeeds
                .mapNotNull { activity.dbHelper.getFeed(it)?.address }.toSet()
        }
        model.setFolders(folders, subscribed)
        if (state.revision > 0) {
            activity.syncServiceState.forceFeedsFolders()
            FeedUtils.triggerSync(activity)
        }
    }
    LaunchedEffect(state.preview) {
        state.preview?.let { feed ->
            val storyHash = state.previewStoryHash
            val subscribed = withContext(Dispatchers.IO) { activity.dbHelper.getFeed(feed.feedId) }
            if (subscribed != null || feed.address in state.added) {
                if (tryFeedStore.isTryFeed(feed.feedId)) tryFeedStore.clear()
                if (storyHash != null) {
                    FeedItemsList.startStoryActivity(
                        activity, FeedSet.singleFeed(feed.feedId), subscribed ?: feed,
                        AppConstants.ROOT_FOLDER, storyHash,
                    )
                } else {
                    FeedItemsList.startActivity(
                        activity, FeedSet.singleFeed(feed.feedId), subscribed ?: feed,
                        AppConstants.ROOT_FOLDER, null, null,
                    )
                }
            } else {
                tryFeedStore.set(feed)
                FeedItemsList.startTryFeedActivity(activity, feed, storyHash)
            }
            model.previewOpened()
        }
    }
}
