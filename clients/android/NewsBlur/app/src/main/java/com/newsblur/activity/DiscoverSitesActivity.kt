package com.newsblur.activity

import android.os.Bundle
import androidx.activity.compose.setContent
import androidx.activity.viewModels
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.lifecycleScope
import com.newsblur.design.NewsBlurTheme
import com.newsblur.design.toVariant
import com.newsblur.di.IconLoader
import com.newsblur.discover.DiscoveryScreen
import com.newsblur.discover.DiscoveryViewModel
import com.newsblur.fragment.AddFeedFragment
import com.newsblur.service.NbSyncManager.UPDATE_METADATA
import com.newsblur.service.NbSyncManager.UPDATE_REBUILD
import com.newsblur.util.FeedUtils
import com.newsblur.util.FeedSet
import com.newsblur.util.AppConstants
import com.newsblur.util.ImageLoader
import com.newsblur.util.TryFeedStore
import dagger.hilt.android.AndroidEntryPoint
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import javax.inject.Inject

@AndroidEntryPoint
class DiscoverSitesActivity : NbActivity() {
    private val model: DiscoveryViewModel by viewModels()

    @Inject @IconLoader
    lateinit var iconLoader: ImageLoader

    @Inject lateinit var tryFeedStore: TryFeedStore

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        model.start()
        refreshSubscriptions()
        setContent {
            NewsBlurTheme(variant = prefsRepo.getSelectedTheme().toVariant(), dynamic = false) {
                DiscoveryContent()
            }
        }
    }

    override fun handleUpdate(updateType: Int) {
        // DiscoverSitesActivity.kt: SyncService publishes new folders through UPDATE_METADATA.
        if (updateType and (UPDATE_METADATA or UPDATE_REBUILD) != 0) refreshSubscriptions()
    }

    private fun refreshSubscriptions() {
        lifecycleScope.launch {
            val (folders, subscribed) =
                withContext(Dispatchers.IO) {
                    dbHelper.folders to dbHelper.allFeeds.mapNotNull { dbHelper.getFeed(it)?.address }.toSet()
                }
            model.setFolders(folders, subscribed)
        }
    }

    @androidx.compose.runtime.Composable
    private fun DiscoveryContent() {
        val state by model.state.collectAsStateWithLifecycle()
        LaunchedEffect(state.revision) {
            if (state.revision > 0) {
                syncServiceState.forceFeedsFolders()
                FeedUtils.triggerSync(this@DiscoverSitesActivity)
            }
        }
        LaunchedEffect(state.preview) {
            state.preview?.let { feed ->
                val subscribed = withContext(Dispatchers.IO) { dbHelper.getFeed(feed.feedId) }
                if (subscribed != null || feed.address in state.added) {
                    if (tryFeedStore.isTryFeed(feed.feedId)) tryFeedStore.clear()
                    FeedItemsList.startActivity(
                        this@DiscoverSitesActivity, FeedSet.singleFeed(feed.feedId),
                        subscribed ?: feed, AppConstants.ROOT_FOLDER, null, null,
                    )
                } else {
                    tryFeedStore.set(feed)
                    FeedItemsList.startTryFeedActivity(this@DiscoverSitesActivity, feed)
                }
                model.previewOpened()
            }
        }
        DiscoveryScreen(
            state,
            model,
            prefsRepo.getResolvedTheme(this),
            iconLoader,
            onBack = { finish() },
            onQuickAdd = { AddFeedFragment.newInstance().show(supportFragmentManager, "add_site") },
        )
    }
}
