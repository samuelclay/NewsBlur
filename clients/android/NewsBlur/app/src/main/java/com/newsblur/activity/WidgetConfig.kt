package com.newsblur.activity

import android.view.Menu
import android.view.MenuItem
import android.view.View
import com.newsblur.R
import com.newsblur.databinding.ActivityWidgetConfigBinding
import com.newsblur.di.IconLoader
import com.newsblur.domain.Feed
import com.newsblur.util.EdgeToEdgeUtil.applyView
import com.newsblur.util.FeedUtils
import com.newsblur.util.ImageLoader
import com.newsblur.util.UIUtils
import com.newsblur.viewModel.FeedFolderData
import com.newsblur.widget.WidgetUtils.updateWidget
import dagger.hilt.android.AndroidEntryPoint
import javax.inject.Inject

@AndroidEntryPoint
class WidgetConfig : FeedChooser() {

    @Inject
    lateinit var feedUtils: FeedUtils

    @Inject
    @IconLoader
    lateinit var iconLoader: ImageLoader

    private lateinit var binding: ActivityWidgetConfigBinding

    override fun onPause() {
        super.onPause()
        // notify widget to update next time it's viewed
        updateWidget(this)
    }

    override fun onCreateOptionsMenu(menu: Menu): Boolean {
        val inflater = menuInflater
        inflater.inflate(R.menu.menu_feed_chooser, menu)
        return true
    }

    override fun onPrepareOptionsMenu(menu: Menu): Boolean {
        super.onPrepareOptionsMenu(menu)
        menu.findItem(R.id.menu_mute_all).setVisible(false)
        menu.findItem(R.id.menu_mute_none).setVisible(false)
        return true
    }

    override fun onOptionsItemSelected(item: MenuItem): Boolean {
        if (item.itemId == R.id.menu_select_all) {
            selectAllFeeds()
            return true
        } else if (item.itemId == R.id.menu_select_none) {
            replaceWidgetFeedIds(emptySet())
            return true
        } else {
            return super.onOptionsItemSelected(item)
        }
    }

    override fun bindLayout() {
        binding = ActivityWidgetConfigBinding.inflate(layoutInflater)
        this.applyView(binding)
        UIUtils.setupToolbar(this, R.drawable.logo, getString(R.string.widget), true)
    }

    override fun setupList() {
        adapter = WidgetConfigAdapter(feedUtils, iconLoader, prefsRepo)
        binding.listView.setAdapter(adapter)
    }

    public override fun setAdapterData() {
        val feedIds = prefsRepo.getWidgetFeedIds() ?: feeds.map { it.feedId }.toSet()
        adapter.setFeedIds(feedIds)

        super.setAdapterData()
        binding.listView.visibility = if (feeds.isEmpty()) View.GONE else View.VISIBLE
        binding.textNoSubscriptions.visibility = if (feeds.isEmpty()) View.VISIBLE else View.GONE
    }

    override fun processData(data: FeedFolderData) {
        folders.clear()
        folders.addAll(data.folders)

        feeds.clear()
        feeds.addAll(data.feeds.filter { it.active })

        val feedMap = feeds.associateBy { it.feedId }

        for (folder in folders) {
            val activeFeeds = ArrayList<Feed>()
            for (feedId in folder.feedIds) {
                val feed = feedMap[feedId]
                if (feed != null && feed.active && !activeFeeds.contains(feed)) {
                    activeFeeds.add(feed)
                }
            }
            folderNames.add(folder.flatName())
            folderChildren.add(activeFeeds)
        }

        setAdapterData()
    }

    private fun selectAllFeeds() {
        replaceWidgetFeedIds(feeds.map { it.feedId }.toSet())
    }

    private fun replaceWidgetFeedIds(feedIds: Set<String>) {
        prefsRepo.setWidgetFeedIds(feedIds)
        adapter.replaceFeedIds(feedIds)
    }
}