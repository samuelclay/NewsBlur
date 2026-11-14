package com.newsblur.activity

import android.content.Context
import android.content.Intent
import android.os.Bundle
import androidx.activity.compose.setContent
import androidx.activity.viewModels
import androidx.compose.runtime.getValue
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.lifecycleScope
import com.newsblur.design.NewsBlurTheme
import com.newsblur.design.toVariant
import com.newsblur.di.IconLoader
import com.newsblur.di.ThumbnailLoader
import com.newsblur.discover.DiscoveryActionEffects
import com.newsblur.discover.DiscoveryScreen
import com.newsblur.discover.DiscoveryTab
import com.newsblur.discover.DiscoveryViewModel
import com.newsblur.fragment.AddFeedFragment
import com.newsblur.service.NbSyncManager.UPDATE_METADATA
import com.newsblur.service.NbSyncManager.UPDATE_REBUILD
import com.newsblur.util.ImageLoader
import com.newsblur.util.TryFeedStore
import dagger.hilt.android.AndroidEntryPoint
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import javax.inject.Inject

@AndroidEntryPoint
class DiscoverSitesActivity : NbActivity() {
    companion object {
        fun intent(context: Context, tab: DiscoveryTab, folder: String): Intent =
            Intent(context, DiscoverSitesActivity::class.java).apply {
                // DiscoverSitesActivity.kt restores the tab and seeds only an explicit fresh folder context.
                putExtra(DiscoveryViewModel.TAB, tab.name)
                putExtra(DiscoveryViewModel.FOLDER, folder)
            }
    }

    private val model: DiscoveryViewModel by viewModels()

    @Inject @IconLoader
    lateinit var iconLoader: ImageLoader

    @Inject @ThumbnailLoader
    lateinit var thumbnailLoader: ImageLoader

    @Inject lateinit var tryFeedStore: TryFeedStore

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (savedInstanceState == null) model.seedFolder(intent.getStringExtra(DiscoveryViewModel.FOLDER).orEmpty())
        model.start()
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

    fun showDiscovery(tab: DiscoveryTab, folder: String) {
        model.seedFolder(folder)
        model.selectTab(tab)
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
        DiscoveryActionEffects(this, model, tryFeedStore)
        DiscoveryScreen(
            state,
            model,
            prefsRepo.getResolvedTheme(this),
            iconLoader,
            thumbnailLoader,
            onBack = { finish() },
            onQuickAdd = {
                if (supportFragmentManager.findFragmentByTag("add_site") == null) {
                    AddFeedFragment.newInstance(parent = state.folder).show(supportFragmentManager, "add_site")
                }
            },
        )
    }
}
