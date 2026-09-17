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
import com.newsblur.util.FeedUtils
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
        if (updateType and com.newsblur.service.NbSyncManager.UPDATE_REBUILD != 0) refreshSubscriptions()
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
                tryFeedStore.set(feed)
                FeedItemsList.startTryFeedActivity(this@DiscoverSitesActivity, feed)
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
